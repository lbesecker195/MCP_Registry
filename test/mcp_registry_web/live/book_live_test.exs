defmodule McpRegistryWeb.BookLiveTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the landing page renders the book's real facts", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/book")

    # Every one of these is checkable against the product listing in one click,
    # so none of them may drift.
    assert html =~ "MCP Server Optimization"
    assert html =~ "Logan R Besecker"
    assert html =~ "244"
    assert html =~ "979-8174638471"
    assert html =~ "$29.99"
    assert html =~ "$49.99"
    assert html =~ "September 15, 2026"
  end

  test "the buy links are affiliate-marked and disclosed", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/book")

    assert html =~ "https://amzn.to/4cPvd4j"
    assert html =~ ~s(rel="sponsored noopener noreferrer")
    assert html =~ "affiliate links"
    assert html =~ "maintains MCP Harbor"
  end

  test "no rating or bestseller claim is made", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/book")

    # The book has no ratings. Marking one up would be a lie a reader can check
    # in one click, and a structured-data manual-action risk.
    refute html =~ "aggregateRating"
    refute html =~ "ratingValue"
    refute html =~ ~r/best\s*seller/i
    refute html =~ ~r/\d(\.\d)?\s*(out of 5|stars)/i
  end

  test "it carries valid Book structured data", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/book")

    # Greedy up to the closing tag: the earlier non-greedy `\{.*?\}` stopped at
    # the first brace, which JSON nesting makes useless.
    # `[^>]*` around the type: LiveView injects its own attributes into the tag.
    [_, body] = Regex.run(~r|<script[^>]*ld\+json[^>]*>(.*?)</script>|s, html)

    assert {:ok, data} = body |> String.trim() |> Jason.decode()
    assert data["@type"] == "Book"
    assert data["isbn"] == "979-8174638471"
    assert data["numberOfPages"] == 244
    assert length(data["offers"]) == 2
    refute Map.has_key?(data, "aggregateRating")
  end

  test "the sidebar slot points here rather than straight at Amazon", %{conn: conn} do
    server = McpRegistry.RegistryFixtures.server_fixture()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    # A cold click from a 250px tile to a product page converts badly; the
    # landing page is the intermediate step that does the selling.
    assert html =~ ~s(href="/book")
    refute html =~ "amzn.to"
  end
end
