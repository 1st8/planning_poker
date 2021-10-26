defmodule PlanningPoker.Issues do
  import PlanningPoker.Planning, only: [to_pid: 1]

  def list_issues!(id) do
    id |> to_pid |> :gen_statem.call(:list_issues)
  end

end
