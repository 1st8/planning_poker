defmodule PlanningPoker.PlanningSession do
  @behaviour :gen_statem

  alias PlanningPoker.Planning

  # lobby
  # voting
  # results

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    {{:via, _, _} = name, opts} = Keyword.pop(opts, :name)
    {args, opts} = Keyword.pop(opts, :args)
    :gen_statem.start_link(name, __MODULE__, args, opts)
  end

  @impl :gen_statem
  def init(%{id: id}) do
    {:ok, :lobby, %{id: id, start: DateTime.utc_now()}}
  end

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  def handle_event({:call, from}, :start_voting, :lobby, data) do
    broadcast_state_change(:voting, data)
    {:next_state, :voting, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :finish_voting, :voting, data) do
    broadcast_state_change(:results, data)
    {:next_state, :results, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :commit_results, :results, data) do
    broadcast_state_change(:lobby, data)
    {:next_state, :lobby, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :get_state, state, data) do
    {:next_state, state, data, [{:reply, from, {state, data}}]}
  end

  def handle_event({:call, from}, _event, _content, data) do
    {:keep_state, data, [{:reply, from, {:error, "invalid transition"}}]}
  end

  defp broadcast_state_change(state, data) do
    Phoenix.PubSub.broadcast(
      PlanningPoker.PubSub,
      Planning.planning_session_topic(data.id),
      {:state_change, {state, data}}
    )
  end
end
