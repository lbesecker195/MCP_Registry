defmodule McpRegistry.Probe do
  @moduledoc """
  Connects to a listing's remote endpoint and asks it what tools it has.

  The catalogue declares about 134 tools across 34,000 listings, because the
  official registry's `server.json` has nowhere to put a tool list. The only
  authority on a server's tools is the server, so this speaks MCP to it:
  `initialize`, `notifications/initialized`, then `tools/list`.

  ## Only remote servers, on purpose

  A `stdio` listing is an npm, PyPI or OCI package. Discovering its tools would
  mean downloading and executing a stranger's code on our host — 34,000 times.
  That is not a tradeoff worth making for metadata, so `probe/1` refuses
  anything without an HTTP endpoint and says why.

  ## What to expect

  Measured against 30 live endpoints: **8 answered, 21 demanded credentials,
  1 redirected**. So roughly a quarter of remote listings will yield a tool
  list and most of the rest are auth-gated by design. `:unauthorized` is a
  normal, permanent-ish outcome rather than a failure to retry hard.
  """
  require Logger

  alias McpRegistry.Registry.Server

  @protocol_version "2025-06-18"
  @receive_timeout 12_000
  @connect_timeout 6_000

  @typedoc """
  `{:ok, tools}` with a list of names, or a reason it could not be asked.

    * `:not_remote` — a packaged server; we will not run it to find out
    * `:unauthorized` — the endpoint requires credentials (401/403)
    * `:unsupported` — reachable, but not answering MCP
    * `:unreachable` — DNS, TLS, timeout, 5xx
  """
  @type listing :: %{
          tools: [String.t()],
          prompts: [String.t()],
          resources: [String.t()]
        }

  @type result ::
          {:ok, listing()}
          | {:error, :not_remote | :unauthorized | :unsupported | :unreachable}

  @doc """
  Asks a listing's endpoint what it exposes: tools, prompts and resources.

  Returns `{:ok, %{tools: [...], prompts: [...], resources: [...]}}`. A server
  that answers for tools but errors on prompts simply reports no prompts --
  the three lists are independent, and one refusal should not discard the rest.
  """
  @spec probe(Server.t()) :: result()
  def probe(%Server{} = server) do
    if Server.remote?(server) and is_binary(server.remote_url) do
      run(server.remote_url)
    else
      {:error, :not_remote}
    end
  end

  defp run(url) do
    with {:ok, session} <- initialize(url),
         :ok <- initialized(url, session),
         {:ok, tools} <- list(url, session, "tools/list", "tools") do
      {:ok,
       %{
         tools: tools,
         # Best effort: a server that has no prompts, or refuses the call, is
         # reported as having none rather than failing the whole probe.
         prompts: list(url, session, "prompts/list", "prompts") |> ok_or_empty(),
         resources: list(url, session, "resources/list", "resources") |> ok_or_empty()
       }}
    end
  rescue
    # A malformed response must never take down the run that is walking the
    # whole catalogue.
    error ->
      Logger.debug("probe crashed for #{url}: #{Exception.message(error)}")
      {:error, :unsupported}
  catch
    _, _ -> {:error, :unreachable}
  end

  defp initialize(url) do
    body = %{
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: %{
        protocolVersion: @protocol_version,
        capabilities: %{},
        clientInfo: %{name: "mcp-harbor-probe", version: version()}
      }
    }

    case post(url, body, nil) do
      {:ok, %Req.Response{status: status, headers: headers, body: raw}} when status in 200..299 ->
        case decode(raw) do
          %{"result" => _} -> {:ok, session_id(headers)}
          _ -> {:error, :unsupported}
        end

      {:ok, %Req.Response{status: status}} when status in [401, 403, 407] ->
        {:error, :unauthorized}

      {:ok, %Req.Response{}} ->
        {:error, :unsupported}

      {:error, _} ->
        {:error, :unreachable}
    end
  end

  # Fire-and-forget: the spec requires the notification, but a server that
  # ignores it is still worth asking for tools.
  defp initialized(url, session) do
    post(url, %{jsonrpc: "2.0", method: "notifications/initialized"}, session)
    :ok
  end

  defp ok_or_empty({:ok, items}), do: items
  defp ok_or_empty(_), do: []

  defp list(url, session, method, key) do
    case post(url, %{jsonrpc: "2.0", id: 2, method: method}, session) do
      {:ok, %Req.Response{status: status, body: raw}} when status in 200..299 ->
        case decode(raw) do
          %{"result" => %{^key => items}} when is_list(items) -> {:ok, names(items)}
          _ -> {:error, :unsupported}
        end

      {:ok, %Req.Response{status: status}} when status in [401, 403, 407] ->
        {:error, :unauthorized}

      {:ok, %Req.Response{}} ->
        {:error, :unsupported}

      {:error, _} ->
        {:error, :unreachable}
    end
  end

  # A resource is named by uri, a tool and a prompt by name.
  defp names(items) do
    items
    |> Enum.map(fn
      %{"name" => name} when is_binary(name) -> String.trim(name)
      %{"uri" => uri} when is_binary(uri) -> String.trim(uri)
      _ -> nil
    end)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  # Streamable HTTP may answer as JSON or as a one-event SSE stream, and the
  # same server can do either depending on the request, so both are decoded
  # here rather than assumed.
  defp decode(body) when is_map(body), do: body

  defp decode(body) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn
      "data:" <> rest -> String.trim(rest)
      line -> line
    end)
    |> Enum.filter(&String.starts_with?(&1, "{"))
    |> Enum.find_value(%{}, fn line ->
      case Jason.decode(line) do
        {:ok, decoded} -> decoded
        _ -> nil
      end
    end)
  end

  defp decode(_), do: %{}

  defp session_id(headers) do
    case Map.get(headers, "mcp-session-id") do
      [id | _] when is_binary(id) -> id
      id when is_binary(id) -> id
      _ -> nil
    end
  end

  defp post(url, body, session) do
    headers =
      [
        {"content-type", "application/json"},
        {"accept", "application/json, text/event-stream"},
        {"mcp-protocol-version", @protocol_version},
        {"user-agent", user_agent()}
      ] ++ if(session, do: [{"mcp-session-id", session}], else: [])

    Req.post(
      url,
      [
        json: body,
        receive_timeout: @receive_timeout,
        connect_options: [timeout: @connect_timeout],
        retry: false,
        # One endpoint in thirty answered 307; without this they are recorded
        # as broken when they are merely moved.
        redirect: true,
        max_redirects: 3,
        headers: headers
      ] ++ req_options()
    )
  end

  defp req_options, do: Application.get_env(:mcp_registry, :probe, [])[:req_options] || []

  defp version, do: to_string(Application.spec(:mcp_registry, :vsn) || "0.0.0")

  defp user_agent, do: "mcp-harbor-probe/#{version()} (+#{McpRegistryWeb.Endpoint.url()})"
end
