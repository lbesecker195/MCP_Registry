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
      McpRegistry.Cache,
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
  # The default source needs no account and no key, so the block is live on a
  # fresh deploy rather than sitting inert until someone registers.
  defp start_geoip_loader do
    config = Application.get_env(:mcp_registry, :geo_block, [])

    if Keyword.get(config, :cities, []) != [] do
      put_license_key(Keyword.get(config, :license_key))
      loader = Keyword.get(config, :loader, :geoip_city)

      case :locus.start_loader(loader, geoip_source(config)) do
        :ok ->
          Logger.info("GeoIP loader started; blocking begins once the database downloads")

        {:error, reason} ->
          Logger.warning("GeoIP loader failed to start (#{inspect(reason)}); geo blocking is off")
      end
    end

    :ok
  end

  defp put_license_key(key) when is_binary(key) and key != "",
    do: Application.put_env(:locus, :license_key, key)

  defp put_license_key(_), do: :ok

  # DB-IP publish a free city database under CC BY 4.0, with no account and no
  # licence key. Attribution is a condition of that licence and is rendered in
  # the site footer -- do not remove it there.
  #
  # The file is published monthly. Early in a month the current one can be a
  # few hours late, so a HEAD check falls back to the previous month, which is
  # always present, rather than leaving the loader retrying a 404 forever.
  defp geoip_source(config) do
    case Keyword.get(config, :source, :dbip) do
      {:url, url} ->
        url

      :maxmind ->
        {:maxmind, "GeoLite2-City"}

      :dbip ->
        today = Date.utc_today()
        current = dbip_url(today)

        if url_available?(current) do
          current
        else
          today |> Date.beginning_of_month() |> Date.add(-1) |> dbip_url()
        end
    end
  end

  defp dbip_url(%Date{year: year, month: month}) do
    padded = String.pad_leading("#{month}", 2, "0")
    "https://download.db-ip.com/free/dbip-city-lite-#{year}-#{padded}.mmdb.gz"
  end

  # A HEAD request only. Locus fetches the body itself, in the background,
  # after the loader starts, so boot is not waiting on 57MB.
  defp url_available?(url) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    case :httpc.request(:head, {String.to_charlist(url), []}, [timeout: 5_000], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 -> true
      _ -> false
    end
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    McpRegistryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
