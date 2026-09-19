defmodule McpRegistryWeb.ErrorHTMLTest do
  use McpRegistryWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(McpRegistryWeb.ErrorHTML, "404", "html", [])

    assert html =~ "No page at this address"
    assert html =~ "Not Found"
    # 404 takes stale deep links to renamed servers; the catalogue is the exit.
    assert html =~ ~s(href="/servers")
    assert html =~ "Search the catalogue"
    assert html =~ ~s(name="robots" content="noindex")
  end

  test "renders 500.html" do
    html = render_to_string(McpRegistryWeb.ErrorHTML, "500", "html", [])

    assert html =~ "Something broke on our end"
    assert html =~ "Internal Server Error"
    assert html =~ ~s(href="/")
  end

  test "renders any other status with its message" do
    html = render_to_string(McpRegistryWeb.ErrorHTML, "503", "html", [])

    assert html =~ "503"
    assert html =~ "Service Unavailable"
  end
end
