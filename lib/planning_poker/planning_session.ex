defmodule PlanningPoker.PlanningSession do
  @behaviour :gen_statem

  alias PlanningPoker.{GitlabApi, Planning}

  # lobby
  # voting
  # results
  # magic_estimation

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
  def init(%{id: id, token: token}) do
    {:ok, :lobby,
     %{
       id: id,
       start: DateTime.utc_now(),
       options: [1, 2, 3, 5, 8, 13, 21, "?"] |> Enum.map(&to_string/1),
       issues: [],
       token: token,
       mode: :magic_estimation,
       opened_issue_ids: MapSet.new(),
       most_recent_issue_id: nil,
       unestimated_issues: [],
       estimated_issues: []
     }}
  end

  @impl :gen_statem
  def callback_mode, do: [:handle_event_function, :state_enter]

  @impl :gen_statem
  def handle_event(:enter, _event, :lobby, data) do
    {:next_state, :lobby, data |> fetch_issues}
  end

  def handle_event(:enter, _, _state, data) do
    {:keep_state, data}
  end

  def handle_event({:call, from}, {:start_voting, issue_id}, :lobby, data) do
    current_issue =
      data.issues
      |> Enum.find(fn el -> el["id"] == issue_id end)

    data =
      data
      |> Map.put(:current_issue, current_issue)
      |> fetch_current_issue
      |> Map.put(:voting_started_at, DateTime.utc_now())
      |> Map.put(:most_recent_issue_id, (if MapSet.member?(data.opened_issue_ids, issue_id), do: nil, else: issue_id))
      |> Map.put(:opened_issue_ids, MapSet.put(data.opened_issue_ids,issue_id))

    broadcast_state_change(:voting, data)

    {:next_state, :voting, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :finish_voting, :voting, data) do
    broadcast_state_change(:results, data)
    {:next_state, :results, data, [{:reply, from, :ok}]}
  end
  def handle_event({:call, from}, :back_to_lobby, :voting, data) do
    broadcast_state_change(:lobby, data)
    {:next_state, :lobby, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :start_magic_estimation, :lobby, data) do
    # Create story point markers for the options
    markers = data.options
              |> Enum.filter(fn val -> val != "?" end)  # Exclude the "?" option
              |> Enum.map(fn str -> {num, _} = Integer.parse(str); num end) # Convert to integers
              |> Enum.sort() # Sort numerically
              |> Enum.map(fn value ->
                  %{
                    "id" => "marker/#{value}",
                    "type" => "marker",
                    "value" => Integer.to_string(value),
                    "title" => "#{value} Story Points"
                  }
                end)

    data = %{data |
      unestimated_issues: data.issues ++ markers,
      estimated_issues: []  # Add markers to the estimated column initially
    }
    broadcast_state_change(:magic_estimation, data)
    {:next_state, :magic_estimation, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :complete_estimation, :magic_estimation, data) do
    broadcast_state_change(:lobby, data)
    {:next_state, :lobby, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:update_issue_position, issue_id, from_list, to_list, new_index}, :magic_estimation, data) do
    {issue, source_list, target_list} = case {from_list, to_list} do
      {"unestimated-issues", "estimated-issues"} ->
        issue = Enum.find(data.unestimated_issues, fn issue -> issue["id"] == issue_id end)
        {issue, :unestimated_issues, :estimated_issues}

      {"estimated-issues", "unestimated-issues"} ->
        issue = Enum.find(data.estimated_issues, fn issue -> issue["id"] == issue_id end)
        {issue, :estimated_issues, :unestimated_issues}

      {"estimated-issues", "estimated-issues"} ->
        issue = Enum.find(data.estimated_issues, fn issue -> issue["id"] == issue_id end)
        {issue, :estimated_issues, :estimated_issues}

      {"unestimated-issues", "unestimated-issues"} ->
        issue = Enum.find(data.unestimated_issues, fn issue -> issue["id"] == issue_id end)
        {issue, :unestimated_issues, :unestimated_issues}
    end

    # Remove the issue from the source list
    updated_source = data[source_list]
                    |> Enum.filter(fn i -> i["id"] != issue_id end)

    # Add the issue to the target list at the specified position
    {before_items, after_items} = data[target_list]
                                |> Enum.filter(fn i -> i["id"] != issue_id end)
                                |> Enum.split(new_index)

    updated_target = before_items ++ [issue] ++ after_items

    # Update both lists in the state data
    updated_data = data
                  |> Map.put(source_list, updated_source)
                  |> Map.put(target_list, updated_target)

    broadcast_state_change(:magic_estimation, updated_data)
    {:keep_state, updated_data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :commit_results, :results, data) do
    broadcast_state_change(:lobby, data)
    {:next_state, :lobby, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :refresh_issues, _state, data) do
    data = data |> fetch_issues
    broadcast_state_change(:lobby, data)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :get_state, state, data) do
    {:keep_state, data, [{:reply, from, to_payload(state, data)}]}
  end

  def handle_event({:call, from}, :list_issues, _state, data) do
    {:keep_state, data, [{:reply, from, data[:issues]}]}
  end

  def handle_event({:call, from}, {:change_mode, new_mode}, :lobby, data) do
    data = Map.put(data, :mode, new_mode)
    broadcast_state_change(:lobby, data)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, _event, _content, data) do
    {:keep_state, data, [{:reply, from, {:error, "invalid transition"}}]}
  end

  def handle_event(
        :info,
        {fetch_issues_ref, result},
        state,
        %{fetch_issues_ref: fetch_issues_ref} = data
      ) do
    Process.demonitor(fetch_issues_ref, [:flush])

    new_data = data |> Map.delete(:fetch_issues_ref) |> Map.put(:issues, result)
    broadcast_state_change(state, new_data)

    {:keep_state, new_data}
  end

  def handle_event(
        :info,
        {fetch_issue_ref, result},
        state,
        %{fetch_issue_ref: fetch_issue_ref} = data
      ) do
    Process.demonitor(fetch_issue_ref, [:flush])

    new_data =
      case data.current_issue do
        nil -> data
        _ -> data |> Map.put(:current_issue, result)
      end
      |> Map.delete(:fetch_issue_ref)

    broadcast_state_change(state, new_data)

    {:keep_state, new_data}
  end

  defp to_payload(state, data) do
    data
    |> Map.drop([:token, :fetch_issues_ref, :fetch_issue_ref])
    |> Map.merge(%{
      state: state,
      fetching: Map.has_key?(data, :fetch_issues_ref),
      current_issue:
        case data[:current_issue] do
          nil -> nil
          issue -> Map.merge(issue, %{fetching: Map.has_key?(issue, :fetch_issue_ref)})
        end
    })
  end

  defp broadcast_state_change(state, data) do
    Phoenix.PubSub.broadcast(
      PlanningPoker.PubSub,
      Planning.planning_session_topic(data.id),
      {:state_change, to_payload(state, data)}
    )
  end

  defp fetch_issues(data) do
    task =
      Task.Supervisor.async_nolink(PlanningPoker.TaskSupervisor, fn ->
        GitlabApi.fetch_issues(GitlabApi.default_client(token: data.token))
      end)

    Map.put(data, :fetch_issues_ref, task.ref)
  end

  defp fetch_current_issue(data) do
    task =
      Task.Supervisor.async_nolink(PlanningPoker.TaskSupervisor, fn ->
        GitlabApi.fetch_issue(GitlabApi.default_client(token: data.token), data.current_issue["id"])
      end)

    Map.put(data, :fetch_issue_ref, task.ref)
  end
end
