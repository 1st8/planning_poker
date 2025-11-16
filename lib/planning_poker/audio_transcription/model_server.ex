defmodule PlanningPoker.AudioTranscription.ModelServer do
  @moduledoc """
  GenServer that manages the Whisper model lifecycle with lazy loading and automatic unloading.

  The model is loaded on first use and kept in memory for 30 minutes after the last transcription
  request. This optimizes memory usage while providing fast response times for active users.

  ## Model Lifecycle
  1. First call to `get_serving/0`: Downloads model from HuggingFace (~290MB) and loads into memory
  2. Subsequent calls: Returns cached model and resets the 30-minute timer
  3. After 30 minutes of inactivity: Unloads model from memory (but keeps on disk)
  4. Next call after unload: Loads from disk cache (fast, no download needed)

  ## Model Storage
  - Downloaded to: `~/.cache/huggingface/hub/`
  - Model: `openai/whisper-base` (~290MB)
  - Downloads only once, persists on disk permanently
  """

  use GenServer
  require Logger

  defp config do
    Application.get_env(:planning_poker, :audio_transcription, [])
  end

  defp idle_timeout_ms do
    minutes = Keyword.get(config(), :model_idle_timeout_minutes, 30)
    :timer.minutes(minutes)
  end

  defp model_name do
    Keyword.get(config(), :whisper_model, "openai/whisper-base")
  end

  # Client API

  @doc """
  Starts the ModelServer GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the Whisper serving for transcription.

  On first call, this will download and load the model (~290MB), which may take several minutes.
  Subsequent calls return the cached model immediately and reset the 30-minute idle timer.

  Returns `{:ok, serving}` where serving is a Nx.Serving that can be used with
  `Nx.Serving.run(serving, {:file, audio_path})`.

  ## Examples

      {:ok, serving} = ModelServer.get_serving()
      %{results: [%{text: transcription}]} = Nx.Serving.run(serving, {:file, "recording.mp3"})
  """
  def get_serving do
    GenServer.call(__MODULE__, :get_serving, :timer.minutes(5))
  end

  @doc """
  Checks if the model is currently loaded in memory.

  Returns `true` if the model is loaded, `false` otherwise.
  """
  def loaded? do
    GenServer.call(__MODULE__, :loaded?)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("ModelServer started")
    {:ok, %{serving: nil, timer_ref: nil, load_count: 0}}
  end

  @impl true
  def handle_call(:get_serving, _from, %{serving: nil} = state) do
    Logger.info("Loading Whisper model for the first time...")
    start_time = System.monotonic_time(:millisecond)

    case load_whisper_model() do
      {:ok, serving} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.info("Whisper model loaded successfully in #{elapsed}ms")

        timer_ref = schedule_unload()
        new_state = %{
          serving: serving,
          timer_ref: timer_ref,
          load_count: state.load_count + 1
        }

        {:reply, {:ok, serving}, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to load Whisper model: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_serving, _from, %{serving: serving, timer_ref: old_ref} = state) do
    # Model already loaded - reset the timer
    if old_ref, do: Process.cancel_timer(old_ref)
    timer_ref = schedule_unload()

    Logger.debug("Whisper model serving returned (timer reset)")

    {:reply, {:ok, serving}, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_call(:loaded?, _from, %{serving: serving} = state) do
    {:reply, serving != nil, state}
  end

  @impl true
  def handle_info(:unload_model, state) do
    timeout = idle_timeout_ms()
    Logger.info("Unloading Whisper model after #{timeout}ms of inactivity")
    {:noreply, %{state | serving: nil, timer_ref: nil}}
  end

  # Private Functions

  defp schedule_unload do
    Process.send_after(self(), :unload_model, idle_timeout_ms())
  end

  defp load_whisper_model do
    try do
      model = model_name()

      # Load model components from HuggingFace
      # These will be cached in ~/.cache/huggingface/hub/ after first download
      {:ok, model_info} = Bumblebee.load_model({:hf, model})
      {:ok, featurizer} = Bumblebee.load_featurizer({:hf, model})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model})
      {:ok, generation_config} = Bumblebee.load_generation_config({:hf, model})

      # Create the speech-to-text serving
      serving =
        Bumblebee.Audio.speech_to_text(
          model_info,
          featurizer,
          tokenizer,
          generation_config,
          defn_options: [compiler: EXLA]
        )

      {:ok, serving}
    rescue
      e ->
        {:error, e}
    end
  end
end
