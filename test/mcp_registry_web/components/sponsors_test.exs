defmodule McpRegistryWeb.SponsorsTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  test "the sponsored block sells the book on-site and the rest by email", %{conn: conn} do
    server = server_fixture()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    # The book tile goes to the landing page, not straight to Amazon: a cold
    # click from a 250px tile to a product page converts badly. The affiliate
    # link and its disclosure live on /book, covered in BookLiveTest.
    assert html =~ ~s(href="/book")
    refute html =~ "amzn.to"

    # Unsold slots open a pre-filled enquiry rather than going nowhere.
    assert html =~ "mailto:me@loganbesecker.com"
    assert html =~ "Interested%20Sponsor%20for%20MCP%20Harbor"
    assert html =~ "bidding%20%24____"

    # Spaces must not be encoded as "+", which mail clients paste literally
    # into the subject line.
    refute html =~ "Interested+Sponsor"
  end

  test "sponsor artwork is addressed through the static path helper", %{conn: conn} do
    server = server_fixture()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    # Plug.Static only answers with `max-age=31536000, immutable` for a request
    # carrying the asset digest; a bare path gets `cache-control: public` and
    # every repeat visit refetches roughly 1.8MB of artwork.
    #
    # The digest itself only exists once `mix phx.digest` has run, which is the
    # release build and not the test run — so what is pinned here is that the
    # markup asks the endpoint for the path rather than hardcoding it. Get that
    # wrong and production silently loses the caching.
    for file <- ~w(Book.png sponsor-1.png sponsor-2.png sponsor-3.png) do
      expected = McpRegistryWeb.Endpoint.static_path("/images/#{file}")
      assert html =~ ~s(src="#{expected}"), "#{file} was not addressed via static_path/1"
    end
  end
end
