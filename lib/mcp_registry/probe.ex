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
  @type result ::
          {:ok, [String.t()]}
          | {:error, :not_remote | :unauthorized | :unsupported | :unreachable}

  @doc "Asks a listing's endpoint for its tools."
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
         {:ok, tools} <- list_tools(url, session) do
      {:ok, tools}
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

  defp list_tools(url, session) do
    case post(url, %{jsonrpc: "2.0", id: 2, method: "tools/list"}, session) do
      {:ok, %Req.Response{status: status, body: raw}} when status in 200..299 ->
        case decode(raw) do
          %{"result" => %{"tools" => tools}} when is_list(tools) -> {:ok, names(tools)}
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

  defp names(tools) do
    tools
    |> Enum.map(fn
      %{"name" => name} when is_binary(name) -> String.trim(name)
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
