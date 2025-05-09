defmodule PlanningPokerWeb.ParticipationController do
  use PlanningPokerWeb, :controller

  def new(conn, _params) do
    conn
    |> assign(:current_user, conn |> get_session(:current_user))
    |> render(:new)
  end
end
