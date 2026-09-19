defmodule McpRegistryWeb.Plugs.GeoBlock do
  @moduledoc """
  Refuses requests that geolocate to a blocked city.

  Configured in `config/runtime.exs`:

      config :mcp_registry, :geo_block,
        loader: :geoip_city,
        source: :dbip,
        cities: [
          %{
            city: "Mountain View",
            subdivision: ["California", "CA"],
            country: ["United States", "US"]
          }
        ]

  A rule value may be one string or a list of acceptable spellings, and the
  list earns its keep: MaxMind records a subdivision as `"CA"` while DB-IP
  records it as `"California"`. A rule naming only one of them matches only
  one database and gives no sign of it — the block simply never fires.

  The default source is DB-IP's free city database, which needs no account and
  no key, so this works on a fresh deploy. It is CC BY 4.0 and the required
  credit is in the site footer.

  ## It fails open, on purpose

  Every path that is not a confident match is allowed through: no database
  loaded, no licence key, a lookup error, a private or loopback address, an
  address the database does not know. A geo-IP database that failed to
  download must never take the whole site off the air, so the only outcome
  that blocks is a successful lookup that positively matches a blocked city.

  `McpRegistryWeb.Plugs.ClientIP` runs first in the endpoint, so `remote_ip`
  is the real client rather than nginx.

  ## What this can and cannot do

  City-level geo-IP is an estimate. Published accuracy for GeoLite2 at city
  level is roughly 60-80% within 50km, so some visitors in the blocked city
  get through and some nearby ones are stopped. VPN and mobile traffic is
  weaker still. Treat it as a coarse filter, not a boundary.

  It is also worth knowing that some of Google's own crawler addresses
  geolocate to Mountain View. Blocking that city can therefore block part of
  Googlebot, which would cost search visibility. Nothing here exempts
  crawlers — if that trade is unwanted, exempt them here rather than
  discovering it in Search Console.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if blocked?(conn.remote_ip) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(:forbidden, "This site is not available from your location.")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Whether an address geolocates to one of the blocked cities.

  False whenever the answer is not a confident yes -- see the module note on
  failing open.
  """
  def blocked?(ip) do
    config = Application.get_env(:mcp_registry, :geo_block, [])
    cities = Keyword.get(config, :cities, [])

    cond do
      cities == [] -> false
      special?(ip) -> false
      true -> ip |> lookup(config) |> matches_any?(cities)
    end
  end

  # `:lookup` lets the test suite supply a database response, so the matching
  # rules and the 403 path are covered without a MaxMind licence key in CI.
  defp lookup(ip, config) do
    case Keyword.get(config, :lookup) do
      fun when is_function(fun, 1) -> fun.(ip)
      _ -> locus_lookup(ip, Keyword.get(config, :loader, :geoip_city))
    end
  end

  # Loopback, private and link-local ranges never geolocate to anything useful,
  # and blocking them would take out local development and health checks.
  defp special?({127, _, _, _}), do: true
  defp special?({10, _, _, _}), do: true
  defp special?({192, 168, _, _}), do: true
  defp special?({172, second, _, _}) when second in 16..31, do: true
  defp special?({169, 254, _, _}), do: true
  defp special?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp special?(_), do: false

  defp locus_lookup(ip, loader) do
    case :locus.lookup(loader, ip) do
      {:ok, entry} -> entry
      _ -> nil
    end
  rescue
    # A loader that was never started raises rather than returning an error.
    _ -> nil
  catch
    :exit, _ -> nil
  end

  defp matches_any?(nil, _cities), do: false

  defp matches_any?(entry, cities) do
    place = %{
      city: [get_in(entry, ["city", "names", "en"])],
      subdivision: entry |> Map.get("subdivisions", []) |> List.first() |> subdivision_names(),
      country: [
        get_in(entry, ["country", "iso_code"]),
        get_in(entry, ["country", "names", "en"])
      ]
    }

    # A city name alone is not unique -- there is a Mountain View in several
    # US states -- so every key the rule names has to agree.
    Enum.any?(cities, fn rule ->
      Enum.all?(rule, fn {key, value} ->
        matches?(Map.get(place, key, []), value)
      end)
    end)
  end

  # The two databases disagree here, and the disagreement is silent: MaxMind
  # gives a subdivision an `iso_code` ("CA"), DB-IP Lite gives it only a name
  # ("California"). Collecting both means one rule works against either, rather
  # than a rule that quietly never matches after a database swap.
  defp subdivision_names(%{} = subdivision) do
    [Map.get(subdivision, "iso_code"), get_in(subdivision, ["names", "en"])]
  end

  defp subdivision_names(_), do: []

  # A rule value may be a single string or a list of acceptable spellings.
  # The list matters: MaxMind records the subdivision as "CA" and DB-IP as
  # "California", so a rule naming only one of them matches only one database,
  # and does so silently.
  defp matches?(candidates, expected) do
    wanted = expected |> List.wrap() |> Enum.map(&String.downcase/1)

    Enum.any?(candidates, fn
      nil -> false
      actual -> String.downcase(actual) in wanted
    end)
  end
end
