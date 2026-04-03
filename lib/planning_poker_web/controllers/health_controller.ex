defmodule PlanningPokerWeb.HealthController do
  use PlanningPokerWeb, :controller

  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
