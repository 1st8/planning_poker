defmodule PlanningPokerWeb.PlanningSessionLive.Show do
  use PlanningPokerWeb, :live_view

  alias PlanningPoker.{Issues, Planning}

  require Logger

  @impl true
  def mount(params, %{"participant" => participant}, socket) do
    id = Map.get(params, "id", "default")

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
     |> assign(:current_participant, participant)}
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/participate")}
  end

  @impl true
  def handle_event("start_voting", _value, socket) do
    :ok = Planning.start_voting(socket.assigns.planning_session.id)
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

  @impl true
  def handle_info({:state_change, new_planning_session}, socket) do
    socket =
      socket
      |> assign(:planning_session, new_planning_session)
      |> assign_title()

    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
     socket
     |> assign(:participants, Planning.get_participants!(socket.assigns.planning_session.id))}
  end

  # PlanningSession DOWN handler
  def handle_info(
        {:DOWN, monitor_ref, :process, _, reason},
        %{assigns: %{monitor_ref: monitor_ref}} = socket
      ) do
    Logger.warn("PlanningSession died, reason=#{inspect(reason)}")
    Process.send_after(self(), :die, 250)

    {:noreply, socket |> put_flash(:error, "Oops, PlanningSession died, dying now too...")}
  end

  def handle_info(:die, socket) do
    Process.exit(self(), :normal)
    {:noreply, socket}
  end

  def assign_title(socket) do
    socket |> assign(:page_title, case socket.assigns.planning_session.state do
      :lobby -> "Lobby"
      :voting -> "Voting"
      :results -> "Results"
      _ -> "Loading..."
    end)
  end
end
