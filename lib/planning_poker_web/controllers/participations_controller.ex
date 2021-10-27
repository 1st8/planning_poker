defmodule PlanningPokerWeb.ParticipationsController do
  use PlanningPokerWeb, :controller

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, params) do
    conn
    |> put_session(:participant, %{id: UUID.uuid4(), name: Map.fetch!(params, "name")})
    |> redirect(to: "/")
  end
end
