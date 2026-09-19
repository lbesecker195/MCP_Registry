defmodule McpRegistryWeb.Plugs.GeoBlockTest do
  @moduledoc """
  The behaviour that matters most here is the *negative* one: this plug sits in
  front of every request, so a geo database that is missing, stale or wrong
  must never stop the site serving.

  The database itself is injected through the `:lookup` option, so these cover
  the real matching rules and the real 403 path without a MaxMind licence key.
  """
  use McpRegistryWeb.ConnCase, async: false

  alias McpRegistryWeb.Plugs.GeoBlock

  # MaxMind gives a subdivision an iso_code; DB-IP Lite gives it only a name.
  # Both real shapes are pinned, because the difference is silent: a rule
  # written for one database simply never matches against the other.
  @maxmind %{
    "city" => %{"names" => %{"en" => "Mountain View"}},
    "subdivisions" => [%{"iso_code" => "CA"}],
    "country" => %{"iso_code" => "US"}
  }

  @dbip %{
    "city" => %{"names" => %{"en" => "Mountain View"}},
    "subdivisions" => [%{"names" => %{"en" => "California"}}],
    "country" => %{"iso_code" => "US", "names" => %{"en" => "United States"}},
    "location" => %{"latitude" => 37.422, "longitude" => -122.085}
  }

  @mountain_view @dbip

  # The rule that actually ships: it lists both spellings, because neither one
  # alone matches both databases.
  @rule [
    %{
      city: "Mountain View",
      subdivision: ["California", "CA"],
      country: ["United States", "US"]
    }
  ]

  @public_ip {93, 184, 216, 34}

  setup do
    original = Application.get_env(:mcp_registry, :geo_block)

    on_exit(fn ->
      if original do
        Application.put_env(:mcp_registry, :geo_block, original)
      else
        Application.delete_env(:mcp_registry, :geo_block)
      end
    end)

    :ok
  end

  defp configure(cities, lookup) do
    Application.put_env(:mcp_registry, :geo_block,
      loader: :geoip_city_test,
      cities: cities,
      lookup: lookup
    )
  end

  defp always(entry), do: fn _ip -> entry end

  describe "matching a blocked city" do
    test "blocks an address in the configured city" do
      configure(@rule, always(@mountain_view))

      assert GeoBlock.blocked?(@public_ip)
    end

    test "the shipped rule matches both database shapes" do
      for entry <- [@dbip, @maxmind] do
        configure(@rule, always(entry))
        assert GeoBlock.blocked?(@public_ip), "expected #{inspect(entry)} to match"
      end
    end

    test "a rule naming one spelling only matches the database that uses it" do
      # This is the trap the shipped rule avoids: "CA" is MaxMind's spelling,
      # so against DB-IP it matches nothing and the block quietly does not fire.
      iso_only = [%{city: "Mountain View", subdivision: "CA", country: "US"}]

      configure(iso_only, always(@maxmind))
      assert GeoBlock.blocked?(@public_ip)

      configure(iso_only, always(@dbip))
      refute GeoBlock.blocked?(@public_ip)
    end

    test "allows a different city" do
      configure(@rule, always(put_city(@mountain_view, "San Jose")))

      refute GeoBlock.blocked?(@public_ip)
    end

    test "allows the same city name in another state or country" do
      configure(@rule, always(put_subdivision(@mountain_view, "Arkansas")))
      refute GeoBlock.blocked?(@public_ip)

      configure(
        @rule,
        always(%{put_country(@mountain_view, "CA") | "country" => %{"iso_code" => "CA"}})
      )

      refute GeoBlock.blocked?(@public_ip)
    end

    test "matches case-insensitively" do
      configure(@rule, always(put_city(@mountain_view, "MOUNTAIN VIEW")))

      assert GeoBlock.blocked?(@public_ip)
    end
  end

  describe "failing open" do
    test "allows everything when no cities are configured" do
      configure([], always(@mountain_view))

      refute GeoBlock.blocked?(@public_ip)
    end

    test "allows when the database has no answer" do
      configure(@rule, always(nil))

      refute GeoBlock.blocked?(@public_ip)
    end

    test "allows when the entry is missing the fields a rule names" do
      configure(@rule, always(%{"country" => %{"iso_code" => "US"}}))

      refute GeoBlock.blocked?(@public_ip)
    end

    test "allows a public address when no loader is running" do
      # No :lookup override, and no loader started under that name -- the real
      # locus call fails. A failed lookup must not block, or a database that
      # did not download would take the whole site offline.
      Application.put_env(:mcp_registry, :geo_block,
        loader: :geoip_city_not_started,
        cities: @rule
      )

      refute GeoBlock.blocked?(@public_ip)
    end

    test "never blocks loopback, private or link-local addresses" do
      configure(@rule, always(@mountain_view))

      for ip <- [
            {127, 0, 0, 1},
            {10, 1, 2, 3},
            {192, 168, 0, 5},
            {172, 20, 0, 1},
            {169, 254, 1, 1},
            {0, 0, 0, 0, 0, 0, 0, 1}
          ] do
        refute GeoBlock.blocked?(ip), "expected #{inspect(ip)} to be allowed"
      end
    end
  end

  describe "the response" do
    test "a blocked request gets 403 and never reaches the router" do
      configure(@rule, always(@mountain_view))

      conn =
        Phoenix.ConnTest.build_conn()
        |> Map.put(:remote_ip, @public_ip)
        |> GeoBlock.call([])

      assert conn.status == 403
      assert conn.halted
      assert conn.resp_body =~ "not available from your location"
    end

    test "an allowed request passes straight through" do
      configure(@rule, always(put_city(@mountain_view, "Berlin")))

      conn =
        Phoenix.ConnTest.build_conn()
        |> Map.put(:remote_ip, @public_ip)
        |> GeoBlock.call([])

      refute conn.halted
      refute conn.status
    end

    test "the site still serves while the block is inert", %{conn: conn} do
      configure(@rule, always(nil))

      assert conn |> get("/") |> html_response(200)
    end
  end

  defp put_city(entry, name), do: put_in(entry, ["city", "names", "en"], name)

  defp put_subdivision(entry, name),
    do: %{entry | "subdivisions" => [%{"names" => %{"en" => name}}]}

  defp put_country(entry, code), do: put_in(entry, ["country", "iso_code"], code)
end
