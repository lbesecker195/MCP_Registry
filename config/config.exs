# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mcp_registry,
  ecto_repos: [McpRegistry.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :mcp_registry, McpRegistryWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: McpRegistryWeb.ErrorHTML, json: McpRegistryWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: McpRegistry.PubSub,
  live_view: [signing_salt: "Zg13WBT8"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mcp_registry: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  mcp_registry: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# The install hub on /servers/* lets you type a real API token in to have it
# substituted into the snippet. That value rides a LiveView event, so keep it
# out of the logs.
config :phoenix, :filter_parameters, ["password", "secret", "secrets", "token"]

# Seriously Simple Analytics (https://seriouslysimpleanalytics.com).
# One account ID drives both the browser tag in the root layout and the
# server-side pings in McpRegistry.Analytics. Set SSA_ACCOUNT_ID at runtime;
# with no ID configured, analytics is a no-op.
config :mcp_registry, :analytics,
  account_id: nil,
  project: "mcp-registry"

# API publishing (POST /api/v0/servers) requires a bearer token. Leave it nil
# to disable API publishing; the /submit web form still works.
config :mcp_registry, :registry, publish_token: nil

# Anonymous submissions (JSON API and MCP) go to review. Each client address
# may submit this many per hour, and the review queue is capped so a flood of
# submissions cannot fill the database.
config :mcp_registry, :submissions,
  per_client_per_hour: 10,
  max_pending: 500

# Copy the official MCP Registry's catalogue on a schedule. Enabled in
# production from config/runtime.exs; run `mix registry.sync_official` locally.
config :mcp_registry, :official_registry,
  base_url: "https://registry.modelcontextprotocol.io",
  page_size: 100,
  page_delay_ms: 250,
  sync_enabled: false,
  sync_interval_ms: :timer.hours(6),
  full_sync_every_ms: :timer.hours(24 * 7),
  initial_delay_ms: :timer.minutes(2),
  req_options: []

# Pushes new and changed listing pages to search engines (McpRegistry.Discovery).
# Off by default so a dev or test sync never announces localhost URLs; the key
# is derived from secret_key_base unless :indexnow_key is set.
config :mcp_registry, :discovery,
  enabled: false,
  indexnow_endpoint: "https://api.indexnow.org/indexnow",
  indexnow_key: nil,
  websub_hubs: ["https://pubsubhubbub.appspot.com/"],
  max_urls_per_run: 10_000,
  batch_window_ms: :timer.minutes(1),
  batch_pause_ms: :timer.seconds(5),
  req_options: []

# Asks remote listings what tools they expose (McpRegistry.Probe). Paced
# slowly on purpose: these are other people's servers, and a first pass over
# ~21,000 endpoints takes about a day and a half at this rate. Enabled only in
# prod, via runtime.exs.
config :mcp_registry, :probe,
  enabled: false,
  batch_size: 50,
  concurrency: 4,
  recheck_days: 14,
  interval_ms: :timer.minutes(5),
  initial_delay_ms: :timer.minutes(3),
  req_options: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
