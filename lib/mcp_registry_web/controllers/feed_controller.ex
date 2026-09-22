defmodule McpRegistryWeb.FeedController do
  @moduledoc """
  Serves /feed.xml, an Atom feed of the newest listings.

  The feed names the WebSub hubs that `McpRegistry.Discovery` pings after a
  sync or an approval. A hub then fetches the feed again and pushes it to its
  subscribers, and Google's Feedfetcher is one of them. That is how a new
  listing reaches Google within minutes instead of waiting for a crawl.
  """
  use McpRegistryWeb, :controller

  alias McpRegistry.Discovery
  alias McpRegistry.Registry
  alias McpRegistryWeb.Routes

  @entries 50

  def show(conn, _params) do
    base = McpRegistryWeb.Endpoint.url()
    servers = Registry.newest_servers(@entries)

    updated =
      servers
      |> Enum.map(& &1.updated_at)
      |> Enum.max(DateTime, fn -> DateTime.utc_now(:second) end)

    body = [
      ~s(<?xml version="1.0" encoding="utf-8"?>\n),
      ~s(<feed xmlns="http://www.w3.org/2005/Atom">\n),
      "  <id>",
      Discovery.feed_url(),
      "</id>\n",
      "  <title>New MCP servers · MCP Registry</title>\n",
      "  <subtitle>The newest Model Context Protocol servers listed in the MCP Registry.</subtitle>\n",
      ~s(  <link rel="self" type="application/atom+xml" href="),
      Discovery.feed_url(),
      ~s("/>\n),
      Enum.map(Discovery.hubs(), &[~s(  <link rel="hub" href="), escape(&1), ~s("/>\n)]),
      ~s(  <link rel="alternate" type="text/html" href="),
      base,
      ~s(/servers"/>\n),
      "  <updated>",
      DateTime.to_iso8601(updated),
      "</updated>\n",
      "  <author><name>MCP Registry</name><uri>",
      base,
      "/</uri></author>\n",
      Enum.map(servers, &entry(&1, base)),
      "</feed>\n"
    ]

    conn
    |> put_resp_content_type("application/atom+xml")
    |> put_resp_header("cache-control", "public, max-age=600")
    |> send_resp(200, body)
  end

  defp entry(server, base) do
    url = base <> Routes.server_path(server.name)

    [
      "  <entry>\n",
      "    <id>",
      escape(url),
      "</id>\n",
      "    <title>",
      escape(server.title || server.name),
      "</title>\n",
      ~s(    <link rel="alternate" type="text/html" href="),
      escape(url),
      ~s("/>\n),
      "    <published>",
      DateTime.to_iso8601(server.inserted_at),
      "</published>\n",
      "    <updated>",
      DateTime.to_iso8601(server.updated_at),
      "</updated>\n",
      "    <summary>",
      escape(server.description || ""),
      "</summary>\n",
      "  </entry>\n"
    ]
  end

  defp escape(text), do: Plug.HTML.html_escape_to_iodata(text)
end
