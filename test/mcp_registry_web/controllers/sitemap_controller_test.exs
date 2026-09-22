defmodule McpRegistryWeb.SitemapControllerTest do
  use McpRegistryWeb.ConnCase, async: true

  import McpRegistry.RegistryFixtures

  test "robots.txt allows everything and names the sitemap", %{conn: conn} do
    body = conn |> get("/robots.txt") |> text_response(200)

    assert body =~ "User-agent: *\nDisallow:\n"
    assert body =~ "Sitemap: http://localhost:4000/sitemap.xml"
  end

  test "the index lists the pages file and one file per 10,000 listings", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)

    assert response_content_type(conn, :xml) =~ "application/xml"
    assert body =~ ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert body =~ "<loc>http://localhost:4000/sitemaps/pages.xml</loc>"
    assert body =~ "<loc>http://localhost:4000/sitemaps/servers-1.xml</loc>"
    refute body =~ "servers-2.xml"
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "a servers file lists active listings with lastmod, never pending ones", %{conn: conn} do
    live = server_fixture()
    pending = server_fixture(%{status: "pending"})

    body = conn |> get("/sitemaps/servers-1.xml") |> response(200)

    assert body =~ "<loc>http://localhost:4000/servers/#{live.name}</loc><lastmod>"
    refute body =~ pending.name
  end

  test "the pages file lists the pages that are not listings", %{conn: conn} do
    body = conn |> get("/sitemaps/pages.xml") |> response(200)

    for path <- ["/", "/servers", "/submit", "/book"] do
      assert body =~ "<loc>http://localhost:4000#{path}</loc>"
    end
  end

  test "files that do not exist are 404s, not redirects", %{conn: conn} do
    for path <- [
          "/sitemaps/servers-2.xml",
          "/sitemaps/servers-0.xml",
          "/sitemaps/servers-x.xml",
          "/sitemaps/other.xml"
        ] do
      assert conn |> get(path) |> response(404) == ""
    end
  end
end
