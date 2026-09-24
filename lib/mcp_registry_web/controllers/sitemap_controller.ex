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
  alias McpRegistryWeb.Routes

  @per_file Discovery.batch_size()
  @servers_per_tool_file 1_000

  def robots(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> text("User-agent: *\nDisallow:\n\nSitemap: #{McpRegistryWeb.Endpoint.url()}/sitemap.xml\n")
  end

  def index(conn, _params) do
    base = McpRegistryWeb.Endpoint.url()

    files =
      ["pages.xml" | Enum.map(1..server_files(), &"servers-#{&1}.xml")] ++
        case tool_files() do
          0 -> []
          n -> Enum.map(1..n, &"tools-#{&1}.xml")
        end

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

  # The tool pages, chunked by listing. Client pages are deliberately absent:
  # at 188,000 tools they would be 1.1 million near-identical URLs, which is
  # the doorway pattern rather than coverage. They stay reachable and useful
  # for a reader who lands on a tool page, and carry noindex.
  #
  # Chunked by listing rather than by URL because a listing's tools travel
  # together. At #{@servers_per_tool_file} listings and about eighteen tools
  # each that is roughly 19,000 URLs a file, well inside the 50,000 limit even
  # for a listing with an unusually large tool set.
  def show(conn, %{"file" => "tools-" <> file}) do
    with {page, ".xml"} <- Integer.parse(file),
         true <- page in 1..tool_files() do
      base = McpRegistryWeb.Endpoint.url()

      page
      |> Registry.servers_with_tools(@servers_per_tool_file)
      |> Enum.flat_map(fn {name, tools, updated_at} ->
        [{base <> Routes.tools_path(name), updated_at}] ++
          Enum.map(tools, &{base <> Routes.tool_path(name, &1), updated_at})
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

  defp server_files, do: max(ceil(Registry.count_servers() / @per_file), 1)

  defp tool_files,
    do: ceil(Registry.count_servers_with_tools() / @servers_per_tool_file)

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
