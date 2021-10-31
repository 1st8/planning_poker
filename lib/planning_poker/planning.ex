defmodule PlanningPoker.Planning do
  alias PlanningPoker.Presence

  def subscribe_and_monitor(id) do
    Phoenix.PubSub.subscribe(PlanningPoker.PubSub, planning_session_topic(id))
    Process.monitor(id |> to_pid)
  end

  def join_participant(session_id, %{id: id} = participant) do
    Presence.track(self(), planning_session_topic(session_id), id, participant)
  end

  def get_participants!(id) do
    id
    |> planning_session_topic
    |> Presence.list()
    |> Map.values()
    |> Enum.map(fn v -> get_in(v, [:metas, Access.at(0)]) end)
  end

  def get_planning_session!(id) do
    id |> to_pid |> :gen_statem.call(:get_state)
  end

  def start_voting(id) do
    id |> to_pid |> :gen_statem.call(:start_voting)
  end

  def finish_voting(id) do
    id |> to_pid |> :gen_statem.call(:finish_voting)
  end

  def commit_results(id) do
    id |> to_pid |> :gen_statem.call(:commit_results)
  end

  def refresh_issues(id) do
    id |> to_pid |> :gen_statem.call(:refresh_issues)
  end

  def kill_planning_session(id) do
    id |> to_pid |> Process.exit(:kill)
  end

  def to_pid(id) do
    [{pid, _value}] = Registry.lookup(PlanningPoker.PlanningSession.Registry, id)
    pid
  end

  def planning_session_topic(id) do
    "planning_sessions:#{id}"
  end
end
