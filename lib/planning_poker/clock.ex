defmodule PlanningPoker.Clock do
  @moduledoc """
  Clock abstraction to allow time-related code (token expiry, refresh scheduling)
  to be tested deterministically without `:timer.sleep` or real wall-clock waits.

  In production, `system_time/1` delegates to `System.system_time/1`.

  In tests, an alternative implementation can be configured via
  `Application.put_env(:planning_poker, :clock, FakeClockModule)`.
  The replacement module must export `system_time(unit)`.
  """

  @doc """
  Returns the current system time in the given unit.

  Delegates to the configured clock module (defaults to `System`).
  """
  def system_time(unit \\ :second) do
    impl().system_time(unit)
  end

  defp impl do
    Application.get_env(:planning_poker, :clock, System)
  end
end
