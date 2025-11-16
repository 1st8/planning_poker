defmodule PlanningPokerWeb.PlanningSessionLive.Show do
  use PlanningPokerWeb, :live_view

  alias PlanningPoker.Planning
  alias PlanningPoker.AudioTranscription.Worker, as: TranscriptionWorker
  alias PlanningPokerWeb.PlanningSessionLive.AudioRecorderComponent

  require Logger

  @impl true
  def mount(params, %{"current_user" => participant, "token" => token}, socket) do
    id = Map.get(params, "id", "default")
    Planning.ensure_started(id, token)

    socket =
      if connected?(socket) do
        monitor_ref = Planning.subscribe_and_monitor(id)
        Planning.join_participant(id, participant)
        socket |> assign(:monitor_ref, monitor_ref)
      else
        socket
      end

    {:ok,
     socket
     |> assign(:planning_session, Planning.get_planning_session!(id))
     |> assign_title()
     |> assign(:participants, Planning.get_participants!(id))
     |> assign(:current_participant, participant)
     |> assign(:token, token)
     |> assign(:personal_notes, %{})}
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/participate")}
  end

  @impl true
  def handle_event("start_voting", %{"issue_id" => issue_id}, socket) do
    :ok = Planning.start_voting(socket.assigns.planning_session.id, issue_id)
    {:noreply, socket}
  end

  def handle_event("finish_voting", _value, socket) do
    :ok = Planning.finish_voting(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("commit_results", _value, socket) do
    :ok = Planning.commit_results(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("kill_planning_session", _value, socket) do
    Planning.kill_planning_session(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("refresh_issues", _value, socket) do
    Planning.refresh_issues(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("cast_vote", %{"value" => value}, socket) do
    Planning.cast_vote(
      socket.assigns.planning_session.id,
      socket.assigns.current_participant,
      value
    )

    {:noreply, socket}
  end

  def handle_event("set_readiness", %{"value" => value}, socket) do
    Planning.set_readiness(
      socket.assigns.planning_session.id,
      socket.assigns.current_participant,
      value
    )

    {:noreply, socket}
  end

  def handle_event("sync_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :personal_notes, notes)}
  end

  def handle_event("change_mode", _value, socket) do
    new_mode =
      if socket.assigns.planning_session.mode == :magic_estimation,
        do: :planning_poker,
        else: :magic_estimation

    :ok = Planning.change_mode(socket.assigns.planning_session.id, new_mode)
    {:noreply, socket}
  end

  def handle_event("start_magic_estimation", _value, socket) do
    :ok = Planning.start_magic_estimation(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event(
        "issue_moved",
        %{"issue_id" => issue_id, "from" => from, "to" => to, "new_index" => new_index},
        socket
      ) do
    :ok =
      Planning.update_issue_position(
        socket.assigns.planning_session.id,
        issue_id,
        from,
        to,
        new_index
      )

    {:noreply, socket}
  end

  def handle_event("complete_estimation", _value, socket) do
    :ok = Planning.complete_estimation(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("back_to_lobby", _value, socket) do
    :ok = Planning.back_to_lobby(socket.assigns.planning_session.id)
    {:noreply, socket}
  end

  def handle_event("save_and_back_to_lobby", _value, socket) do
    case Planning.save_and_back_to_lobby(socket.assigns.planning_session.id) do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save issue: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:state_change, new_planning_session}, socket) do
    socket =
      socket
      |> assign(:planning_session, new_planning_session)
      |> assign_title()

    {:noreply, socket}
  end

  def handle_info({:weight_update_errors, failures}, socket) do
    # Show error flash for failed weight updates
    error_count = length(failures)

    error_msg =
      if error_count == 1 do
        "Failed to update 1 issue weight"
      else
        "Failed to update #{error_count} issue weights"
      end

    {:noreply, put_flash(socket, :error, error_msg)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    participants = Planning.get_participants!(socket.assigns.planning_session.id)

    current_participant =
      Enum.find(participants, fn p -> p.id == socket.assigns.current_participant.id end)

    {
      :noreply,
      socket
      |> assign(:participants, participants)
      |> assign(:current_participant, current_participant)
    }
  end

  # PlanningSession DOWN handler
  def handle_info(
        {:DOWN, monitor_ref, :process, _, reason},
        %{assigns: %{monitor_ref: monitor_ref}} = socket
      ) do
    Logger.warning("PlanningSession died, reason=#{inspect(reason)}")
    Process.send_after(self(), :die, 250)

    {:noreply, socket |> put_flash(:error, "Oops, PlanningSession died, dying now too...")}
  end

  def handle_info(:die, socket) do
    Process.exit(self(), :normal)
    {:noreply, socket}
  end

  # Audio recording upload and transcription handlers

  def handle_info({:process_audio_recording, base64_data, mime_type, _component_id}, socket) do
    # This message is sent by the AudioRecorderComponent with base64-encoded audio data
    # Decode and save the file, then start transcription

    try do
      # Decode base64 data
      binary_data = Base.decode64!(base64_data)

      # Create upload directory if it doesn't exist
      upload_dir =
        Path.join(["priv", "static", "uploads", "audio", socket.assigns.planning_session.id])

      File.mkdir_p!(upload_dir)

      # Generate unique filename with appropriate extension
      timestamp = System.system_time(:millisecond)
      ext = mime_type_to_extension(mime_type)
      audio_path = Path.join(upload_dir, "#{timestamp}#{ext}")

      # Write the binary data to file
      File.write!(audio_path, binary_data)

      Logger.info("Audio file saved: #{audio_path} (#{byte_size(binary_data)} bytes)")

      # Start transcription task
      issue = socket.assigns.planning_session.data.current_issue
      token = socket.assigns.token
      user_name = socket.assigns.current_participant.name

      task =
        TranscriptionWorker.transcribe_and_post(
          audio_path: audio_path,
          issue: issue,
          token: token,
          user_name: user_name
        )

      # Update component to show "transcribing" state
      AudioRecorderComponent.set_transcribing(socket, "audio-recorder")

      # Store task ref to handle completion
      {:noreply, assign(socket, :transcription_task_ref, task.ref)}
    rescue
      e ->
        Logger.error("Failed to process audio recording: #{inspect(e)}")
        AudioRecorderComponent.set_error(socket, "audio-recorder", "Failed to save recording")
        {:noreply, socket}
    end
  end

  def handle_info({ref, result}, socket) when socket.assigns[:transcription_task_ref] == ref do
    # Transcription task completed
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, _transcription} ->
        # Success! Update component
        AudioRecorderComponent.set_success(socket, "audio-recorder")
        Logger.info("Audio transcription and posting completed successfully")

      {:error, reason} ->
        # Error - show to user
        error_msg = format_transcription_error(reason)
        AudioRecorderComponent.set_error(socket, "audio-recorder", error_msg)
        Logger.error("Audio transcription failed: #{inspect(reason)}")
    end

    {:noreply, assign(socket, :transcription_task_ref, nil)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket)
      when socket.assigns[:transcription_task_ref] == ref do
    # Transcription task crashed
    Logger.error("Transcription task crashed: #{inspect(reason)}")
    AudioRecorderComponent.set_error(socket, "audio-recorder", "Transcription failed unexpectedly")

    {:noreply, assign(socket, :transcription_task_ref, nil)}
  end

  def handle_info({:reset_recorder, component_id}, socket) do
    # Reset the recorder component to idle state after success
    send_update(AudioRecorderComponent, id: component_id, recording_state: :idle, transcription_status: nil)
    {:noreply, socket}
  end

  defp mime_type_to_extension(mime_type) do
    case mime_type do
      "audio/webm" <> _ -> ".webm"
      "audio/ogg" <> _ -> ".ogg"
      "audio/mp4" -> ".m4a"
      "audio/mpeg" -> ".mp3"
      "audio/wav" -> ".wav"
      _ -> ".webm"
    end
  end

  defp format_transcription_error({:gitlab_post_failed, _}), do: "Failed to post comment to GitLab"
  defp format_transcription_error({:transcription_failed, _}), do: "Failed to transcribe audio"
  defp format_transcription_error(_), do: "An unexpected error occurred"

  def assign_title(socket) do
    socket
    |> assign(
      :page_title,
      case socket.assigns.planning_session.state do
        :lobby -> "Lobby"
        :voting -> "Voting"
        :results -> "Results"
        :magic_estimation -> "Magic Estimation"
        _ -> "Loading..."
      end
    )
  end
end
