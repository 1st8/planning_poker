defmodule PlanningPokerWeb.DevController do
  use PlanningPokerWeb, :controller

  @doc """
  Reset the planning session by killing the GenStatem process.
  Used by e2e tests to ensure clean state between tests.
  """
  def reset_session(conn, _params) do
    case Registry.lookup(PlanningPoker.PlanningSession.Registry, "default") do
      [{pid, _}] -> Process.exit(pid, :kill)
      [] -> :ok
    end

    json(conn, %{status: "ok"})
  end

  @doc """
  Gracefully halt the server.
  Used by e2e teardown to stop the server after tests complete.
  """
  def halt(conn, _params) do
    # Send response first, then halt
    conn = json(conn, %{status: "halting"})

    # Halt the VM after a short delay to allow the response to be sent
    spawn(fn ->
      Process.sleep(100)
      System.halt(0)
    end)

    conn
  end
end
