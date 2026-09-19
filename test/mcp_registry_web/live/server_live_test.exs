defmodule McpRegistryWeb.ServerLiveTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  test "index lists and searches servers", %{conn: conn} do
    weather = server_fixture(%{title: "Acme Weather"})

    notes =
      server_fixture(%{
        name: "io.github.acme/notes",
        title: "Acme Notes",
        description: "Keeps notes.",
        tags: ["notes"],
        tools: ["add_note"]
      })

    {:ok, view, html} = live(conn, ~p"/servers")
    assert html =~ weather.title
    assert html =~ notes.title
    assert html =~ "Seriously Simple Analytics"

    assert html =~
             "claude mcp add --transport http mcp-registry-search #{McpRegistryWeb.Endpoint.url()}/mcp"

    html = view |> element("form") |> render_change(%{q: "notes", transport: ""})
    assert html =~ notes.title
    refute html =~ weather.title
    assert_patch(view, ~p"/servers?q=notes")
  end

  test "show renders install snippets and the manifest", %{conn: conn} do
    server = server_fixture()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    assert html =~ "claude mcp add"
    assert html =~ "@acme/weather-mcp"
    assert html =~ "server.json"
    assert html =~ "get_forecast"
  end

  test "show sets a fixed <h1> and an Integration tab strip for packaged servers", %{
    conn: conn
  } do
    server = server_fixture(%{title: "Weather"})
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    assert html =~ ~r{<h1[^>]*>\s*Weather MCP\s*</h1>}
    assert html =~ "Package managers"
    assert html =~ "npx -y @acme/weather-mcp"
    assert html =~ "pnpm dlx @acme/weather-mcp"
    assert html =~ "Homebrew"
    assert html =~ "Not available via Homebrew. Try one of the other package managers above."
    refute html =~ "Opening of the GitHub README"
    refute html =~ "View repository"

    remote =
      server_fixture(%{
        transport: "sse",
        remote_url: "https://mcp.acme.dev/sse",
        package_registry: nil,
        package_identifier: nil
      })

    {:ok, _view, remote_html} = live(conn, "/servers/#{remote.name}")
    refute remote_html =~ "Package managers"
  end

  test "show sets a fixed SEO title and meta description", %{conn: conn} do
    server = server_fixture(%{name: "io.github.upstash/context7-seo", title: "Context7"})
    html = conn |> get("/servers/#{server.name}") |> html_response(200)

    assert html =~ "Context7 MCP</title>"
    refute html =~ "Context7 MCP · MCP Registry"

    assert html =~
             ~s(<meta name="description" content="Context7 MCP server integration.  ) <>
               ~s(Upstash Context7 MCP server.  How to integrate with Claude Context7 using MCP ) <>
               ~s(and Cursor Context7 using MCP so I can use them in Claude Code and Grok Bot.")
  end

  test "pending listings are kept out of search engines", %{conn: conn} do
    active = server_fixture()
    pending = server_fixture(%{status: "pending"})

    refute conn |> get("/servers/#{active.name}") |> html_response(200) =~ ~s(content="noindex")
    html = conn |> get("/servers/#{pending.name}") |> html_response(200)
    assert html =~ ~s(<meta name="robots" content="noindex">)
    assert html =~ ~s(rel="nofollow ugc noopener")
  end

  test "index paginates large catalogues", %{conn: conn} do
    for i <- 1..50 do
      server_fixture(%{
        name: "com.example/bulk-#{String.pad_leading("#{i}", 2, "0")}",
        title: "Bulk #{String.pad_leading("#{i}", 2, "0")}"
      })
    end

    {:ok, view, html} = live(conn, ~p"/servers")
    assert html =~ "Showing 1–48 of 50 servers"
    assert html =~ "Bulk 48"
    refute html =~ "Bulk 49"

    html = view |> element("#pagination a[rel=next]") |> render_click()
    assert_patch(view, ~p"/servers?page=2")
    assert html =~ "Showing 49–50 of 50 servers"
    assert html =~ "Bulk 50"

    {:ok, _view, html} = live(conn, ~p"/servers?page=999")
    assert html =~ "Showing 49–50 of 50 servers"
  end

  test "imported listings credit the official registry", %{conn: conn} do
    server =
      server_fixture()
      |> Ecto.Changeset.change(origin: "official", synced_at: DateTime.utc_now())
      |> McpRegistry.Repo.update!()

    {:ok, _view, html} = live(conn, "/servers/#{server.name}")
    assert html =~ "Verified official"
    assert html =~ "just now"
    assert html =~ McpRegistry.OfficialRegistry.server_url(server.name)
  end

  test "the install hub switches client and fills placeholders as you type", %{conn: conn} do
    server = server_fixture()
    {:ok, view, html} = live(conn, "/servers/#{server.name}")

    # Claude Code is offered first, and the secret starts as a placeholder.
    assert html =~ "claude mcp add"
    assert html =~ "&lt;WEATHER_API_KEY&gt;"

    # Each client's own shape -- these keys are not interchangeable, and a
    # wrong one fails silently in the client, so pin them.
    html = view |> element("button[phx-value-client=claude-desktop]") |> render_click()
    assert html =~ "mcpServers"

    html = view |> element("button[phx-value-client=vscode]") |> render_click()
    assert html =~ "&quot;servers&quot;"
    refute html =~ "mcpServers"

    html = view |> element("button[phx-value-client=zed]") |> render_click()
    assert html =~ "context_servers"

    # Typing a token rewrites the rendered snippet in place.
    html =
      view
      |> element("button[phx-value-client=cursor]")
      |> render_click()

    assert html =~ "&lt;WEATHER_API_KEY&gt;"

    html =
      view
      |> form("form[phx-change=update_secrets]", secrets: %{"WEATHER_API_KEY" => "sk-live-42"})
      |> render_change()

    assert html =~ "sk-live-42"
    refute html =~ "&lt;WEATHER_API_KEY&gt;"
  end

  test "remote listings get a remote-shaped config per client", %{conn: conn} do
    server =
      server_fixture(%{
        transport: "streamable-http",
        remote_url: "https://mcp.acme.dev/mcp",
        package_registry: nil,
        package_identifier: nil,
        env_vars: []
      })

    {:ok, view, html} = live(conn, "/servers/#{server.name}")
    assert html =~ "claude mcp add --transport http"

    # Windsurf spells the remote endpoint serverUrl, not url.
    html = view |> element("button[phx-value-client=windsurf]") |> render_click()
    assert html =~ "serverUrl"

    # Claude Desktop has no remote form at all, so it bridges via mcp-remote.
    html = view |> element("button[phx-value-client=claude-desktop]") |> render_click()
    assert html =~ "mcp-remote"
  end

  test "the capability explorer filters tools and flags mutating ones", %{conn: conn} do
    server = server_fixture(%{tools: ["get_forecast", "delete_alert"]})
    {:ok, view, html} = live(conn, "/servers/#{server.name}")

    assert html =~ "get_forecast"
    assert html =~ "delete_alert"
    assert html =~ "Read-only"
    assert html =~ "Mutating"

    html = view |> form("form[phx-change=filter_tools]", query: "delete") |> render_change()
    assert html =~ "delete_alert"
    refute html =~ "get_forecast"
  end

  test "show 404s for unknown servers", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn -> live(conn, "/servers/io.github.nobody/nothing") end
  end

  test "submit form validates and creates a pending listing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/submit")

    html = view |> form("#server-form", server: %{name: "bad name"}) |> render_change()
    assert html =~ "must look like namespace/server-name"

    attrs = %{
      name: "io.github.acme/submitted",
      title: "Submitted",
      description: "Came in through the web form.",
      version: "0.1.0",
      transport: "stdio",
      package_registry: "npm",
      package_identifier: "@acme/submitted",
      tags: "forms, web",
      tools: "submit_thing"
    }

    {:ok, _show, html} =
      view
      |> form("#server-form", server: attrs)
      |> render_submit()
      |> follow_redirect(conn, "/servers/io.github.acme/submitted")

    assert html =~ "pending review"
    assert html =~ "submit_thing"

    assert {:ok, %{status: "pending", tags: ["forms", "web"]}} =
             McpRegistry.Registry.fetch_server("io.github.acme/submitted")
  end
end
