defmodule McpRegistryWeb.Routes do
  @moduledoc """
  Path helpers for routes whose parameter is a server name. Names contain a
  slash (`io.github.acme/weather`), which the router matches with a glob, so
  these are built as plain strings rather than through `~p`.
  """
  alias McpRegistry.Registry.Server
  alias McpRegistry.Registry.Tool

  def server_path(%Server{name: name}), do: server_path(name)
  def server_path(name) when is_binary(name), do: "/servers/" <> name

  def api_server_path(%Server{name: name}), do: api_server_path(name)
  def api_server_path(name) when is_binary(name), do: "/api/v0/servers/" <> name

  @doc "The tools index for a listing."
  def tools_path(%Server{} = server), do: server_path(server) <> "/tools"

  @doc """
  One tool's page. The name is percent-encoded: tool names are conventionally
  `snake_case` and safe, but nothing enforces that, and an unencoded space or
  slash would silently produce a different route.
  """
  def tool_path(%Server{} = server, tool) when is_binary(tool),
    do: tools_path(server) <> "/" <> Tool.slug(tool)

  @doc "One tool, as configured for one client."
  def client_path(%Server{} = server, tool, client_id) when is_binary(client_id),
    do: tool_path(server, tool) <> "/" <> client_id
end
