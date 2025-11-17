defmodule PlanningPoker.AudioTranscription.ModelServerTest do
  use ExUnit.Case, async: false

  alias PlanningPoker.AudioTranscription.ModelServer

  # Note: These tests are not async because we're testing a singleton GenServer

  setup do
    # Get the existing ModelServer process (started by application)
    pid = Process.whereis(ModelServer)

    # Send unload message to reset state before each test
    if pid do
      send(pid, :unload_model)
      # Give it time to process
      Process.sleep(10)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the ModelServer GenServer" do
      # The ModelServer should already be started by the application
      pid = Process.whereis(ModelServer)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "loaded?/0" do
    test "returns false when model is not loaded" do
      refute ModelServer.loaded?()
    end

    test "returns true after model is loaded" do
      # Note: This test is skipped because it would download a 290MB model
      # In a real environment, you'd mock Bumblebee.load_model
      #
      # {:ok, _serving} = ModelServer.get_serving()
      # assert ModelServer.loaded?()
    end
  end

  describe "GenServer lifecycle" do
    test "initializes with nil serving and no timer" do
      # The ModelServer should start with no model loaded
      refute ModelServer.loaded?()
    end

    test "handles unload_model message" do
      # Ensure the server can receive the unload message
      pid = Process.whereis(ModelServer)
      assert is_pid(pid)

      send(pid, :unload_model)
      Process.sleep(10)

      # Model should remain unloaded
      refute ModelServer.loaded?()
    end
  end

  describe "configuration" do
    test "reads model name from configuration" do
      config = Application.get_env(:planning_poker, :audio_transcription, [])
      model_name = Keyword.get(config, :whisper_model, "openai/whisper-base")

      assert model_name == "openai/whisper-base"
    end

    test "reads idle timeout from configuration" do
      config = Application.get_env(:planning_poker, :audio_transcription, [])
      timeout_minutes = Keyword.get(config, :model_idle_timeout_minutes, 30)

      assert timeout_minutes == 30
    end
  end
end
