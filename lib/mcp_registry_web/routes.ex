defmodule McpRegistryWeb.Routes do
  @moduledoc """
  Path helpers for routes whose parameter is a server name. Names contain a
  slash (`io.github.acme/weather`), which the router matches with a glob, so
  these are built as plain strings rather than through `~p`.
  """
  alias McpRegistry.Registry.Server
  alias McpRegistry.Registry.Skill
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

  @doc "The skills index for a listing, where a listing has any."
  def skills_path(%Server{name: name}), do: skills_path(name)
  def skills_path(name) when is_binary(name), do: server_path(name) <> "/skills"

  @doc "One skill's page. Percent-encoded for the same reason `tool_path/2` is."
  def skill_path(%Server{name: name}, skill) when is_binary(skill), do: skill_path(name, skill)

  def skill_path(name, skill) when is_binary(name) and is_binary(skill),
    do: skills_path(name) <> "/" <> Skill.slug(skill)

  @doc "One skill, as used from one client."
  def skill_client_path(%Server{name: name}, skill, client_id) when is_binary(client_id),
    do: skill_client_path(name, skill, client_id)

  def skill_client_path(name, skill, client_id) when is_binary(name) and is_binary(client_id),
    do: skill_path(name, skill) <> "/" <> client_id
end
