defmodule McpRegistryWeb.SitemapController do
  @moduledoc """
  Serves robots.txt and the sitemap, which is how crawlers find the
  listing pages the IndexNow and WebSub pushes in `McpRegistry.Discovery` do
  not reach.

  `/sitemap.xml` is an index of `/sitemaps/pages.xml` (the pages that are not
  listings) and `/sitemaps/servers-N.xml`, 10,000 active listings each. The
  protocol allows 50,000 per file; smaller files stay quick to build on a
  small box, and each one matches one IndexNow batch.
  """
  use McpRegistryWeb, :controller

  alias McpRegistry.Discovery
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Clients
  alias McpRegistryWeb.Routes

  @per_file Discovery.batch_size()
  # ~18 tools a listing, seven URLs each (the tool plus six clients), so 150
  # listings is roughly 19,000 URLs -- inside the 50,000 limit with room for a
  # listing carrying an unusually large tool set.
  @servers_per_tool_file 150
  # Twelve or so agent pages a listing, so 3,000 listings is about 36,000 URLs.
  @servers_per_agent_file 3_000
  # Skills run far fewer per listing than tools -- a handful rather than
  # eighteen -- so more listings fit in a file at the same URL budget.
  @servers_per_skill_file 500

  # `/live` is LiveView's transport, not content. Its long-poll fallback carries
  # a fresh CSRF token in the query string, so every fetch mints a URL that has
  # never been seen before -- an endless supply of new pages to a crawler that
  # cannot hold a websocket. Googlebot spent 39 of its requests there against 8
  # on real pages before this was disallowed.
  #
  # The JSON API is excluded too: it is for programs, it duplicates what the
  # listing pages say, and every request spent there is one not spent on a page
  # that can rank. llms.txt stays allowed -- it is written for agents to read.
  def robots(conn, _params) do
    body = """
    User-agent: *
    Disallow: /live/
    Disallow: /api/
    Allow: /

    Sitemap: #{McpRegistryWeb.Endpoint.url()}/sitemap.xml
    """

    conn
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> text(body)
  end

  def index(conn, _params) do
    base = McpRegistryWeb.Endpoint.url()

    files =
      ["pages.xml" | Enum.map(1..server_files(), &"servers-#{&1}.xml")] ++
        case tool_files() do
          0 -> []
          n -> Enum.map(1..n, &"tools-#{&1}.xml")
        end ++
        case skill_files() do
          0 -> []
          n -> Enum.map(1..n, &"skills-#{&1}.xml")
        end ++
        Enum.map(1..agent_files(), &"agents-#{&1}.xml")

    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(files, &["  <sitemap><loc>", base, "/sitemaps/", &1, "</loc></sitemap>\n"]),
      "</sitemapindex>\n"
    ]
    |> send_xml(conn)
  end

  def show(conn, %{"file" => "pages.xml"}) do
    Discovery.static_urls()
    |> Enum.map(&{&1, nil})
    |> urlset()
    |> send_xml(conn)
  end

  # Every tool page and every tool-and-client page, chunked by listing. A
  # listing's tools travel together, so the chunk boundary is the listing.
  # One page per listing per client that can actually run it. Chunked because
  # twelve clients across 34,000 listings is roughly 400,000 URLs.
  def show(conn, %{"file" => "agents-" <> file}) do
    with {page, ".xml"} <- Integer.parse(file),
         true <- page in 1..agent_files() do
      base = McpRegistryWeb.Endpoint.url()

      page
      |> Registry.agent_sitemap_entries(@servers_per_agent_file)
      |> Enum.flat_map(fn {server, updated_at} ->
        Enum.map(Clients.ids(server), fn id ->
          {base <> Routes.agent_path(server.name, id), updated_at}
        end)
      end)
      |> urlset()
      |> send_xml(conn)
    else
      _ -> not_found(conn)
    end
  end

  def show(conn, %{"file" => "tools-" <> file}) do
    with {page, ".xml"} <- Integer.parse(file),
         true <- within(page, tool_files()) do
      base = McpRegistryWeb.Endpoint.url()

      page
      |> Registry.servers_with_tools(@servers_per_tool_file)
      |> Enum.flat_map(fn {server, tools, updated_at} ->
        clients = Clients.ids(server)

        [{base <> Routes.tools_path(server.name), updated_at}] ++
          Enum.flat_map(tools, fn tool ->
            [{base <> Routes.tool_path(server.name, tool), updated_at}] ++
              Enum.map(clients, &{base <> Routes.client_path(server.name, tool, &1), updated_at})
          end)
      end)
      |> urlset()
      |> send_xml(conn)
    else
      _ -> not_found(conn)
    end
  end

  def show(conn, %{"file" => "skills-" <> file}) do
    with {page, ".xml"} <- Integer.parse(file),
         true <- within(page, skill_files()) do
      base = McpRegistryWeb.Endpoint.url()

      page
      |> Registry.servers_with_skills(@servers_per_skill_file)
      |> Enum.flat_map(fn {server, skills, updated_at} ->
        clients = Clients.ids(server)

        [{base <> Routes.skills_path(server.name), updated_at}] ++
          Enum.flat_map(skills, fn skill ->
            [{base <> Routes.skill_path(server.name, skill), updated_at}] ++
              Enum.map(
                clients,
                &{base <> Routes.skill_client_path(server.name, skill, &1), updated_at}
              )
          end)
      end)
      |> urlset()
      |> send_xml(conn)
    else
      _ -> not_found(conn)
    end
  end

  def show(conn, %{"file" => "servers-" <> file}) do
    with {page, ".xml"} <- Integer.parse(file),
         true <- page in 1..server_files() do
      base = McpRegistryWeb.Endpoint.url()

      page
      |> Registry.sitemap_entries(@per_file)
      |> Enum.map(fn {name, updated_at} -> {base <> Routes.server_path(name), updated_at} end)
      |> urlset()
      |> send_xml(conn)
    else
      _ -> not_found(conn)
    end
  end

  def show(conn, _params), do: not_found(conn)

  # Not `page in 1..count`: when count is 0 that range descends (Elixir gives
  # `1..0` a step of -1), so `1 in 1..0` is true and the file is served as an
  # empty 200 rather than a 404.
  defp within(page, count), do: page >= 1 and page <= count

  defp server_files, do: max(ceil(Registry.count_servers() / @per_file), 1)

  defp agent_files,
    do: max(ceil(Registry.count_servers() / @servers_per_agent_file), 1)

  defp tool_files,
    do: ceil(Registry.count_servers_with_tools() / @servers_per_tool_file)

  defp skill_files,
    do: ceil(Registry.count_servers_with_skills() / @servers_per_skill_file)

  defp urlset(entries) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(entries, fn {loc, lastmod} ->
        [
          "  <url><loc>",
          Plug.HTML.html_escape_to_iodata(loc),
          "</loc>",
          if(lastmod, do: ["<lastmod>", DateTime.to_iso8601(lastmod), "</lastmod>"], else: []),
          "</url>\n"
        ]
      end),
      "</urlset>\n"
    ]
  end

  defp send_xml(body, conn) do
    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end

  # A crawler asking for a file that is gone (the catalogue shrank) should drop
  # it, not follow the site-wide 301 home.
  defp not_found(conn), do: conn |> put_resp_content_type("text/plain") |> send_resp(404, "")
end
