defmodule McpRegistry.DocumentsTest do
  use McpRegistry.DataCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Changes.Change
  alias McpRegistry.Documents
  alias McpRegistry.Documents.Document
  alias McpRegistry.Repo

  @public {93, 184, 216, 34}

  setup do
    Application.put_env(:mcp_registry, :documents,
      req_options: [plug: {Req.Test, McpRegistry.Documents}],
      resolver: fn _host -> {:ok, [@public]} end
    )

    on_exit(fn -> Application.delete_env(:mcp_registry, :documents) end)
  end

  defp serve(fun), do: Req.Test.stub(McpRegistry.Documents, fun)

  defp text(conn, status, body, headers \\ []) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> then(&Enum.reduce(headers, &1, fn {k, v}, c -> Plug.Conn.put_resp_header(c, k, v) end))
    |> Plug.Conn.send_resp(status, body)
  end

  defp doc(attrs \\ %{}) do
    Repo.insert!(
      struct(Document, Map.merge(%{url: "https://acme.test/llms.txt", kind: "llms_txt"}, attrs))
    )
  end

  defp changes, do: Repo.all(from c in Change, order_by: c.id)

  describe "which documents a listing points at" do
    test "llms.txt at the website, else the verified namespace domain" do
      assert {"llms_txt", "https://docs.acme.com/llms.txt"} in Documents.urls_for(%{
               name: "com.acme/x",
               website_url: "https://docs.acme.com/getting-started",
               repository_url: nil
             })

      assert Documents.urls_for(%{
               name: "com.cloudflare/docs",
               website_url: nil,
               repository_url: nil
             }) ==
               [{"llms_txt", "https://cloudflare.com/llms.txt"}]
    end

    test "an io.github namespace names an account, not a site" do
      assert Documents.urls_for(%{
               name: "io.github.acme/x",
               website_url: nil,
               repository_url: nil
             }) ==
               []
    end

    test "AGENTS.md from a GitHub repository, .git and all" do
      assert {"agents_md", "https://raw.githubusercontent.com/acme/weather/HEAD/AGENTS.md"} in Documents.urls_for(
               %{
                 name: "io.github.acme/x",
                 website_url: nil,
                 repository_url: "https://github.com/Acme/weather.git"
               }
             )
    end

    test "nothing is guessed for hosts that are not GitHub or are not domains" do
      assert Documents.urls_for(%{
               name: "io.github.acme/x",
               website_url: "https://localhost:8080/",
               repository_url: "https://gitlab.com/acme/x"
             }) == []
    end
  end

  describe "what counts as a change" do
    test "the first fetch is a baseline, not an event" do
      serve(&text(&1, 200, "# Acme\n\n- one\n"))
      d = doc()

      assert Documents.check(d) == :baseline
      assert changes() == []
      assert Repo.reload(d).status == "ok"
    end

    test "a changed file records the lines added and removed" do
      d = doc()
      serve(&text(&1, 200, "# Acme\n- one\n- two\n"))
      Documents.check(d)

      serve(&text(&1, 200, "# Acme\n- two\n- three\n"))
      assert Documents.check(Repo.reload(d)) == :changed

      assert [change] = changes()
      assert change.document_url == "https://acme.test/llms.txt"
      assert change.kind == "llms_txt"
      assert change.added == ["- three"]
      assert change.removed == ["- one"]
      assert change.server_id == nil
    end

    test "an unchanged file is asked for conditionally and costs a 304" do
      d = doc()
      serve(&text(&1, 200, "# Acme\n", [{"etag", ~s("v1")}]))
      Documents.check(d)

      serve(fn conn ->
        assert Plug.Conn.get_req_header(conn, "if-none-match") == [~s("v1")]
        Plug.Conn.send_resp(conn, 304, "")
      end)

      assert Documents.check(Repo.reload(d)) == :not_modified
      assert changes() == []
    end

    test "a file that disappears is recorded as removed" do
      d = doc()
      serve(&text(&1, 200, "# Acme\n- one\n"))
      Documents.check(d)

      serve(&text(&1, 404, "not here"))
      assert Documents.check(Repo.reload(d)) == :changed

      assert [change] = changes()
      assert change.fields == %{"file" => ["published", "removed"]}
      assert change.removed == ["# Acme", "- one"]
      assert Repo.reload(d).status == "missing"
    end

    test "a file that appears where one was confirmed absent is recorded" do
      d = doc(%{status: "missing"})
      serve(&text(&1, 200, "# Acme\n"))

      assert Documents.check(d) == :changed
      assert [%{fields: %{"file" => ["absent", "published"]}}] = changes()
    end

    test "an outage is not a removal" do
      d = doc()
      serve(&text(&1, 200, "# Acme\n"))
      Documents.check(d)

      serve(&text(&1, 503, "down"))
      assert Documents.check(Repo.reload(d)) == :error

      assert changes() == []
      reloaded = Repo.reload(d)
      assert reloaded.status == "ok"
      assert reloaded.content == "# Acme\n"
      assert reloaded.last_error == "HTTP 503"
    end

    test "an HTML page served at /llms.txt is not an llms.txt" do
      # The single-page-app fallback: every path answers 200 with the shell.
      serve(fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(200, "<!doctype html><html><body>app</body></html>")
      end)

      assert Documents.check(doc()) == :missing
    end
  end

  describe "fetching URLs that publishers choose" do
    test "a host resolving to a private address is never requested" do
      Application.put_env(:mcp_registry, :documents,
        req_options: [plug: {Req.Test, McpRegistry.Documents}],
        resolver: fn _ -> {:ok, [{169, 254, 169, 254}]} end
      )

      serve(fn _conn -> flunk("a private address was requested") end)

      assert Documents.check(doc()) == :error
    end

    test "a redirect to a private address is refused at that hop" do
      Application.put_env(:mcp_registry, :documents,
        req_options: [plug: {Req.Test, McpRegistry.Documents}],
        resolver: fn
          "acme.test" -> {:ok, [@public]}
          _ -> {:ok, [{10, 0, 0, 5}]}
        end
      )

      serve(fn conn ->
        assert conn.host == "acme.test"

        conn
        |> Plug.Conn.put_resp_header("location", "https://internal.acme.test/llms.txt")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert Documents.check(doc()) == :error
      assert Repo.one(Document).last_error =~ "private address"
    end

    test "plain http is refused before anything is sent" do
      serve(fn _conn -> flunk("an http URL was requested") end)
      assert Documents.check(doc(%{url: "http://acme.test/llms.txt"})) == :error
    end

    test "a body past the cap is cut, not downloaded whole" do
      serve(&text(&1, 200, String.duplicate("a", 300_000)))
      d = doc()

      Documents.check(d)
      assert byte_size(Repo.reload(d).content) == 262_144
    end

    test "private and special addresses are recognised" do
      for ip <- [
            {127, 0, 0, 1},
            {10, 1, 2, 3},
            {172, 16, 0, 1},
            {192, 168, 1, 1},
            {169, 254, 169, 254},
            {100, 64, 0, 1},
            {0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 1},
            {0xFE80, 0, 0, 0, 0, 0, 0, 1},
            {0xFD00, 0, 0, 0, 0, 0, 0, 1},
            {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001}
          ] do
        refute Documents.public_address?(ip), "#{inspect(ip)} should be private"
      end

      assert Documents.public_address?(@public)
      assert Documents.public_address?({0x2606, 0x4700, 0, 0, 0, 0, 0, 1})
    end
  end

  describe "discovery and the listing's changelog" do
    test "links listings to shared documents once, and drops ones no longer linked" do
      a = server_fixture(%{name: "com.acme/one", repository_url: "https://github.com/acme/one"})
      _b = server_fixture(%{name: "com.acme/two", repository_url: nil})
      Repo.insert!(%Document{url: "https://gone.test/llms.txt", kind: "llms_txt"})

      Documents.discover()

      urls = Repo.all(from d in Document, select: d.url) |> Enum.sort()

      # Both listings share acme.com's llms.txt: one document, not two.
      assert urls == [
               "https://acme.com/llms.txt",
               "https://raw.githubusercontent.com/acme/one/HEAD/AGENTS.md"
             ]

      assert Documents.linked_urls(a) |> Enum.sort() == urls
    end

    test "a document's change shows on every listing that points at it" do
      a = server_fixture(%{name: "com.acme/one"})
      b = server_fixture(%{name: "com.acme/two"})
      Documents.discover()

      McpRegistry.Changes.record_document("https://acme.com/llms.txt", "llms_txt", %{
        added: ["- new"]
      })

      for server <- [a, b] do
        assert [%{kind: "llms_txt", added: ["- new"]}] = McpRegistry.Changes.for_server(server)
        assert McpRegistry.Changes.kinds_for_server(server) == %{"llms_txt" => 1}
      end

      # Recorded once, attributed to both.
      assert Repo.aggregate(Change, :count) == 1
      assert McpRegistry.Changes.count_servers_with_changes() == 2
    end
  end
end
