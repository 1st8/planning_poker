defmodule PlanningPokerWeb.TimerComponent do
  use PlanningPokerWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      phx-hook="VotingTimer"
      seconds={seconds_since(@started_at)}
    />
    """
  end

  def seconds_since(datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :seconds)
  end
end
