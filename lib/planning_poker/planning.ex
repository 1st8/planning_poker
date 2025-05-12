defmodule PlanningPoker.Planning do
  alias PlanningPoker.Presence

  def ensure_started(id, token) do
    PlanningPoker.PlanningSession.start_link(
      name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, id}},
      args: %{id: id, token: token}
    )
  end

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

  def cast_vote(session_id, %{id: id} = participant, value) do
    Presence.update(
      self(),
      planning_session_topic(session_id),
      id,
      participant |> Map.put(:vote, value)
    )
  end

  def get_planning_session!(id) do
    id |> to_pid |> :gen_statem.call(:get_state)
  end

  def start_voting(id, issue_id) do
    id |> to_pid |> :gen_statem.call({:start_voting, issue_id})
  end

  def finish_voting(id) do
    id |> to_pid |> :gen_statem.call(:finish_voting)
  end

  def commit_results(session_id) do
    clear_votes(session_id)

    session_id |> to_pid |> :gen_statem.call(:commit_results)
  end

  def clear_votes(session_id) do
    topic = session_id |> planning_session_topic

    Enum.each(get_participants!(session_id), fn %{id: id} = participant ->
      Enum.each(Phoenix.Tracker.get_by_key(Presence, topic, id), fn {pid, _} ->
        Presence.update(
          pid,
          planning_session_topic(session_id),
          id,
          participant |> Map.delete(:vote)
        )
      end)
    end)
  end

  def refresh_issues(id) do
    id |> to_pid |> :gen_statem.call(:refresh_issues)
  end

  def kill_planning_session(id) do
    id |> to_pid |> Process.exit(:kill)
  end

  def change_mode(session_id, new_mode) do
    session_id |> to_pid |> :gen_statem.call({:change_mode, new_mode})
  end

  def back_to_lobby(session_id) do
    session_id |> to_pid |> :gen_statem.call(:back_to_lobby)
  end

  def start_magic_estimation(session_id) do
    session_id |> to_pid |> :gen_statem.call(:start_magic_estimation)
  end

  def update_issue_position(session_id, issue_id, from_list, to_list, new_index) do
    session_id |> to_pid |> :gen_statem.call({:update_issue_position, issue_id, from_list, to_list, new_index})
  end

  def complete_estimation(session_id) do
    session_id |> to_pid |> :gen_statem.call(:complete_estimation)
  end

  def to_pid(id) do
    [{pid, _value}] = Registry.lookup(PlanningPoker.PlanningSession.Registry, id)
    pid
  end

  def planning_session_topic(id) do
    "planning_sessions:#{id}"
  end
end
