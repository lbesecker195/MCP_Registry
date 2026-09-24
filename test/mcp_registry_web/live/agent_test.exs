defmodule McpRegistryWeb.ServerLive.AgentTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  defp remote_fixture do
    server_fixture(%{
      title: "Weather",
      transport: "streamable-http",
      remote_url: "https://mcp.acme.dev/mcp",
      package_registry: nil,
      package_identifier: nil,
      env_vars: []
    })
  end

  test "H1 and title follow the requested shape", %{conn: conn} do
    server = server_fixture(%{title: "Weather"})
    {:ok, _view, html} = live(conn, "/servers/#{server.name}/for/cursor")

    assert html =~ ~r{<h1[^>]*>\s*Weather for Cursor\s*</h1>}
    assert html =~ "How to install Weather MCP Server in Cursor — setup guide and tutorial"
  end

  test "each client's page carries that client's own real instruction", %{conn: conn} do
    server = server_fixture(%{title: "Weather"})

    {:ok, _v, cline} = live(conn, "/servers/#{server.name}/for/cline")
    assert cline =~ "cline_mcp_settings.json"
    assert cline =~ "mcpServers"

    {:ok, _v, gemini} = live(conn, "/servers/#{server.name}/for/gemini")
    assert gemini =~ ".gemini/settings.json"

    {:ok, _v, grok} = live(conn, "/servers/#{server.name}/for/grok")
    assert grok =~ ".mcp.json"

    {:ok, _v, lc} = live(conn, "/servers/#{server.name}/for/langchain")
    assert lc =~ "langchain_mcp_adapters"
    assert lc =~ "MultiServerMCPClient"
  end

  test "ChatGPT and Claude.ai appear only for remote listings", %{conn: conn} do
    packaged = server_fixture()
    remote = remote_fixture()

    # Neither will run a packaged server, so there is nothing honest to show.
    assert {:error, {:live_redirect, %{to: to}}} =
             live(conn, "/servers/#{packaged.name}/for/chatgpt")

    assert to == "/servers/#{packaged.name}"

    {:ok, _view, html} = live(conn, "/servers/#{remote.name}/for/chatgpt")
    assert html =~ "Developer mode"
    assert html =~ "https://mcp.acme.dev/mcp"
  end

  test "crawlers and non-clients get no page at all", %{conn: conn} do
    server = server_fixture()

    # GPTBot and BingBot crawl, Lighthouse audits, Perplexity publishes its own
    # server, Aider has no native MCP support. A setup guide would be fiction.
    for agent <- ~w(gptbot bingbot lighthouse perplexity aider) do
      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/for/#{agent}")

      assert to == "/servers/#{server.name}"
    end
  end

  test "the agent pages are in the sitemap", %{conn: conn} do
    server = server_fixture()
    xml = conn |> get("/sitemaps/agents-1.xml") |> response(200)

    assert xml =~ "/servers/#{server.name}/for/cursor</loc>"
    assert xml =~ "/servers/#{server.name}/for/cline</loc>"
    assert conn |> get("/sitemap.xml") |> response(200) =~ "/sitemaps/agents-1.xml"
  end
end
