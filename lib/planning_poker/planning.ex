defmodule PlanningPoker.Planning do
  alias PlanningPoker.Presence

  def ensure_started(id, token) do
    require Logger

    case Registry.lookup(PlanningPoker.PlanningSession.Registry, id) do
      [{pid, _}] ->
        Logger.debug("""
        PlanningSession already running
        Session ID: #{inspect(id)}
        Existing PID: #{inspect(pid)}
        Process alive: #{Process.alive?(pid)}
        """)

        {:ok, pid}

      [] ->
        Logger.info("""
        Starting new PlanningSession under DynamicSupervisor
        Session ID: #{inspect(id)}
        Caller PID: #{inspect(self())}
        """)

        child_spec = %{
          id: PlanningPoker.PlanningSession,
          start:
            {PlanningPoker.PlanningSession, :start_link,
             [
               [
                 name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, id}},
                 args: %{id: id, token: token}
               ]
             ]},
          restart: :temporary,
          type: :worker
        }

        result =
          DynamicSupervisor.start_child(PlanningPoker.PlanningSession.Supervisor, child_spec)

        case result do
          {:ok, pid} ->
            Logger.info(
              "PlanningSession started successfully under supervisor, PID: #{inspect(pid)}"
            )

          {:error, {:already_started, pid}} ->
            Logger.debug(
              "PlanningSession already started during race condition, PID: #{inspect(pid)}"
            )

          {:error, reason} ->
            Logger.error("Failed to start PlanningSession: #{inspect(reason)}")
        end

        result
    end
  end

  def subscribe_and_monitor(id) do
    require Logger

    Phoenix.PubSub.subscribe(PlanningPoker.PubSub, planning_session_topic(id))
    pid = id |> to_pid()
    monitor_ref = Process.monitor(pid)

    Logger.debug("""
    LiveView monitoring PlanningSession
    Session ID: #{inspect(id)}
    LiveView PID: #{inspect(self())}
    PlanningSession PID: #{inspect(pid)}
    Monitor Ref: #{inspect(monitor_ref)}
    PlanningSession alive: #{Process.alive?(pid)}
    """)

    monitor_ref
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

  def set_readiness(session_id, %{id: id} = participant, value) do
    Presence.update(
      self(),
      planning_session_topic(session_id),
      id,
      participant |> Map.put(:readiness, value)
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

  def clear_readiness(session_id) do
    topic = session_id |> planning_session_topic

    Enum.each(get_participants!(session_id), fn %{id: id} = participant ->
      Enum.each(Phoenix.Tracker.get_by_key(Presence, topic, id), fn {pid, _} ->
        Presence.update(
          pid,
          planning_session_topic(session_id),
          id,
          participant |> Map.delete(:readiness)
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

  def save_and_back_to_lobby(session_id) do
    session_id |> to_pid |> :gen_statem.call(:save_and_back_to_lobby)
  end

  def start_magic_estimation(session_id) do
    session_id |> to_pid |> :gen_statem.call(:start_magic_estimation)
  end

  def update_issue_position(session_id, issue_id, from_list, to_list, new_index) do
    session_id
    |> to_pid
    |> :gen_statem.call({:update_issue_position, issue_id, from_list, to_list, new_index})
  end

  def complete_estimation(session_id) do
    session_id |> to_pid |> :gen_statem.call(:complete_estimation)
  end

  def end_turn(session_id) do
    session_id |> to_pid |> :gen_statem.call(:end_turn)
  end

  def sync_turn_order(session_id, participant_ids) do
    session_id |> to_pid |> :gen_statem.call({:sync_turn_order, participant_ids})
  end

  def lock_section(session_id, section_id, user_id) do
    session_id |> to_pid |> :gen_statem.call({:lock_section, section_id, user_id})
  end

  def unlock_section(session_id, section_id, user_id) do
    session_id |> to_pid |> :gen_statem.call({:unlock_section, section_id, user_id})
  end

  def cancel_section_edit(session_id, section_id, user_id) do
    session_id |> to_pid |> :gen_statem.call({:cancel_section_edit, section_id, user_id})
  end

  def update_section_content(session_id, section_id, content, user_id) do
    session_id
    |> to_pid
    |> :gen_statem.call({:update_section_content, section_id, content, user_id})
  end

  def delete_section(session_id, section_id, user_id) do
    session_id |> to_pid |> :gen_statem.call({:delete_section, section_id, user_id})
  end

  def restore_section(session_id, section_id) do
    session_id |> to_pid |> :gen_statem.call({:restore_section, section_id})
  end

  def to_pid(id) do
    [{pid, _value}] = Registry.lookup(PlanningPoker.PlanningSession.Registry, id)
    pid
  end

  def planning_session_topic(id) do
    "planning_sessions:#{id}"
  end
end
