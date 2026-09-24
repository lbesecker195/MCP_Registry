defmodule McpRegistryWeb.ServerLive.CapabilitiesTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  alias McpRegistry.Registry.Capability

  defp with_both do
    server_fixture(%{
      title: "Weather",
      tools: ~w(get_forecast),
      prompts: ~w(review_diff summarise_issue),
      resources: ["file:///alerts.json", "https://example.test/api/stations"]
    })
  end

  describe "slugging" do
    test "a resource URI becomes one path segment" do
      # URI.encode/1 leaves `/` alone, so file:///alerts.json would have been
      # three segments and matched no route at all.
      slug = Capability.slug("file:///alerts.json")

      refute slug =~ "/"
      assert slug == "file-alerts-json"
    end

    test "http and https are dropped, other schemes kept" do
      assert Capability.slug("https://example.test/a") == "example-test-a"
      assert Capability.slug("file:///a") == "file-a"
      assert Capability.slug("ui://widget/x") == "ui-widget-x"
    end

    test "find matches on the slug, so a rewritten name is still reachable" do
      items = ["file:///alerts.json", "review_diff"]

      assert Capability.find(items, "file-alerts-json") == "file:///alerts.json"
      assert Capability.find(items, "review-diff") == "review_diff"
      assert Capability.find(items, "nope") == nil
    end
  end

  describe "the prompts silo" do
    test "lists every prompt and links each one", %{conn: conn} do
      server = with_both()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/prompts")

      assert html =~ "Weather MCP Prompts"
      assert html =~ "review_diff"
      assert html =~ "/prompts/review-diff"
      # The word people do not search for must not come back.
      refute html =~ "MCP Skills"
    end

    test "H1 and H2 on a client page name the prompt", %{conn: conn} do
      server = with_both()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/prompts/review-diff/cursor")

      assert html =~ ~r{<h1[^>]*>\s*Cursor Weather Prompt/review_diff\s*</h1>}
      assert html =~ "How to: Cursor Weather review_diff"
    end

    test "says a prompt is invoked, not called for you", %{conn: conn} do
      server = with_both()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/prompts/review-diff/claude-code")

      assert html =~ "slash command"
      assert html =~ "will not call it for you"
    end

    test "a listing with no prompts redirects rather than showing an empty page", %{conn: conn} do
      server = server_fixture(%{prompts: [], resources: []})

      assert {:error, {:live_redirect, %{to: to}}} = live(conn, "/servers/#{server.name}/prompts")
      assert to == "/servers/#{server.name}"
    end
  end

  describe "the resources silo" do
    test "lists every resource, shortened, with its scheme", %{conn: conn} do
      server = with_both()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/resources")

      assert html =~ "Weather MCP Resources"
      assert html =~ "alerts.json"
      # https is stripped for display; the scheme badge carries file.
      assert html =~ "example.test/api/stations"
      assert html =~ "/resources/file-alerts-json"
    end

    test "H1 and H2 on a client page name the resource", %{conn: conn} do
      server = with_both()

      {:ok, _view, html} =
        live(conn, "/servers/#{server.name}/resources/file-alerts-json/cursor")

      assert html =~ ~r{<h1[^>]*>\s*Cursor Weather Resource/file:///alerts\.json\s*</h1>}
      assert html =~ "How to: Cursor Weather file:///alerts.json"
    end

    test "describes a resource as context to attach, not an action", %{conn: conn} do
      server = with_both()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/resources")

      assert html =~ "attach as context"
      refute html =~ "will not call it for you"
    end

    test "a listing with no resources redirects", %{conn: conn} do
      server = server_fixture(%{prompts: ~w(only_prompt), resources: []})

      assert {:error, {:live_redirect, %{to: to}}} = live(conn, "/servers/#{server.name}/resources")
      assert to == "/servers/#{server.name}"
    end
  end

  test "each silo points at the other", %{conn: conn} do
    server = with_both()

    {:ok, _view, prompts} = live(conn, "/servers/#{server.name}/prompts")
    assert prompts =~ "/resources"

    {:ok, _view, resources} = live(conn, "/servers/#{server.name}/resources")
    assert resources =~ "/prompts"
  end

  test "an unknown item or client falls back rather than 404ing", %{conn: conn} do
    server = with_both()

    assert {:error, {:live_redirect, %{to: to}}} =
             live(conn, "/servers/#{server.name}/prompts/not_a_prompt")

    assert to == "/servers/#{server.name}"

    assert {:error, {:live_redirect, %{to: to}}} =
             live(conn, "/servers/#{server.name}/prompts/review-diff/gptbot")

    assert to == "/servers/#{server.name}/prompts/review-diff"
  end

  test "/skills 301s to prompts, at every depth", %{conn: conn} do
    server = with_both()

    assert conn |> get("/servers/#{server.name}/skills") |> redirected_to(301) ==
             "/servers/#{server.name}/prompts"

    assert conn |> get("/servers/#{server.name}/skills/review_diff/cursor") |> redirected_to(301) ==
             "/servers/#{server.name}/prompts"
  end

  test "an unknown listing still redirects home with a 301", %{conn: conn} do
    assert conn |> get("/servers/io.github.nobody/nothing/prompts") |> redirected_to(301) == "/"
  end

  describe "the sitemap" do
    test "carries index, item and client URLs for both kinds", %{conn: conn} do
      server = with_both()

      prompts = conn |> get("/sitemaps/prompts-1.xml") |> response(200)
      assert prompts =~ "/servers/#{server.name}/prompts</loc>"
      assert prompts =~ "/servers/#{server.name}/prompts/review-diff</loc>"
      assert prompts =~ "/prompts/review-diff/cursor</loc>"

      resources = conn |> get("/sitemaps/resources-1.xml") |> response(200)
      assert resources =~ "/servers/#{server.name}/resources</loc>"
      assert resources =~ "/resources/file-alerts-json</loc>"

      index = conn |> get("/sitemap.xml") |> response(200)
      assert index =~ "/sitemaps/prompts-1.xml"
      assert index =~ "/sitemaps/resources-1.xml"
      refute index =~ "skills"
    end

    test "nothing anywhere means no file, and a 404 rather than an empty 200", %{conn: conn} do
      server_fixture(%{prompts: [], resources: []})

      index = conn |> get("/sitemap.xml") |> response(200)
      refute index =~ "prompts-1.xml"
      refute index =~ "resources-1.xml"

      assert conn |> get("/sitemaps/prompts-1.xml") |> response(404) == ""
      assert conn |> get("/sitemaps/resources-1.xml") |> response(404) == ""
    end
  end

  test "every page in both silos is indexable", %{conn: conn} do
    server = with_both()

    paths = [
      "/prompts",
      "/prompts/review-diff",
      "/prompts/review-diff/cursor",
      "/resources",
      "/resources/file-alerts-json",
      "/resources/file-alerts-json/cursor"
    ]

    for path <- paths do
      html = conn |> get("/servers/#{server.name}#{path}") |> html_response(200)
      refute html =~ "noindex", "#{path} should be indexable"
    end
  end

  test "the listing page links into a silo only when it has content", %{conn: conn} do
    quiet = server_fixture(%{prompts: [], resources: []})

    {:ok, _view, html} = live(conn, "/servers/#{quiet.name}")
    refute html =~ "/prompts"
    refute html =~ "/resources"
  end
end
