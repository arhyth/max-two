# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :max_two,
  environment: config_env(),
  ecto_repos: [MaxTwo.Repo],
  # Set users service behaviour implementation
  users_service: MaxTwo.Users,
  # Set users sidecar implementation
  users_sidecar: MaxTwo.Users.GenSidecar

config :max_two, MaxTwo.Repo,
  pool_size: 20

# Configures the endpoint
config :max_two, MaxTwoWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: MaxTwoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MaxTwo.PubSub,
  live_view: [signing_salt: "Lnwi5ar4"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# MaxTwo context/service and sidecar config
config :max_two, MaxTwo,
  # interval between update starts, in milliseconds
  update_interval_ms: 60_000,
  # number of rows fetched from DB on each query
  page_limit: 20_000,
  # count of users streamed to Flow stage/partitions
  # to trigger actual repo update
  trigger_interval: 4_000,
  # minimum cooldown between updates
  min_cooldown_ms: 10_000

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
