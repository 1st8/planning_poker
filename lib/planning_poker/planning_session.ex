defmodule PlanningPoker.PlanningSession do
  @behaviour :gen_statem

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
    {name, opts} = Keyword.pop(opts, :name)
    :gen_statem.start_link({:local, name}, __MODULE__, :ok, opts)
  end

  @impl :gen_statem
  def init(_), do: {:ok, :lobby, nil}

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  def handle_event({:call, from}, :start_voting, :lobby, data) do
    Phoenix.PubSub.broadcast(
      PlanningPoker.PubSub,
      "planning_sessions:default",
      {:state_change, {:voting, data}}
    )

    {:next_state, :voting, data, [{:reply, from, {:ok, {:voting, data}}}]}
  end

  def handle_event({:call, from}, :finish_voting, :voting, data) do
    Phoenix.PubSub.broadcast(
      PlanningPoker.PubSub,
      "planning_sessions:default",
      {:state_change, {:results, data}}
    )

    {:next_state, :results, data, [{:reply, from, {:ok, {:results, data}}}]}
  end

  def handle_event({:call, from}, :commit_results, :results, data) do
    Phoenix.PubSub.broadcast(
      PlanningPoker.PubSub,
      "planning_sessions:default",
      {:state_change, {:lobby, data}}
    )

    {:next_state, :lobby, data, [{:reply, from, {:ok, {:lobby, data}}}]}
  end

  def handle_event({:call, from}, :get_state, state, data) do
    {:next_state, state, data, [{:reply, from, {state, data}}]}
  end

  def handle_event({:call, from}, _event, _content, data) do
    {:keep_state, data, [{:reply, from, {:error, "invalid transition"}}]}
  end
end
