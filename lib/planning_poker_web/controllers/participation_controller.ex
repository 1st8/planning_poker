defmodule PlanningPokerWeb.ParticipationController do
  use PlanningPokerWeb, :controller

  alias PlanningPoker.IssueProvider

  def new(conn, _params) do
    conn
    |> assign(:current_user, conn |> get_session(:current_user))
    |> assign(:provider, IssueProvider.get_provider())
    |> render(:new)
  end
end
