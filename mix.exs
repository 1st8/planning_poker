defmodule PlanningPoker.MixProject do
  use Mix.Project

  def project do
    [
      app: :planning_poker,
      version: "0.6.2",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PlanningPoker.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:e2e), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:tidewave, "~> 0.5", only: [:dev]},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:tesla, "~> 1.14"},
      {:elixir_uuid, "~> 1.2"},
      {:ueberauth, "~> 0.7.0"},
      {:ueberauth_gitlab_strategy, "~> 0.4.0"},
      {:igniter, "~> 0.6.30"},
      {:earmark, "~> 1.4"},
      {:html_sanitize_ex, "~> 1.4"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind planning_poker", "esbuild planning_poker"],
      "assets.deploy": [
        "tailwind planning_poker --minify",
        "esbuild planning_poker --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"],
      e2e: ["cmd npm run e2e:test"],
      "e2e.ui": ["cmd npm run e2e:ui"],
      "e2e.headed": ["cmd npm run e2e:headed"],
      "e2e.debug": ["cmd npm run e2e:debug"]
    ]
  end
end
