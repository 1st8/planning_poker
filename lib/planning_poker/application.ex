defmodule PlanningPoker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PlanningPokerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PlanningPoker.PubSub},
      # Start the Endpoint (http/https)
      PlanningPokerWeb.Endpoint,
      # Start a worker by calling: PlanningPoker.Worker.start_link(arg)
      # {PlanningPoker.Worker, arg}
      {Registry, [name: PlanningPoker.PlanningSession.Registry, keys: :unique]},
      {PlanningPoker.PlanningSession,
       name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, "default"}},
       args: %{id: "default"}}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PlanningPoker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlanningPokerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
