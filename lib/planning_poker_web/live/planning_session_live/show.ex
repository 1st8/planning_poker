defmodule PlanningPokerWeb.PlanningSessionLive.Show do
  use PlanningPokerWeb, :live_view

  alias PlanningPoker.{Issues, Planning}

  require Logger

  @impl true
  def mount(params, _session, socket) do
    id = Map.get(params, "id", "default")

    socket =
      if connected?(socket) do
        monitor_ref = Planning.subscribe_and_monitor(id)
        socket |> assign(:monitor_ref, monitor_ref)
      else
        socket
      end

    {:ok,
     socket
     |> assign(:page_title, "Planning session")
     |> assign(:planning_session, Planning.get_planning_session!(id))
     |> assign(:issues, Issues.list_issues!(id))}
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

  @impl true
  def handle_info({:state_change, new_planning_session}, socket) do
    {:noreply, assign(socket, :planning_session, new_planning_session)}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, socket) do
    socket =
      if socket.assigns.monitor_ref == ref do
        Logger.warn("PlanningSession died, reason=#{inspect(reason)}")
        Process.send_after(self(), :die, 2500)
        put_flash(socket, :error, "Oops, PlanningSession died, dying now too...")
        # Process.exit(self(), :normal)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:die, socket) do
    Process.exit(self(), :normal)
    {:noreply, socket}
  end
end
