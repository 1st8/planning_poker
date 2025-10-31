defmodule PlanningPokerWeb.PageControllerTest do
  use PlanningPokerWeb.ConnCase

  test "GET / redirects to /participate when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/participate"
  end
end
