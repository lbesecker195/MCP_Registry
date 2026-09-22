defmodule McpRegistryWeb.Plugs.IndexNowKeyTest do
  use McpRegistryWeb.ConnCase, async: true

  alias McpRegistry.Discovery

  test "serves the key at /<key>.txt", %{conn: conn} do
    key = Discovery.indexnow_key()

    assert key =~ ~r/^[0-9a-f]{32}$/
    assert conn |> get("/#{key}.txt") |> text_response(200) == key
  end

  test "leaves every other path to the router", %{conn: conn} do
    assert conn |> get("/llms.txt") |> text_response(200) =~ "MCP Registry"
    assert conn |> get("/0123456789abcdef.txt") |> redirected_to(301) == "/"
  end
end
