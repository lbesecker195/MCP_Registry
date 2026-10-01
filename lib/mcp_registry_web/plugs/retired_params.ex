defmodule McpRegistryWeb.Plugs.RetiredParams do
  @moduledoc """
  Permanently redirects a page request that carries a query parameter the site
  no longer uses to the same URL without it.

  `?tag=` drove browse-by-tag, which was removed because too few listings carry
  tags for a tag page to be worth landing on. Every listing page, the home page
  and the footer linked to `/servers?tag=…`, so crawlers and bookmarks hold
  those URLs. Left alone, each would now render a copy of `/servers` under its
  own URL; a 301 folds them back into the page they actually show.

  Only page requests pass through here. The JSON API keeps its `tag` filter:
  it is a query parameter clients may rely on, not a page anyone browses.
  """
  @behaviour Plug

  import Plug.Conn

  @retired ~w(tag)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "GET"} = conn, _opts) do
    conn = fetch_query_params(conn)

    if Enum.any?(@retired, &Map.has_key?(conn.query_params, &1)) do
      kept = Map.drop(conn.query_params, @retired)
      query = if kept == %{}, do: "", else: "?" <> Plug.Conn.Query.encode(kept)

      conn
      |> put_resp_header("location", conn.request_path <> query)
      |> send_resp(:moved_permanently, "")
      |> halt()
    else
      conn
    end
  end

  def call(conn, _opts), do: conn
end
