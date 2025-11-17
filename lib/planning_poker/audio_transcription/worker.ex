defmodule PlanningPoker.AudioTranscription.Worker do
  @moduledoc """
  Background worker for transcribing audio recordings and posting them to GitLab.

  This module handles the full workflow of audio transcription:
  1. Load the Whisper model (lazy-loaded via ModelServer)
  2. Transcribe the audio file
  3. Post the transcription as a comment to the GitLab issue
  4. Schedule the audio file for cleanup (2 hours delay)

  ## Usage

      # Start transcription task
      task = Worker.transcribe_and_post(
        audio_path: "/tmp/recording.webm",
        issue: %{"referencePath" => "1st8/planning_poker#42", ...},
        token: "oauth-token",
        user_name: "Alice Anderson"
      )

      # Wait for result (in LiveView handle_info for task completion)
      case task_result do
        {:ok, transcription} -> # Success!
        {:error, reason} -> # Handle error
      end
  """

  require Logger

  alias PlanningPoker.AudioTranscription.ModelServer
  alias PlanningPoker.AudioTranscription.FileCleanup
  alias PlanningPoker.IssueProvider

  @doc """
  Starts an async task to transcribe audio and post it to GitLab.

  Returns a `Task` struct that can be monitored for completion.

  ## Arguments

  - `opts` - Keyword list with required fields:
    - `:audio_path` - Path to the audio file to transcribe
    - `:issue` - Issue map with `referencePath` and other fields
    - `:token` - OAuth access token for GitLab API
    - `:user_name` - Name of the user who recorded the audio (for attribution)

  ## Returns

  A `Task` struct. The task will eventually return:
  - `{:ok, transcription_text}` on success
  - `{:error, reason}` on failure

  ## Example

      task = Worker.transcribe_and_post(
        audio_path: "/tmp/recording123.webm",
        issue: current_issue,
        token: session_token,
        user_name: "Alice Anderson"
      )
  """
  def transcribe_and_post(opts) do
    audio_path = Keyword.fetch!(opts, :audio_path)
    issue = Keyword.fetch!(opts, :issue)
    token = Keyword.fetch!(opts, :token)
    user_name = Keyword.fetch!(opts, :user_name)

    Task.Supervisor.async_nolink(PlanningPoker.TaskSupervisor, fn ->
      do_transcribe_and_post(audio_path, issue, token, user_name)
    end)
  end

  # Private Functions

  defp do_transcribe_and_post(audio_path, issue, token, user_name) do
    Logger.info("Starting audio transcription for #{Path.basename(audio_path)}")

    try do
      # Step 1: Get the Whisper model serving (triggers lazy load if needed)
      {:ok, serving} = ModelServer.get_serving()
      Logger.debug("Whisper model serving obtained")

      # Step 2: Transcribe the audio file
      transcription_start = System.monotonic_time(:millisecond)

      result = Nx.Serving.run(serving, {:file, audio_path})
      Logger.debug("Whisper raw result: #{inspect(result)}")

      # Extract transcription text from chunks
      transcription = extract_transcription_text(result)

      transcription_time = System.monotonic_time(:millisecond) - transcription_start
      Logger.info("Transcription completed in #{transcription_time}ms")
      Logger.info("Transcribed text: #{inspect(transcription)}")

      # Step 3: Extract issue identifiers and prepare comment
      {project_id, issue_iid} = extract_issue_identifiers(issue)

      comment_body = format_transcription_comment(transcription, user_name)

      # Step 4: Post to GitLab
      client = IssueProvider.client(token: token)

      case IssueProvider.post_comment(client, project_id, issue_iid, comment_body) do
        {:ok, _note} ->
          Logger.info("Transcription posted to #{project_id}##{issue_iid}")

          # Step 5: Schedule file cleanup in 2 hours
          FileCleanup.schedule_cleanup(audio_path)

          {:ok, transcription}

        {:error, reason} ->
          Logger.error("Failed to post transcription to GitLab: #{inspect(reason)}")
          {:error, {:gitlab_post_failed, reason}}
      end
    rescue
      e ->
        Logger.error("Transcription failed: #{Exception.format(:error, e, __STACKTRACE__)}")
        {:error, {:transcription_failed, e}}
    end
  end

  defp extract_transcription_text(result) do
    # Handle different Bumblebee return formats
    case result do
      # New format (Bumblebee 0.5+): %{chunks: [%{text: "..."}, ...]}
      %{chunks: chunks} when is_list(chunks) ->
        chunks
        |> Enum.map(& &1.text)
        |> Enum.join("")
        |> String.trim()

      # Old format (legacy): %{results: [%{text: "..."}]}
      %{results: [%{text: text}]} ->
        String.trim(text)

      # Fallback
      _ ->
        Logger.warning("Unexpected transcription result format: #{inspect(result)}")
        "Transcription failed: unexpected format"
    end
  end

  defp extract_issue_identifiers(issue) do
    # Extract project_id and issue_iid from the issue's referencePath
    # Format: "1st8/planning_poker#42" -> {"1st8/planning_poker", "42"}
    reference_path = issue["referencePath"]

    if reference_path && String.contains?(reference_path, "#") do
      [project_path, iid] = String.split(reference_path, "#", parts: 2)
      {project_path, iid}
    else
      # Fallback for mock or issues without proper reference path
      {"mock-project", issue["iid"]}
    end
  end

  defp format_transcription_comment(transcription, user_name) do
    """
    ## 🎙️ Voice Comment (Transcribed)

    **Recorded by:** #{user_name}
    **Transcribed at:** #{format_timestamp(DateTime.utc_now())}

    ---

    #{transcription}

    ---

    _This comment was automatically transcribed from a voice recording using Whisper AI._
    """
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end
end
