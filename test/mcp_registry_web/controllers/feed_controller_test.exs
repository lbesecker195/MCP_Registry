defmodule McpRegistryWeb.FeedControllerTest do
  use McpRegistryWeb.ConnCase, async: true

  import McpRegistry.RegistryFixtures

  test "the Atom feed declares its hub and self, and lists the newest listings", %{conn: conn} do
    live = server_fixture(%{title: "Tides & Weather", description: "Tide <tables> by port."})
    pending = server_fixture(%{status: "pending"})

    conn = get(conn, "/feed.xml")
    body = response(conn, 200)

    assert response_content_type(conn, :xml) =~ "application/atom+xml"
    assert body =~ ~s(<feed xmlns="http://www.w3.org/2005/Atom">)
    assert body =~ ~s(<link rel="hub" href="https://pubsubhubbub.appspot.com/"/>)

    assert body =~
             ~s(<link rel="self" type="application/atom+xml" href="http://localhost:4000/feed.xml"/>)

    assert body =~ "<id>http://localhost:4000/servers/#{live.name}</id>"
    assert body =~ "<title>Tides &amp; Weather</title>"
    assert body =~ "<summary>Tide &lt;tables&gt; by port.</summary>"
    refute body =~ pending.name
  end

  test "every page advertises the feed", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)
    assert html =~ ~s(type="application/atom+xml" href="/feed.xml")
  end
end
