# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :planning_poker, PlanningPokerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PlanningPokerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PlanningPoker.PubSub,
  live_view: [signing_salt: "g3ulvRba"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger,
  level: :debug
  # handle_otp_reports: true,
  # handle_sasl_reports: true

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Enable login via Gitlab
config :ueberauth, Ueberauth,
  providers: [
    identity:
      {Ueberauth.Strategy.Identity,
       [
         callback_methods: ["POST"],
         uid_field: :email,
         nickname_field: :username
       ]},
    gitlab: {Ueberauth.Strategy.Gitlab, [default_scope: "api"]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
