defmodule PlanningPoker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Validate that mock provider is not used in production
    validate_production_config()

    children = [
      PlanningPokerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:planning_poker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PlanningPoker.PubSub},
      PlanningPoker.Presence,
      # Start a worker by calling: PlanningPoker.Worker.start_link(arg)
      # {PlanningPoker.Worker, arg},
      {Task.Supervisor, name: PlanningPoker.TaskSupervisor},
      {Registry, [name: PlanningPoker.PlanningSession.Registry, keys: :unique]},
      {DynamicSupervisor, name: PlanningPoker.PlanningSession.Supervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      PlanningPokerWeb.Endpoint
    ]

    # Add mock provider GenServer if configured
    children = maybe_add_mock_provider(children)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PlanningPoker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp validate_production_config do
    # Use Application.get_env instead of Mix.env() since Mix is not available in releases
    if Application.get_env(:planning_poker, :env) == :prod do
      provider = PlanningPoker.IssueProvider.get_provider()

      if provider == PlanningPoker.IssueProviders.Mock do
        raise """
        FATAL: Mock issue provider cannot be used in production!

        The mock provider uses insecure authentication and is only intended for
        development and testing. Please set ISSUE_PROVIDER=gitlab in production.
        """
      end
    end
  end

  defp maybe_add_mock_provider(children) do
    if PlanningPoker.IssueProvider.get_provider() == PlanningPoker.IssueProviders.Mock do
      [{PlanningPoker.IssueProviders.Mock, []} | children]
    else
      children
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlanningPokerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
