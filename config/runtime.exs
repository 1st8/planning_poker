import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :planning_poker, PlanningPokerWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    url: [host: System.get_env("HOST", "example.com"), port: 80],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:

  config :planning_poker, PlanningPokerWeb.Endpoint, server: true

  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end

redirect_uri =
  if config_env() == :dev && System.get_env("HOST") == nil do
    "http://localhost:4000"
  else
    "https://" <> System.get_env("HOST", "example.com")
  end <> "/auth/gitlab/callback"

config :ueberauth, Ueberauth.Strategy.Gitlab.OAuth,
  site: System.get_env("GITLAB_SITE", "https://gitlab.com"),
  authorize_url: System.get_env("GITLAB_SITE", "https://gitlab.com") <> "/oauth/authorize",
  token_url: System.get_env("GITLAB_SITE", "https://gitlab.com") <> "/oauth/token",
  client_id: System.get_env("GITLAB_CLIENT_ID"),
  client_secret: System.get_env("GITLAB_CLIENT_SECRET"),
  redirect_uri: redirect_uri
