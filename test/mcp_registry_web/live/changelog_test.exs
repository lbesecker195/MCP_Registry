defmodule McpRegistryWeb.ChangelogTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  alias McpRegistry.Changes.Change
  alias McpRegistry.Repo

  defp change!(server, attrs) do
    Repo.insert!(
      struct(
        Change,
        Map.merge(%{server_id: server.id, source: "probe", added: [], removed: []}, attrs)
      )
    )
  end

  defp with_history do
    server = server_fixture(%{title: "Weather"})
    change!(server, %{kind: "tools", added: ~w(get_radar), removed: ~w(get_legacy)})

    change!(server, %{
      kind: "server_json",
      source: "sync",
      fields: %{"version" => ["1.0.0", "1.1.0"]}
    })

    server
  end

  test "a listing's changelog shows each change, newest first", %{conn: conn} do
    server = with_history()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}/changelog")

    assert html =~ ~r{<h1[^>]*>\s*Weather changelog\s*</h1>}
    assert html =~ "get_radar"
    assert html =~ "get_legacy"
    assert html =~ "1.0.0"
    assert html =~ "1.1.0"
    assert html =~ "/changelog/server-json"
  end

  test "one kind of change has its own page", %{conn: conn} do
    server = with_history()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}/changelog/tools")

    assert html =~ "Weather Tools changelog"
    assert html =~ "get_radar"
    refute html =~ "1.1.0"
  end

  test "no history means no page, not an empty one", %{conn: conn} do
    server = server_fixture()

    assert {:error, {:live_redirect, %{to: to}}} = live(conn, "/servers/#{server.name}/changelog")
    assert to == "/servers/#{server.name}"
  end

  test "a kind the listing has none of, or no such kind, goes to its changelog", %{conn: conn} do
    server = with_history()

    for kind <- ["prompts", "gptbot"] do
      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/changelog/#{kind}")

      assert to == "/servers/#{server.name}/changelog"
    end
  end

  test "the listing links to its changelog only when there is one", %{conn: conn} do
    with = with_history()
    without = server_fixture()

    {:ok, _view, html} = live(conn, "/servers/#{with.name}")
    assert html =~ "/servers/#{with.name}/changelog"
    assert html =~ "changelog · 2"

    {:ok, _view, html} = live(conn, "/servers/#{without.name}")
    refute html =~ "/changelog"
  end

  test "the site-wide changelog lists recent changes and links into each listing", %{conn: conn} do
    server = with_history()
    {:ok, _view, html} = live(conn, "/changelog")

    assert html =~ "What changed in MCP servers"
    assert html =~ "get_radar"
    assert html =~ "/servers/#{server.name}/changelog"
  end

  test "the sitemap lists changelogs for listings that have them", %{conn: conn} do
    server = with_history()
    _quiet = server_fixture()

    index = conn |> get("/sitemap.xml") |> response(200)
    assert index =~ "/sitemaps/changelogs-1.xml"

    xml = conn |> get("/sitemaps/changelogs-1.xml") |> response(200)
    assert xml =~ "/servers/#{server.name}/changelog</loc>"
    assert xml =~ "/servers/#{server.name}/changelog/tools</loc>"
    assert xml =~ "/servers/#{server.name}/changelog/server-json</loc>"

    pages = conn |> get("/sitemaps/pages.xml") |> response(200)
    assert pages =~ "/changelog</loc>"
  end

  test "a listing whose only history is its llms.txt still gets a changelog", %{conn: conn} do
    server =
      server_fixture(%{name: "com.acme/docs-only", title: "Acme Docs", repository_url: nil})

    McpRegistry.Documents.discover()

    McpRegistry.Changes.record_document("https://acme.com/llms.txt", "llms_txt", %{
      added: ["- [Pricing](/pricing.md)"],
      removed: ["- [Old pricing](/old.md)"]
    })

    {:ok, _view, html} = live(conn, "/servers/#{server.name}/changelog/llms-txt")

    assert html =~ "Acme Docs llms.txt changelog"
    assert html =~ "https://acme.com/llms.txt"
    assert html =~ "[Pricing](/pricing.md)"
    assert html =~ "<pre"

    xml = conn |> get("/sitemaps/changelogs-1.xml") |> response(200)
    assert xml =~ "/servers/#{server.name}/changelog/llms-txt</loc>"

    {:ok, _view, html} = live(conn, "/changelog")
    assert html =~ "Acme Docs"
    assert html =~ "[Pricing](/pricing.md)"
  end

  test "no history anywhere means no changelog file", %{conn: conn} do
    server_fixture()

    refute conn |> get("/sitemap.xml") |> response(200) =~ "changelogs-1.xml"
    assert conn |> get("/sitemaps/changelogs-1.xml") |> response(404) == ""
  end
end
