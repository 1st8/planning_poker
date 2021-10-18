defmodule PlanningPoker.Planning do
  def get_planning_session!(id) do
    id |> to_pid |> :gen_statem.call(:get_state)
  end

  def start_voting(id) do
    id |> to_pid |> :gen_statem.call(:start_voting)
  end

  def finish_voting(id) do
    id |> to_pid |> :gen_statem.call(:finish_voting)
  end

  def commit_results(id) do
    id |> to_pid |> :gen_statem.call(:commit_results)
  end

  defp to_pid("default") do
    :default_planning_session
  end
end
