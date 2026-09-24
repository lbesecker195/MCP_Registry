defmodule McpRegistry.ProbeTest do
  @moduledoc """
  The destructive failure mode here is writing an empty tool list over a
  publisher's declared one because an endpoint happened to be auth-gated or
  briefly down. Most of these tests exist to prove that cannot happen.
  """
  use McpRegistry.DataCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Probe
  alias McpRegistry.Probe.Runner
  alias McpRegistry.Registry.Server

  defp remote_fixture(attrs \\ %{}) do
    server_fixture(
      Map.merge(
        %{
          transport: "streamable-http",
          remote_url: "https://mcp.example.test/mcp",
          package_registry: nil,
          package_identifier: nil
        },
        attrs
      )
    )
  end

  # Req.Test needs the stub wired through config, matching how the official
  # registry sync is tested.
  defp stub(fun) do
    Req.Test.stub(McpRegistry.Probe, fun)
    Application.put_env(:mcp_registry, :probe, req_options: [plug: {Req.Test, McpRegistry.Probe}])
    on_exit(fn -> Application.delete_env(:mcp_registry, :probe) end)
  end

  defp json(conn, payload) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(payload))
  end

  describe "probing an endpoint" do
    test "returns the tool names a server reports" do
      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" ->
            json(conn, %{jsonrpc: "2.0", id: 1, result: %{protocolVersion: "2025-06-18"}})

          "tools/list" ->
            json(conn, %{
              jsonrpc: "2.0",
              id: 2,
              result: %{tools: [%{name: "search_docs"}, %{name: "get_page"}]}
            })

          _ ->
            Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert {:ok, %{tools: ["search_docs", "get_page"]}} = Probe.probe(remote_fixture())
    end

    test "reads a Streamable HTTP server that answers with SSE" do
      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        method = Jason.decode!(body)["method"]

        payload =
          case method do
            "initialize" -> %{jsonrpc: "2.0", id: 1, result: %{protocolVersion: "2025-06-18"}}
            _ -> %{jsonrpc: "2.0", id: 2, result: %{tools: [%{name: "only_tool"}]}}
          end

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, "event: message\ndata: #{Jason.encode!(payload)}\n\n")
      end)

      assert {:ok, %{tools: ["only_tool"]}} = Probe.probe(remote_fixture())
    end

    test "an auth-gated endpoint is reported as such, not as broken" do
      stub(fn conn -> Plug.Conn.send_resp(conn, 401, "") end)

      assert {:error, :unauthorized} = Probe.probe(remote_fixture())
    end

    test "something that is not an MCP server is unsupported" do
      stub(fn conn -> json(conn, %{hello: "world"}) end)

      assert {:error, :unsupported} = Probe.probe(remote_fixture())
    end

    test "prompts and resources are collected alongside the tools" do
      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" ->
            json(conn, %{jsonrpc: "2.0", id: 1, result: %{}})

          "tools/list" ->
            json(conn, %{jsonrpc: "2.0", id: 2, result: %{tools: [%{name: "search"}]}})

          "prompts/list" ->
            json(conn, %{jsonrpc: "2.0", id: 2, result: %{prompts: [%{name: "summarise"}]}})

          "resources/list" ->
            # A resource is identified by uri, not name.
            json(conn, %{jsonrpc: "2.0", id: 2, result: %{resources: [%{uri: "file:///readme"}]}})

          _ ->
            Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert {:ok, found} = Probe.probe(remote_fixture())
      assert found.tools == ["search"]
      assert found.prompts == ["summarise"]
      assert found.resources == ["file:///readme"]
    end

    test "a server that refuses prompts still reports its tools" do
      # Observed on live endpoints: tools/list answers, prompts/list errors.
      # One refused call must not discard the rest of the probe.
      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" -> json(conn, %{jsonrpc: "2.0", id: 1, result: %{}})
          "tools/list" -> json(conn, %{jsonrpc: "2.0", id: 2, result: %{tools: [%{name: "a"}]}})
          "prompts/list" -> json(conn, %{jsonrpc: "2.0", id: 2, error: %{code: -32_601}})
          _ -> Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert {:ok, %{tools: ["a"], prompts: [], resources: []}} = Probe.probe(remote_fixture())
    end

    test "a packaged server is never executed to find out" do
      # No stub: reaching the network at all would be the bug.
      assert {:error, :not_remote} = Probe.probe(server_fixture())
    end
  end

  describe "recording a batch" do
    test "a successful probe replaces the tools and records provenance" do
      remote_fixture(%{tools: ["declared_only"]})

      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" ->
            json(conn, %{jsonrpc: "2.0", id: 1, result: %{}})

          "tools/list" ->
            json(conn, %{jsonrpc: "2.0", id: 2, result: %{tools: [%{name: "real_tool"}]}})

          _ ->
            Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert %{ok: 1} = Runner.run_batch(limit: 10)

      server = Repo.one(Server)
      assert server.tools == ["real_tool"]
      assert server.tools_source == "probed"
      assert server.probe_status == "ok"
      assert server.probed_at
    end

    test "an auth-gated endpoint keeps the tools the publisher declared" do
      remote_fixture(%{tools: ["declared_a", "declared_b"]})
      stub(fn conn -> Plug.Conn.send_resp(conn, 403, "") end)

      assert %{unauthorized: 1} = Runner.run_batch(limit: 10)

      server = Repo.one(Server)
      # The whole point: a locked door is not evidence of an empty room.
      assert server.tools == ["declared_a", "declared_b"]
      assert server.probe_status == "unauthorized"
      refute server.tools_source == "probed"
    end

    test "a server that answers with no tools does not erase declared ones" do
      remote_fixture(%{tools: ["declared_a"]})

      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" -> json(conn, %{jsonrpc: "2.0", id: 1, result: %{}})
          "tools/list" -> json(conn, %{jsonrpc: "2.0", id: 2, result: %{tools: []}})
          _ -> Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert %{ok: 1} = Runner.run_batch(limit: 10)
      assert Repo.one(Server).tools == ["declared_a"]
    end

    test "having no prompts is recorded, because it is the finding" do
      # Tools are protected from an empty answer because a publisher declared
      # them. Nothing declares prompts, so the probe is the only source and
      # "asked, and has none" has to be storable -- otherwise it is
      # indistinguishable from never asked, which is the count being collected.
      remote_fixture(%{tools: ["declared_a"]})

      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode!(body)["method"] do
          "initialize" -> json(conn, %{jsonrpc: "2.0", id: 1, result: %{}})
          "tools/list" -> json(conn, %{jsonrpc: "2.0", id: 2, result: %{tools: []}})
          "resources/list" -> json(conn, %{jsonrpc: "2.0", id: 2, result: %{resources: []}})
          _ -> Plug.Conn.send_resp(conn, 202, "")
        end
      end)

      assert %{ok: 1} = Runner.run_batch(limit: 10)

      server = Repo.one(Server)
      assert server.tools == ["declared_a"]
      assert server.prompts == []
      assert server.resources == []
      assert server.probe_status == "ok"
    end

    test "packaged listings are never picked up by the runner" do
      server_fixture(%{tools: ["declared"]})

      assert %{asked: 0} = Runner.run_batch(limit: 10)
      assert Runner.pending() == 0
    end

    test "a probed listing is not asked again until it goes stale" do
      remote_fixture()
      stub(fn conn -> Plug.Conn.send_resp(conn, 401, "") end)

      assert %{asked: 1} = Runner.run_batch(limit: 10)
      # Same run again: already probed, nothing due.
      assert %{asked: 0} = Runner.run_batch(limit: 10)
      assert Runner.pending() == 0
    end
  end
end
