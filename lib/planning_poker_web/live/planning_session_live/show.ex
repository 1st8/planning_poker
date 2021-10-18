defmodule PlanningPokerWeb.PlanningSessionLive.Show do
  use PlanningPokerWeb, :live_view

  alias PlanningPoker.Planning

  require Logger

  @impl true
  def mount(params, _session, socket) do
    id = Map.get(params, "id", "default")

    if connected?(socket) do
      topic = "planning_sessions:#{id}"
      Logger.info("Subscribing to #{topic}")
      Phoenix.PubSub.subscribe(PlanningPoker.PubSub, topic)
    end

    {:ok,
     socket
     |> assign(:page_title, "Planning session")
     |> assign(:planning_session_id, id)
     |> assign(:planning_session, Planning.get_planning_session!(id))}
  end

  @impl true
  def handle_event("start_voting", _value, socket) do
    {:ok, new_planning_session} = Planning.start_voting(socket.assigns.planning_session_id)
    {:noreply, assign(socket, :planning_session, new_planning_session)}
  end

  def handle_event("finish_voting", _value, socket) do
    {:ok, new_planning_session} = Planning.finish_voting(socket.assigns.planning_session_id)
    {:noreply, assign(socket, :planning_session, new_planning_session)}
  end

  def handle_event("commit_results", _value, socket) do
    {:ok, new_planning_session} = Planning.commit_results(socket.assigns.planning_session_id)
    {:noreply, assign(socket, :planning_session, new_planning_session)}
  end

  @impl true
  def handle_info({:state_change, new_planning_session}, socket) do
    {:noreply, assign(socket, :planning_session, new_planning_session)}
  end
end
