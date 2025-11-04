import Config

# Store the environment for runtime checks (since Mix.env() is not available in releases)
config :planning_poker, :env, :test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :planning_poker, PlanningPokerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EyshxAr/484macsMekOSZstch+j/WYdqOi2dDbL6hnkCMyCoKoqz5f7lblGI0C7o",
  server: false

# In test we don't send emails
config :planning_poker, PlanningPoker.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
