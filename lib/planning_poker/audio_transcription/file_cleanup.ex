defmodule PlanningPoker.AudioTranscription.FileCleanup do
  @moduledoc """
  GenServer that manages delayed cleanup of audio files.

  Audio files are kept for 2 hours after transcription to allow for debugging
  and potential re-listening. This service schedules and executes file deletions.

  ## Usage

      # Schedule a file for cleanup in 2 hours
      FileCleanup.schedule_cleanup("/path/to/audio.webm")

      # Or specify a custom delay
      FileCleanup.schedule_cleanup("/path/to/audio.webm", :timer.hours(1))
  """

  use GenServer
  require Logger

  defp config do
    Application.get_env(:planning_poker, :audio_transcription, [])
  end

  defp cleanup_delay_ms do
    hours = Keyword.get(config(), :file_cleanup_delay_hours, 2)
    :timer.hours(hours)
  end

  # Client API

  @doc """
  Starts the FileCleanup GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Schedules a file for cleanup after the configured delay (default: 2 hours).

  ## Arguments

  - `file_path` - Absolute path to the file to delete
  - `delay_ms` - Optional custom delay in milliseconds (defaults to configured value)

  ## Returns

  - `:ok`

  ## Examples

      # Schedule with default 2-hour delay
      FileCleanup.schedule_cleanup("/tmp/recording.webm")

      # Schedule with 1-hour delay
      FileCleanup.schedule_cleanup("/tmp/recording.webm", :timer.hours(1))
  """
  def schedule_cleanup(file_path, delay_ms \\ nil) do
    GenServer.cast(__MODULE__, {:schedule_cleanup, file_path, delay_ms})
  end

  @doc """
  Gets the count of files currently scheduled for cleanup.

  Useful for monitoring and debugging.
  """
  def scheduled_count do
    GenServer.call(__MODULE__, :scheduled_count)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("FileCleanup service started")
    {:ok, %{scheduled: %{}}}
  end

  @impl true
  def handle_cast({:schedule_cleanup, file_path, custom_delay}, state) do
    delay = custom_delay || cleanup_delay_ms()

    # Schedule the deletion
    timer_ref = Process.send_after(self(), {:delete_file, file_path}, delay)

    # Track the scheduled deletion
    scheduled = Map.put(state.scheduled, timer_ref, %{
      file_path: file_path,
      scheduled_at: DateTime.utc_now(),
      delete_at: DateTime.add(DateTime.utc_now(), div(delay, 1000), :second)
    })

    Logger.info("Scheduled cleanup for #{file_path} in #{div(delay, 1000)} seconds")

    {:noreply, %{state | scheduled: scheduled}}
  end

  @impl true
  def handle_call(:scheduled_count, _from, state) do
    {:reply, map_size(state.scheduled), state}
  end

  @impl true
  def handle_info({:delete_file, file_path}, state) do
    # Find and remove the timer ref from scheduled
    {timer_ref, _} =
      state.scheduled
      |> Enum.find(fn {_ref, info} -> info.file_path == file_path end) || {nil, nil}

    new_scheduled =
      if timer_ref do
        Map.delete(state.scheduled, timer_ref)
      else
        state.scheduled
      end

    # Attempt to delete the file
    case File.rm(file_path) do
      :ok ->
        Logger.info("Successfully cleaned up audio file: #{file_path}")

      {:error, :enoent} ->
        Logger.debug("Audio file already deleted: #{file_path}")

      {:error, reason} ->
        Logger.warning("Failed to cleanup audio file #{file_path}: #{inspect(reason)}")
    end

    {:noreply, %{state | scheduled: new_scheduled}}
  end
end
