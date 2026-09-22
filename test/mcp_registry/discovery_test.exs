defmodule McpRegistry.DiscoveryTest do
  # Not async: these tests switch pushing on in the application environment.
  use McpRegistry.DataCase, async: false

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Discovery
  alias McpRegistry.Discovery.Batcher
  alias McpRegistry.OfficialRegistry
  alias McpRegistry.Registry

  @key "0123456789abcdef0123456789abcdef"

  setup do
    # Flushing while pushing is off drops whatever an earlier test queued.
    :ok = Batcher.flush()
    original = Application.get_env(:mcp_registry, :discovery)

    on_exit(fn ->
      Application.put_env(:mcp_registry, :discovery, original)
      :ok = Batcher.flush()
    end)

    Application.put_env(
      :mcp_registry,
      :discovery,
      Keyword.merge(original, enabled: true, indexnow_key: @key, batch_window_ms: 60_000)
    )

    :ok
  end

  # Answers IndexNow with `indexnow_status` and every hub with 204, and sends
  # each request to the test process.
  defp stub_engines(indexnow_status \\ 200) do
    test_pid = self()

    Req.Test.stub(Discovery, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case conn.host do
        "api.indexnow.org" ->
          send(test_pid, {:indexnow, conn.request_path, Jason.decode!(body)})
          Plug.Conn.send_resp(conn, indexnow_status, "")

        hub ->
          send(test_pid, {:websub, hub, URI.decode_query(body)})
          Plug.Conn.send_resp(conn, 204, "")
      end
    end)
  end

  test "announce submits the URLs to IndexNow and pings the hub when the feed changed" do
    stub_engines()

    assert %{indexnow: [{:ok, 200}], websub: [{:ok, 204}], urls: 2} =
             Discovery.announce(["io.github.acme/a", "io.github.acme/b", "io.github.acme/a"],
               feed: true
             )

    assert_received {:indexnow, "/indexnow",
                     %{
                       "host" => "localhost",
                       "key" => @key,
                       "keyLocation" => "http://localhost:4000/" <> @key <> ".txt",
                       "urlList" => [
                         "http://localhost:4000/servers/io.github.acme/a",
                         "http://localhost:4000/servers/io.github.acme/b"
                       ]
                     }}

    assert_received {:websub, "pubsubhubbub.appspot.com",
                     %{"hub.mode" => "publish", "hub.url" => "http://localhost:4000/feed.xml"}}
  end

  test "announce leaves the hub alone unless the feed changed, and skips empty runs" do
    stub_engines()

    assert %{websub: []} = Discovery.announce(["io.github.acme/a"])
    assert_received {:indexnow, _, _}
    refute_received {:websub, _, _}

    assert Discovery.announce([]) == :nothing_to_announce
    refute_received {:indexnow, _, _}
  end

  test "a refusal is reported, not raised, and is not retried" do
    stub_engines(429)

    assert %{indexnow: [{:error, "IndexNow: HTTP 429"}]} =
             Discovery.announce(["io.github.acme/a"])

    assert_received {:indexnow, _, _}
    refute_received {:indexnow, _, _}
  end

  test "caps one run at max_urls_per_run, keeping the earliest names" do
    stub_engines()
    config = Application.get_env(:mcp_registry, :discovery)
    Application.put_env(:mcp_registry, :discovery, Keyword.put(config, :max_urls_per_run, 2))

    Discovery.announce(["n.e/new", "r.e/removed", "u.e/updated"])

    assert_received {:indexnow, _, %{"urlList" => urls}}

    assert urls == [
             "http://localhost:4000/servers/n.e/new",
             "http://localhost:4000/servers/r.e/removed"
           ]
  end

  test "does nothing when disabled" do
    Application.put_env(:mcp_registry, :discovery, enabled: false)

    assert Discovery.announce(["io.github.acme/a"], feed: true) == :disabled
    assert Discovery.announce_all() == :disabled
    refute_received {:indexnow, _, _}
  end

  test "a sync announces the listings it added, and pings the hub" do
    stub_engines()

    Req.Test.stub(OfficialRegistry, fn conn ->
      Req.Test.json(conn, %{
        "servers" => [
          %{
            "server" => %{
              "name" => "com.example/tides",
              "description" => "Tide tables by port.",
              "version" => "1.0.0",
              "packages" => [
                %{
                  "registryType" => "npm",
                  "identifier" => "@example/tides",
                  "transport" => %{"type" => "stdio"}
                }
              ]
            },
            "_meta" => %{
              "io.modelcontextprotocol.registry/official" => %{
                "status" => "active",
                "updatedAt" => "2026-09-01T00:00:00Z"
              }
            }
          }
        ],
        "metadata" => %{"nextCursor" => nil}
      })
    end)

    assert {:ok, %{inserted: 1}} = OfficialRegistry.sync(mode: :incremental)

    assert_received {:indexnow, _,
                     %{"urlList" => ["http://localhost:4000/servers/com.example/tides"]}}

    assert_received {:websub, _, %{"hub.mode" => "publish"}}
  end

  test "approving a listing announces it in the next batch" do
    stub_engines()
    Req.Test.allow(Discovery, self(), Process.whereis(Batcher))

    pending = server_fixture(%{status: "pending"})
    refute_received {:indexnow, _, _}

    assert {:ok, _} = Registry.approve_server(pending.name)
    :ok = Batcher.flush()

    assert_received {:indexnow, _, %{"urlList" => [url]}}
    assert url == "http://localhost:4000/servers/" <> pending.name
    assert_received {:websub, _, _}
  end

  test "announce_all submits the pages and every active listing" do
    stub_engines()
    live = server_fixture()

    assert %{indexnow: [{:ok, 200} | _]} = Discovery.announce_all()

    assert_received {:indexnow, _, %{"urlList" => ["http://localhost:4000/" | _]}}
    assert_received {:indexnow, _, %{"urlList" => listings}}
    assert ("http://localhost:4000/servers/" <> live.name) in listings
  end
end
