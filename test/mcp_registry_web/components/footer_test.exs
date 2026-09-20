defmodule McpRegistryWeb.FooterTest do
  use McpRegistryWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Everything the footer is allowed to point at off-site. gateway.mcpharbor.dev
  # is ours -- a sister property on the same root domain -- so it counts as an
  # internal link in spirit even though the host differs.
  @allowed_hosts ["seriouslysimpleanalytics.com", "gateway.mcpharbor.dev"]

  defp footer_html(conn) do
    {:ok, _view, html} = live(conn, ~p"/servers")
    [_, footer] = Regex.run(~r|<footer.*?>(.*?)</footer>|s, html)
    footer
  end

  test "the footer links off-site only to our own properties and the analytics vendor", %{
    conn: conn
  } do
    hosts =
      footer_html(conn)
      |> then(&Regex.scan(~r|href="https?://([^/"]+)|, &1))
      |> Enum.map(fn [_, host] -> String.replace_prefix(host, "www.", "") end)
      |> Enum.uniq()

    assert hosts -- @allowed_hosts == [],
           "unexpected external hosts in the footer: #{inspect(hosts -- @allowed_hosts)}"

    assert "seriouslysimpleanalytics.com" in hosts
    assert "gateway.mcpharbor.dev" in hosts
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
