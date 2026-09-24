defmodule McpRegistryWeb.Routes do
  @moduledoc """
  Path helpers for routes whose parameter is a server name. Names contain a
  slash (`io.github.acme/weather`), which the router matches with a glob, so
  these are built as plain strings rather than through `~p`.
  """
  alias McpRegistry.Registry.Server
  alias McpRegistry.Registry.Capability
  alias McpRegistry.Registry.Tool

  def server_path(%Server{name: name}), do: server_path(name)
  def server_path(name) when is_binary(name), do: "/servers/" <> name

  def api_server_path(%Server{name: name}), do: api_server_path(name)
  def api_server_path(name) when is_binary(name), do: "/api/v0/servers/" <> name

  @doc "The tools index for a listing."
  def tools_path(%Server{name: name}), do: tools_path(name)
  def tools_path(name) when is_binary(name), do: server_path(name) <> "/tools"

  @doc """
  One tool's page. The name is percent-encoded: tool names are conventionally
  `snake_case` and safe, but nothing enforces that, and an unencoded space or
  slash would silently produce a different route.
  """
  def tool_path(%Server{name: name}, tool) when is_binary(tool), do: tool_path(name, tool)

  def tool_path(name, tool) when is_binary(name) and is_binary(tool),
    do: tools_path(name) <> "/" <> Tool.slug(tool)

  @doc "A listing set up in one client: the server x agent page."
  def agent_path(%Server{name: name}, agent_id), do: agent_path(name, agent_id)

  def agent_path(name, agent_id) when is_binary(name) and is_binary(agent_id),
    do: server_path(name) <> "/for/" <> agent_id

  @doc "One tool, as configured for one client."
  def client_path(%Server{name: name}, tool, client_id) when is_binary(client_id),
    do: client_path(name, tool, client_id)

  def client_path(name, tool, client_id) when is_binary(name) and is_binary(client_id),
    do: tool_path(name, tool) <> "/" <> client_id

  @doc """
  The prompts or resources index for a listing.

  `kind` is `:prompts` or `:resources`, and it is also the URL segment, so the
  path and the database column cannot drift apart.
  """
  def capabilities_path(%Server{name: name}, kind), do: capabilities_path(name, kind)

  def capabilities_path(name, kind) when is_binary(name) and kind in [:prompts, :resources],
    do: server_path(name) <> "/" <> Atom.to_string(kind)

  @doc "One prompt or resource. Slugged, because a resource URI has slashes in it."
  def capability_path(%Server{name: name}, kind, item), do: capability_path(name, kind, item)

  def capability_path(name, kind, item) when is_binary(name) and is_binary(item),
    do: capabilities_path(name, kind) <> "/" <> Capability.slug(item)

  @doc "One prompt or resource, as used from one client."
  def capability_client_path(%Server{name: name}, kind, item, client_id),
    do: capability_client_path(name, kind, item, client_id)

  def capability_client_path(name, kind, item, client_id) when is_binary(client_id),
    do: capability_path(name, kind, item) <> "/" <> client_id
end
