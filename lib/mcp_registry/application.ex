defmodule McpRegistry.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    start_geoip_loader()

    children = [
      McpRegistryWeb.Telemetry,
      McpRegistry.Repo,
      {DNSCluster, query: Application.get_env(:mcp_registry, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: McpRegistry.PubSub},
      {Task.Supervisor, name: McpRegistry.AnalyticsSupervisor},
      McpRegistry.RateLimiter,
      McpRegistry.OfficialRegistry.Scheduler,
      # Start a worker by calling: McpRegistry.Worker.start_link(arg)
      # {McpRegistry.Worker, arg},
      # Start to serve requests, typically the last entry
      McpRegistryWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: McpRegistry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Starts the MaxMind city database used by
  # `McpRegistryWeb.Plugs.GeoBlock`. Locus downloads and refreshes it in the
  # background, so boot is not blocked on the download and the first requests
  # after a restart simply see no database yet -- which the plug treats as
  # "allow", like every other uncertain case.
  #
  # With no licence key configured the loader is not started at all and the
  # geo block is inert. That is the intended behaviour for development and for
  # any deploy that has not been given a key, not an error.
  defp start_geoip_loader do
    config = Application.get_env(:mcp_registry, :geo_block, [])

    with true <- Keyword.get(config, :cities, []) != [],
         key when is_binary(key) and key != "" <- Keyword.get(config, :license_key) do
      :ok = Application.put_env(:locus, :license_key, key)

      case :locus.start_loader(
             Keyword.get(config, :loader, :geoip_city),
             {:maxmind, "GeoLite2-City"}
           ) do
        :ok ->
          Logger.info("GeoIP loader started; geo blocking is active")

        {:error, reason} ->
          Logger.warning("GeoIP loader failed to start (#{inspect(reason)}); geo blocking is off")
      end
    else
      _ -> :ok
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    McpRegistryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
