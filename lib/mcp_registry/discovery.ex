defmodule McpRegistry.Discovery do
  @moduledoc """
  Tells search engines when listing pages appear, change or go away, rather
  than waiting for a crawler to find them among some 34,000 others.

  Two push channels, both a plain HTTP POST:

    * IndexNow (https://www.indexnow.org). Up to 10,000 URLs per request to
      `api.indexnow.org`. The participating engines (Bing, Yandex, Naver,
      Seznam, Yep) share every submission with each other, so one request
      reaches all of them. Ownership is proven by the key file that
      `McpRegistryWeb.Plugs.IndexNowKey` serves at `/<key>.txt`.
    * WebSub (https://www.w3.org/TR/websub/). A publish ping makes each hub
      named in `/feed.xml` fetch the feed again and push it to its subscribers.
      Google's Feedfetcher is one of them. Google accepts neither IndexNow nor
      sitemap pings, so WebSub is the only push channel it takes.

  The sitemap at `/sitemap.xml` covers anything these pushes miss.

  Calls are best-effort. A failure is logged and the sync or request that
  triggered the call carries on. With `enabled: false` (the default outside
  production) every call is a no-op, so a local sync never announces
  `localhost` URLs.
  """
  require Logger

  alias McpRegistry.{Analytics, Registry}
  alias McpRegistry.Discovery.Batcher
  alias McpRegistryWeb.{Endpoint, Routes}

  # The most URLs IndexNow takes in one request.
  @batch_size 10_000

  # Pages that are not listings, for the backfill.
  @static_paths ["/", "/servers", "/submit", "/book"]

  def config, do: Application.get_env(:mcp_registry, :discovery, [])

  def enabled?, do: config()[:enabled] == true

  def batch_size, do: @batch_size

  @doc """
  The IndexNow key. It is `:indexnow_key` when that is set. Otherwise it is
  derived from the endpoint's secret, so production needs no extra setting and
  the key stays the same across deploys. Anyone can fetch the key file, but
  deriving the key keeps it out of this public repository, so a stranger
  cannot use it to submit URLs in our name.
  """
  def indexnow_key do
    case config()[:indexnow_key] do
      key when is_binary(key) and key != "" ->
        key

      _ ->
        :crypto.hash(:sha256, "indexnow:" <> Endpoint.config(:secret_key_base))
        |> Base.encode16(case: :lower)
        |> binary_part(0, 32)
    end
  end

  def key_url, do: Endpoint.url() <> "/" <> indexnow_key() <> ".txt"

  def feed_url, do: Endpoint.url() <> "/feed.xml"

  @doc "The WebSub hubs `/feed.xml` declares and `announce/2` pings."
  def hubs, do: config()[:websub_hubs] || []

  def server_url(name), do: Endpoint.url() <> Routes.server_path(name)

  def static_urls, do: Enum.map(@static_paths, &(Endpoint.url() <> &1))

  @doc """
  Announces the listings named, whose pages appeared, changed or went away.
  Pass `feed: true` when the newest-listings feed changed too, so the WebSub
  hubs are pinged.

  At most `:max_urls_per_run` URLs are sent, earliest names first, so pass new
  listings before merely updated ones. Blocks until done and never raises.
  Returns `:disabled`, `:nothing_to_announce`, `{:error, reason}`, or a map of
  per-request outcomes.
  """
  def announce(names, opts \\ []) do
    safely(fn ->
      urls =
        names
        |> Enum.uniq()
        |> Enum.take(config()[:max_urls_per_run] || @batch_size)
        |> Enum.map(&server_url/1)

      feed? = Keyword.get(opts, :feed, false)

      if urls == [] and not feed? do
        :nothing_to_announce
      else
        report(%{
          indexnow: urls |> Enum.chunk_every(@batch_size) |> Enum.map(&submit/1),
          websub: if(feed?, do: Enum.map(hubs(), &publish/1), else: []),
          urls: length(urls)
        })
      end
    end)
  end

  @doc """
  `announce/2` in the background, for code on a request path: the names are
  batched with any others that arrive within `:batch_window_ms` (see
  `Discovery.Batcher`). A no-op when disabled, or outside a running application
  (a release `eval`).
  """
  def announce_later(names, opts \\ []) do
    if enabled?() and Process.whereis(Batcher) do
      Batcher.enqueue(names, Keyword.get(opts, :feed, false))
    end

    :ok
  end

  @doc """
  Submits every active listing and the static pages to IndexNow, in batches of
  #{@batch_size}, then pings the WebSub hubs. Use it once, as a backfill, when
  pushing starts, or after a domain move: `bin/announce` in production, or
  `mix discovery.announce` locally.
  """
  def announce_all do
    safely(fn ->
      pages = max(ceil(Registry.count_servers() / @batch_size), 1)
      pause = config()[:batch_pause_ms] || 0

      listings =
        for page <- 1..pages,
            urls =
              page |> Registry.sitemap_entries(@batch_size) |> Enum.map(&server_url(elem(&1, 0))),
            urls != [] do
          if page > 1, do: Process.sleep(pause)
          submit(urls)
        end

      report(%{
        indexnow: [submit(static_urls()) | listings],
        websub: Enum.map(hubs(), &publish/1),
        urls: Registry.count_servers() + length(@static_paths)
      })
    end)
  end

  defp safely(fun) do
    if enabled?() do
      try do
        fun.()
      rescue
        exception ->
          Logger.warning("Discovery failed: " <> Exception.message(exception))
          {:error, Exception.message(exception)}
      end
    else
      :disabled
    end
  end

  defp submit(urls) do
    body = %{
      host: URI.parse(Endpoint.url()).host,
      key: indexnow_key(),
      keyLocation: key_url(),
      urlList: urls
    }

    config()[:indexnow_endpoint]
    |> request()
    |> Req.post(json: body, headers: [{"content-type", "application/json; charset=utf-8"}])
    |> outcome("IndexNow", [200, 202])
  end

  defp publish(hub) do
    hub
    |> request()
    |> Req.post(form: %{"hub.mode" => "publish", "hub.url" => feed_url()})
    |> outcome("WebSub hub #{hub}", [200, 202, 204])
  end

  # Retries only failures that say nothing about us: a dropped connection or a
  # hub that is down. A 429 from IndexNow means "slow down"; hammering it again
  # is how a key gets flagged as spam.
  defp request(url) do
    [
      url: url,
      receive_timeout: 15_000,
      retry: fn _request, result ->
        match?(%Req.TransportError{}, result) or
          match?(%Req.Response{status: status} when status in [500, 502, 503, 504], result)
      end,
      max_retries: 2
    ]
    |> Keyword.merge(config()[:req_options] || [])
    |> Req.new()
    |> Req.Request.put_header("user-agent", user_agent())
  end

  defp outcome({:ok, %Req.Response{status: status}}, channel, ok) do
    if status in ok, do: {:ok, status}, else: {:error, "#{channel}: HTTP #{status}"}
  end

  defp outcome({:error, exception}, channel, _ok),
    do: {:error, "#{channel}: #{Exception.message(exception)}"}

  defp report(%{indexnow: indexnow, websub: websub, urls: urls} = result) do
    failed = Enum.reject(indexnow ++ websub, &match?({:ok, _}, &1))

    if failed == [] do
      Logger.info("Discovery: announced #{urls} URLs; #{length(websub)} hub(s) pinged")
    else
      Logger.warning("Discovery: #{length(failed)} request(s) failed: #{inspect(failed)}")
    end

    Analytics.track(:search_engines_notified, %{
      urls: urls,
      hubs: length(websub),
      outcome: if(failed == [], do: "success", else: "error")
    })

    result
  end

  defp user_agent do
    "mcp-registry/#{Application.spec(:mcp_registry, :vsn)} (+#{Endpoint.url()})"
  end
end
