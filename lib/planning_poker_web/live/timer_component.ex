defmodule PlanningPokerWeb.TimerComponent do
  use PlanningPokerWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="VotingTimer"
      seconds={@seconds}
    />
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
