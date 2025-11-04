ExUnit.start()

# Start the application in E2E mode
{:ok, _} = Application.ensure_all_started(:planning_poker)

# Wait for the server to be ready
Process.sleep(1000)

IO.puts("E2E Test Server started on http://localhost:4004")

# Keep the process alive
Process.sleep(:infinity)
