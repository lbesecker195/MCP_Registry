defmodule McpRegistryWeb.FooterTest do
  use McpRegistryWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # The footer carries no outbound links at all -- not to third parties, not to
  # our own properties. The one exception is the DB-IP credit, which is a
  # CC BY 4.0 licence condition and renders only while that data is loaded.
  @allowed_hosts []

  defp footer_html(conn) do
    {:ok, _view, html} = live(conn, ~p"/servers")
    [_, footer] = Regex.run(~r|<footer.*?>(.*?)</footer>|s, html)
    footer
  end

  test "the footer carries no outbound links", %{conn: conn} do
    hosts =
      footer_html(conn)
      |> then(&Regex.scan(~r|href="https?://([^/"]+)|, &1))
      |> Enum.map(fn [_, host] -> String.replace_prefix(host, "www.", "") end)
      |> Enum.uniq()

    assert hosts -- @allowed_hosts == [],
           "unexpected external hosts in the footer: #{inspect(hosts -- @allowed_hosts)}"
  end

  test "the analytics credit survives as text, without a link", %{conn: conn} do
    footer = footer_html(conn)

    # Attribution is still owed and still wanted; it just no longer needs to be
    # a sitewide outbound link.
    assert footer =~ "Seriously Simple Analytics"
    refute footer =~ "seriouslysimpleanalytics.com"
  end

  test "the header links to the gateway", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/servers")
    [header] = Regex.run(~r|<header.*?</header>|s, html)

    assert header =~ "https://gateway.mcpharbor.dev"
  end

  test "the DB-IP credit follows whether the data is actually loaded", %{conn: conn} do
    original = Application.get_env(:mcp_registry, :geo_block)

    on_exit(fn ->
      if original,
        do: Application.put_env(:mcp_registry, :geo_block, original),
        else: Application.delete_env(:mcp_registry, :geo_block)
    end)

    # Off: nothing uses the database, so no credit is owed and none is shown.
    Application.put_env(:mcp_registry, :geo_block, loader: :geoip_city, cities: [])
    refute footer_html(conn) =~ "db-ip.com"

    # On: the credit is a CC BY 4.0 licence condition and must reappear by
    # itself, rather than depending on someone remembering to re-add it.
    Application.put_env(:mcp_registry, :geo_block,
      loader: :geoip_city,
      cities: [%{city: "Mountain View", country: "US"}]
    )

    assert footer_html(conn) =~ "db-ip.com"
  end
end
