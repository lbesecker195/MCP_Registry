defmodule McpRegistryWeb.SponsorSidebarTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  alias McpRegistry.Changes.Change
  alias McpRegistry.Repo

  # Tile image sources in the order they render.
  defp tiles(html) do
    ~r{<img src="/images/(Book|sponsor-\d)[^"]*"}
    |> Regex.scan(html)
    |> Enum.map(&List.last/1)
  end

  test "the book opens and closes the block, with the three slots between", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/servers")
    assert tiles(html) == ["Book", "sponsor-1", "sponsor-2", "sponsor-3", "Book"]
  end

  test "every page type carries the sponsor sidebar", %{conn: conn} do
    server =
      server_fixture(%{
        title: "Weather",
        tools: ~w(get_forecast),
        prompts: ~w(review_diff),
        resources: ["file:///alerts.json"]
      })

    Repo.insert!(%Change{server_id: server.id, kind: "tools", source: "probe", added: ["x"]})
    base = "/servers/#{server.name}"

    pages = [
      "/",
      "/servers",
      "/submit",
      "/changelog",
      base,
      base <> "/for/cursor",
      base <> "/tools",
      base <> "/tools/get_forecast",
      base <> "/tools/get_forecast/cursor",
      base <> "/prompts",
      base <> "/prompts/review-diff",
      base <> "/prompts/review-diff/cursor",
      base <> "/resources",
      base <> "/resources/file-alerts-json",
      base <> "/resources/file-alerts-json/cursor",
      base <> "/changelog",
      base <> "/changelog/tools"
    ]

    for path <- pages do
      html = conn |> get(path) |> html_response(200)

      assert html =~ "sponsors-heading", "#{path} has no sponsor block"

      assert html =~ ~s(phx-hook="McpRegistryWeb.Layouts.StickySidebar"),
             "#{path} sidebar not pinned"

      assert tiles(html) == ["Book", "sponsor-1", "sponsor-2", "sponsor-3", "Book"], path
    end
  end

  test "the book's own page does not advertise itself", %{conn: conn} do
    html = conn |> get("/book") |> html_response(200)
    refute html =~ "sponsors-heading"
  end
end
