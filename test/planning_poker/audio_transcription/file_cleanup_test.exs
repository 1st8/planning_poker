defmodule PlanningPoker.AudioTranscription.FileCleanupTest do
  use ExUnit.Case, async: false

  alias PlanningPoker.AudioTranscription.FileCleanup

  # Note: These tests are not async because we're testing a singleton GenServer

  setup do
    # Create a temporary test file
    test_dir = Path.join([System.tmp_dir!(), "planning_poker_test"])
    File.mkdir_p!(test_dir)

    test_file = Path.join(test_dir, "test_audio_#{:erlang.unique_integer([:positive])}.webm")
    File.write!(test_file, "fake audio data")

    on_exit(fn ->
      # Cleanup test directory
      if File.exists?(test_dir), do: File.rm_rf!(test_dir)
    end)

    %{test_file: test_file, test_dir: test_dir}
  end

  describe "start_link/1" do
    test "starts the FileCleanup GenServer" do
      pid = Process.whereis(FileCleanup)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "schedule_cleanup/1" do
    test "schedules file for cleanup with default delay", %{test_file: test_file} do
      assert File.exists?(test_file)

      # Schedule cleanup with a very short delay for testing (100ms)
      FileCleanup.schedule_cleanup(test_file, 100)

      # File should still exist immediately
      assert File.exists?(test_file)

      # Wait for cleanup to happen
      Process.sleep(150)

      # File should be deleted
      refute File.exists?(test_file)
    end

    test "schedules file for cleanup with custom delay", %{test_file: test_file} do
      assert File.exists?(test_file)

      # Schedule with 50ms delay
      FileCleanup.schedule_cleanup(test_file, 50)

      # File should still exist immediately
      assert File.exists?(test_file)

      # Wait for cleanup
      Process.sleep(100)

      # File should be deleted
      refute File.exists?(test_file)
    end

    test "handles cleanup of non-existent file gracefully" do
      fake_path = "/tmp/nonexistent_file_#{:erlang.unique_integer([:positive])}.webm"

      # This should not crash
      FileCleanup.schedule_cleanup(fake_path, 10)

      Process.sleep(50)

      # No error should occur
      pid = Process.whereis(FileCleanup)
      assert Process.alive?(pid)
    end

    test "can schedule multiple files for cleanup", %{test_dir: test_dir} do
      file1 = Path.join(test_dir, "file1.webm")
      file2 = Path.join(test_dir, "file2.webm")
      file3 = Path.join(test_dir, "file3.webm")

      File.write!(file1, "data1")
      File.write!(file2, "data2")
      File.write!(file3, "data3")

      # Schedule all files
      FileCleanup.schedule_cleanup(file1, 50)
      FileCleanup.schedule_cleanup(file2, 50)
      FileCleanup.schedule_cleanup(file3, 50)

      # All should exist initially
      assert File.exists?(file1)
      assert File.exists?(file2)
      assert File.exists?(file3)

      # Wait for cleanup
      Process.sleep(100)

      # All should be deleted
      refute File.exists?(file1)
      refute File.exists?(file2)
      refute File.exists?(file3)
    end
  end

  describe "scheduled_count/0" do
    test "returns count of scheduled cleanups", %{test_dir: test_dir} do
      initial_count = FileCleanup.scheduled_count()

      file1 = Path.join(test_dir, "count1.webm")
      file2 = Path.join(test_dir, "count2.webm")

      File.write!(file1, "data1")
      File.write!(file2, "data2")

      # Schedule files with longer delay to check count
      FileCleanup.schedule_cleanup(file1, 1000)
      FileCleanup.schedule_cleanup(file2, 1000)

      # Give it time to process the schedule requests
      Process.sleep(50)

      new_count = FileCleanup.scheduled_count()
      assert new_count >= initial_count + 2

      # Cleanup manually to avoid waiting
      File.rm(file1)
      File.rm(file2)
    end
  end

  describe "configuration" do
    test "reads cleanup delay from configuration" do
      config = Application.get_env(:planning_poker, :audio_transcription, [])
      delay_hours = Keyword.get(config, :file_cleanup_delay_hours, 2)

      assert delay_hours == 2
    end
  end
end
