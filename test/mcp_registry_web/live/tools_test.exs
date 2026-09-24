defmodule McpRegistryWeb.ServerLive.ToolsTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  defp with_tools(tools \\ ~w(get_forecast delete_alert)) do
    server_fixture(%{title: "Weather", tools: tools})
  end

  describe "the tools index" do
    test "lists every tool and links each one", %{conn: conn} do
      server = with_tools()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/tools")

      assert html =~ "Weather MCP Tools"
      assert html =~ "get_forecast"
      assert html =~ "delete_alert"
      assert html =~ "/tools/get_forecast"
    end

    test "a listing with no tools redirects to the listing itself", %{conn: conn} do
      server = server_fixture(%{tools: []})

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/tools")

      assert to == "/servers/#{server.name}"
    end
  end

  describe "a tool page" do
    test "names the tool and offers every client that can run the server", %{conn: conn} do
      server = with_tools()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/tools/get_forecast")

      assert html =~ "get_forecast"
      # One link per client, titled the way the question gets typed.
      for label <- ["Claude Code", "Cursor", "VS Code", "Zed", "Windsurf"] do
        assert html =~ "#{label} Weather get_forecast"
      end

      assert html =~ "/tools/get_forecast/cursor"
    end

    test "classification is shown as derived, never as fact", %{conn: conn} do
      server = with_tools()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/tools/get_forecast")

      assert html =~ "Read-only"
      assert html =~ "read off each tool&#39;s name"
    end

    test "a tool that is not on this server redirects to the listing", %{conn: conn} do
      server = with_tools()

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/tools/not_a_tool")

      assert to == "/servers/#{server.name}"
    end
  end

  describe "a tool-and-client page" do
    test "H1 and H2 follow the AGENT SERVER TOOL shape", %{conn: conn} do
      server = with_tools()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/tools/get_forecast/cursor")

      assert html =~ ~r{<h1[^>]*>\s*Cursor Weather get_forecast\s*</h1>}
      assert html =~ "How to: Cursor Weather get_forecast"
    end

    test "carries that client's real configuration, not a generic one", %{conn: conn} do
      server = with_tools()

      {:ok, _view, vscode} = live(conn, "/servers/#{server.name}/tools/get_forecast/vscode")
      # VS Code reads `servers`, not `mcpServers` -- the shape must be its own.
      assert vscode =~ "&quot;servers&quot;"
      refute vscode =~ "mcpServers"

      {:ok, _view, zed} = live(conn, "/servers/#{server.name}/tools/get_forecast/zed")
      assert zed =~ "context_servers"
    end

    test "an unknown client falls back to the tool page", %{conn: conn} do
      server = with_tools()

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/tools/get_forecast/gptbot")

      assert to == "/servers/#{server.name}/tools/get_forecast"
    end
  end

  test "an unknown listing still redirects home with a 301", %{conn: conn} do
    # The sub-path must not defeat KnownServer: the plug reads the first two
    # segments as the name, so /tools under a missing listing is still a 301.
    conn = get(conn, "/servers/io.github.nobody/nothing/tools")

    assert redirected_to(conn, 301) == "/"
  end

  test "the tools sitemap carries the index, tool and client URLs", %{conn: conn} do
    server = with_tools(~w(get_forecast))

    xml = conn |> get("/sitemaps/tools.xml") |> response(200)

    assert xml =~ "/servers/#{server.name}/tools</loc>"
    assert xml =~ "/servers/#{server.name}/tools/get_forecast</loc>"
    assert xml =~ "/servers/#{server.name}/tools/get_forecast/cursor</loc>"

    # And the index advertises the file.
    assert conn |> get("/sitemap.xml") |> response(200) =~ "/sitemaps/tools.xml"
  end
end
