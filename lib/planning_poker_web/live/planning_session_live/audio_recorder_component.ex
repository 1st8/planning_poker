defmodule PlanningPokerWeb.PlanningSessionLive.AudioRecorderComponent do
  use PlanningPokerWeb, :live_component

  @moduledoc """
  LiveComponent for recording and transcribing voice comments.

  Provides UI for:
  - Recording audio via browser MediaRecorder API
  - Showing recording duration timer
  - Uploading recorded audio
  - Displaying transcription progress
  - Showing success/error feedback

  Only displayed for GitLab provider (not Mock).
  """

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:recording_state, fn -> :idle end)
     |> assign_new(:recording_duration, fn -> 0 end)
     |> assign_new(:transcription_status, fn -> nil end)
     |> assign_new(:available_devices, fn -> [] end)
     |> assign_new(:selected_device_id, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="audio-recorder border-t border-gray-200 pt-6 mt-6" id={"audio-recorder-#{@id}"} phx-hook="AudioRecorder">
      <div class="flex flex-col gap-4">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold text-gray-900">Voice Comment</h3>

          <%= case @recording_state do %>
            <% :idle -> %>
              <button
                phx-click="start_recording"
                phx-target={@myself}
                class="btn btn-sm btn-outline gap-2"
              >
                <.icon name="hero-microphone" class="h-5 w-5" />
                Kommentar aufnehmen
              </button>

          <% :recording -> %>
            <div class="flex items-center gap-4">
              <!-- Pulsing red indicator -->
              <div class="flex items-center gap-2">
                <span class="relative flex h-3 w-3">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                </span>
                <span class="text-sm font-medium text-gray-700">
                  Recording: <%= format_duration(@recording_duration) %>
                </span>
              </div>

              <button
                phx-click="stop_recording"
                phx-target={@myself}
                class="btn btn-sm btn-error gap-2"
              >
                <.icon name="hero-stop" class="h-5 w-5" />
                Stop
              </button>
            </div>

          <% :stopped -> %>
            <div class="flex flex-col gap-3 w-full">
              <div class="flex items-center gap-4">
                <span class="text-sm text-gray-600">
                  Recording ready (<%= format_duration(@recording_duration) %>)
                </span>

                <button
                  phx-click="cancel_recording"
                  phx-target={@myself}
                  class="btn btn-sm btn-ghost"
                >
                  Cancel
                </button>

                <button
                  phx-click="send_recording"
                  phx-target={@myself}
                  class="btn btn-sm btn-primary gap-2"
                >
                  <.icon name="hero-paper-airplane" class="h-5 w-5" />
                  Senden
                </button>
              </div>

              <!-- Audio playback -->
              <div class="flex items-center gap-2 bg-base-200 p-3 rounded-lg">
                <.icon name="hero-speaker-wave" class="h-5 w-5 text-gray-500" />
                <audio id="audio-playback" controls class="flex-1 h-8">
                  Your browser does not support the audio element.
                </audio>
              </div>
            </div>

          <% :uploading -> %>
            <div class="flex items-center gap-2">
              <span class="loading loading-spinner loading-sm"></span>
              <span class="text-sm text-gray-600">Uploading...</span>
            </div>

          <% :transcribing -> %>
            <div class="flex items-center gap-2">
              <span class="loading loading-spinner loading-sm"></span>
              <span class="text-sm text-gray-600">Transcribing...</span>
            </div>

          <% :posting -> %>
            <div class="flex items-center gap-2">
              <span class="loading loading-spinner loading-sm"></span>
              <span class="text-sm text-gray-600">Posting to GitLab...</span>
            </div>

          <% :success -> %>
            <div class="alert alert-success shadow-sm py-2 px-4">
              <.icon name="hero-check-circle" class="h-5 w-5" />
              <span class="text-sm">Voice comment posted successfully!</span>
            </div>

          <% :error -> %>
            <div class="alert alert-error shadow-sm py-2 px-4">
              <.icon name="hero-x-circle" class="h-5 w-5" />
              <span class="text-sm">
                <%= @transcription_status || "Failed to process recording" %>
              </span>
            </div>
        <% end %>
        </div>

        <!-- Microphone selector (only in idle state) -->
        <%= if @recording_state == :idle && length(@available_devices) > 0 do %>
          <div class="flex items-center gap-2">
            <label for="microphone-select" class="text-sm font-medium text-gray-700">
              Microphone:
            </label>
            <select
              id="microphone-select"
              class="select select-sm select-bordered flex-1"
              phx-change="select_device"
              phx-target={@myself}
            >
              <%= for device <- @available_devices do %>
                <option value={device["deviceId"]} selected={device["deviceId"] == @selected_device_id}>
                  <%= device["label"] %>
                </option>
              <% end %>
            </select>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("devices_enumerated", %{"devices" => devices}, socket) do
    # Store available audio input devices
    {:noreply, assign(socket, :available_devices, devices)}
  end

  @impl true
  def handle_event("select_device", %{"value" => device_id}, socket) do
    # Update selected device
    {:noreply, assign(socket, :selected_device_id, device_id)}
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    device_id = socket.assigns.selected_device_id

    {:noreply,
     socket
     |> assign(:recording_state, :recording)
     |> assign(:recording_duration, 0)
     |> push_event("start-audio-recording", %{device_id: device_id})}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    {:noreply,
     socket
     |> assign(:recording_state, :stopped)
     |> push_event("stop-audio-recording", %{})}
  end

  @impl true
  def handle_event("cancel_recording", _params, socket) do
    {:noreply,
     socket
     |> assign(:recording_state, :idle)
     |> assign(:recording_duration, 0)
     |> assign(:transcription_status, nil)
     |> push_event("cancel-audio-recording", %{})}
  end

  @impl true
  def handle_event("send_recording", _params, socket) do
    # Request the audio data from JavaScript
    {:noreply,
     socket
     |> assign(:recording_state, :uploading)
     |> push_event("request-audio-data", %{})}
  end

  # Note: The following events are handled in the parent LiveView (Show.ex)
  # because JavaScript hooks send events to the parent, not to components:
  # - update_duration
  # - recording_complete
  # - recording_error
  # - audio_data

  # Public functions for parent LiveView to update state

  def set_transcribing(socket, component_id) do
    send_update(__MODULE__, id: component_id, recording_state: :transcribing)
    socket
  end

  def set_posting(socket, component_id) do
    send_update(__MODULE__, id: component_id, recording_state: :posting)
    socket
  end

  def set_success(socket, component_id) do
    send_update(__MODULE__, id: component_id, recording_state: :success)

    # Reset to idle after 3 seconds
    Process.send_after(self(), {:reset_recorder, component_id}, 3000)
    socket
  end

  def set_error(socket, component_id, error_message) do
    send_update(__MODULE__,
      id: component_id,
      recording_state: :error,
      transcription_status: error_message
    )

    socket
  end

  # Helper functions

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{pad(minutes)}:#{pad(secs)}"
  end

  defp format_duration(_), do: "00:00"

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: to_string(number)
end
