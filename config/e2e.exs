import Config

# Enable dev routes (for /dev/reset_session endpoint used by e2e tests)
config :planning_poker, dev_routes: true

# Configure the endpoint for E2E tests
config :planning_poker, PlanningPokerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4004],
  secret_key_base: "E2ETestSecretKeyBaseE2ETestSecretKeyBaseE2ETestSecretKeyBaseE2ETestSecretKeyBaseE2ETestSecretKeyBase",
  server: true,
  live_view: [signing_salt: "e2e_test_salt"],
  check_origin: false

# Use mock issue provider for E2E tests
System.put_env("ISSUE_PROVIDER", "mock")

# In E2E we don't send emails
config :planning_poker, PlanningPoker.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client
config :swoosh, :api_client, false

# Print only warnings and errors during E2E tests
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
