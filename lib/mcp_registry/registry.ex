defmodule McpRegistry.Registry do
  @moduledoc "The registry: listing, searching, publishing and approving MCP servers."
  import Ecto.Query, warn: false

  alias McpRegistry.Analytics
  alias McpRegistry.Cache
  alias McpRegistry.Discovery
  alias McpRegistry.Repo
  alias McpRegistry.Registry.Server

  @default_limit 30
  @max_limit 100

  @doc """
  Lists servers. Options: `:q` (free text), `:transport`, `:tag`, `:status`
  (default `"active"`), `:limit` (max #{@max_limit}) and `:offset`.
  """
  def list_servers(opts \\ []) do
    opts
    |> base_query()
    # Hand-curated and locally submitted listings first, then the official
    # catalogue with the most recently updated servers first.
    |> order_by([s],
      asc: fragment("CASE WHEN ? = 'official' THEN 1 ELSE 0 END", s.origin),
      desc_nulls_last: s.source_updated_at,
      asc: s.title,
      asc: s.id
    )
    |> limit(^limit(opts))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> Repo.all()
  end

  def count_servers(opts \\ []), do: opts |> base_query() |> Repo.aggregate(:count)

  # Names are stored lowercase; the official registry allows mixed case.
  def get_server!(name), do: Repo.get_by!(Server, name: String.downcase(name))

  @doc """
  Whether a listing exists, without loading it.

  Used by `McpRegistryWeb.Plugs.KnownServer` to decide between serving the page
  and redirecting, so it selects a constant rather than the row's columns --
  several of which (`article_content`, `tools`) are large.
  """
  def server_exists?(name) when is_binary(name) do
    Repo.exists?(from s in Server, where: s.name == ^String.downcase(name))
  end

  def fetch_server(name) when is_binary(name) do
    case Repo.get_by(Server, name: String.downcase(name)) do
      nil -> {:error, :not_found}
      server -> {:ok, server}
    end
  end

  @doc """
  Publishes a listing. `:status` (default `"pending"`) is decided by the caller,
  never by the submitted attributes; `:source` is only used for analytics, and
  `:origin` (default `"local"`) records where the listing came from.

  Returns `{:error, :queue_full}` when a pending listing would exceed the
  configured `:max_pending`.
  """
  def create_server(attrs, opts \\ []) do
    status = Keyword.get(opts, :status, "pending")

    with :ok <- check_queue_capacity(status) do
      attrs = attrs |> Map.new(fn {k, v} -> {to_string(k), v} end) |> Map.put("status", status)

      %Server{}
      |> Server.changeset(attrs)
      |> Ecto.Changeset.put_change(:origin, Keyword.get(opts, :origin, "local"))
      |> Repo.insert()
      |> invalidate_on_write()
      |> tap(fn
        {:ok, server} ->
          Analytics.track(:server_submitted, %{
            status: server.status,
            transport: server.transport,
            source: Keyword.get(opts, :source, "web")
          })

        _ ->
          :ok
      end)
      |> announce_if_live()
    end
  end

  def update_server(%Server{} = server, attrs) do
    server |> Server.changeset(attrs) |> Repo.update() |> invalidate_on_write()
  end

  def approve_server(name) when is_binary(name) do
    with {:ok, server} <- fetch_server(name) do
      server
      |> Ecto.Changeset.change(status: "active")
      |> Repo.update()
      |> invalidate_on_write()
      |> announce_if_live()
    end
  end

  def change_server(%Server{} = server, attrs \\ %{}), do: Server.changeset(server, attrs)

  @doc "Deletes a pending listing. Active listings cannot be rejected."
  def reject_server(name) when is_binary(name) do
    with {:ok, server} <- fetch_server(name) do
      if server.status == "pending",
        do: server |> Repo.delete() |> invalidate_on_write(),
        else: {:error, :not_pending}
    end
  end

  @doc """
  Drops the cached catalogue figures.

  Called after anything that changes what `stats/0` or `top_tags/1` would
  answer, so the day-long TTL is a ceiling rather than a staleness guarantee.
  The official-registry sync calls this once at the end of a run rather than
  per row.
  """
  def invalidate_cache, do: Cache.invalidate()

  defp invalidate_on_write({:ok, _} = result) do
    Cache.invalidate()
    result
  end

  defp invalidate_on_write(result), do: result

  # A listing that has just gone live is new to search engines and to the feed.
  defp announce_if_live({:ok, %Server{status: "active", name: name}} = result) do
    Discovery.announce_later([name], feed: true)
    result
  end

  defp announce_if_live(result), do: result

  defp check_queue_capacity("pending") do
    max = Application.get_env(:mcp_registry, :submissions, [])[:max_pending] || 500
    if count_servers(status: "pending") >= max, do: {:error, :queue_full}, else: :ok
  end

  defp check_queue_capacity(_status), do: :ok

  @doc """
  One page of `{name, updated_at}` for active listings, in a stable order, for
  the sitemap and the IndexNow backfill. Selects two columns only: whole rows
  carry the article text and tool lists.
  """
  def sitemap_entries(page, per_page) when page >= 1 do
    Server
    |> where([s], s.status == "active")
    |> order_by([s], asc: s.id)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> select([s], {s.name, s.updated_at})
    |> Repo.all()
  end

  @doc """
  Active listings that declare at least one tool, for the tools sitemap.

  Deliberately unpaginated: the whole catalogue holds only a few hundred tool
  names, so this is a short list, not a scan. If tool coverage ever grows to
  catalogue scale this has to become a paged query like `sitemap_entries/2`.
  """
  def servers_with_tools do
    Server
    |> where([s], s.status == "active")
    |> where([s], fragment("cardinality(?) > 0", s.tools))
    |> order_by([s], asc: s.id)
    |> Repo.all()
  end

  @doc """
  The `n` active listings added most recently, newest first, for the feed.
  Cached like the catalogue figures, so the sync and every approval refresh it.
  """
  def newest_servers(n) do
    Cache.fetch({:newest_servers, n}, fn ->
      Server
      |> where([s], s.status == "active")
      |> order_by([s], desc: s.inserted_at, desc: s.id)
      |> limit(^n)
      |> select([s], struct(s, [:name, :title, :description, :inserted_at, :updated_at]))
      |> Repo.all()
    end)
  end

  @doc """
  The most-used tags among active servers, as `{tag, count}` pairs.

  Counted in Postgres. The previous version selected `unnest(tags)` and tallied
  in Elixir, which moved one row per tag per listing -- roughly ninety thousand
  of them -- across the wire on every catalogue and landing page view.
  """
  def top_tags(n \\ 12) do
    Cache.fetch({:top_tags, n}, fn ->
      %{rows: rows} =
        Repo.query!(
          """
          SELECT tag, count(*) AS uses
          FROM (SELECT unnest(tags) AS tag FROM servers WHERE status = 'active') AS tags
          GROUP BY tag
          ORDER BY uses DESC, tag ASC
          LIMIT $1
          """,
          [n]
        )

      Enum.map(rows, fn [tag, uses] -> {tag, uses} end)
    end)
  end

  @doc """
  Catalogue-wide counters for the landing page and the catalogue header.

  One pass over the active rows using filtered aggregates, rather than the five
  separate full-table scans this used to issue per page view.
  """
  def stats do
    Cache.fetch(:stats, fn ->
      %{rows: [row]} =
        Repo.query!("""
        SELECT
          count(*),
          coalesce(sum(cardinality(tools)), 0),
          count(*) FILTER (WHERE transport <> 'stdio'),
          count(*) FILTER (WHERE origin = 'official'),
          -- Listings that exist here and nowhere upstream. `origin` defaults to
          -- 'local' but is nullable on rows predating that default, so NULL
          -- counts as ours too.
          count(*) FILTER (WHERE origin IS NULL OR origin <> 'official')
        FROM servers
        WHERE status = 'active'
        """)

      [servers, tools, remote, official, unique] = row

      %{
        servers: servers,
        tools: trunc(tools),
        remote: remote,
        official: official,
        unique: unique
      }
    end)
  end

  defp base_query(opts) do
    Server
    |> where([s], s.status == ^Keyword.get(opts, :status, "active"))
    |> filter_q(opts[:q])
    |> filter_eq(:transport, opts[:transport])
    |> filter_tag(opts[:tag])
  end

  defp filter_q(query, q) when is_binary(q) do
    case String.trim(q) do
      "" ->
        query

      q ->
        pattern = "%" <> escape_like(q) <> "%"

        # mcp_array_to_text/1 rather than array_to_string/2: same result, but
        # IMMUTABLE, so the trigram indexes on these two columns can exist and
        # the planner can match this expression to them. Change one and the
        # other has to change with it, or search silently falls back to a
        # sequential scan. See the IndexSearchColumns migration.
        where(
          query,
          [s],
          ilike(s.name, ^pattern) or ilike(s.title, ^pattern) or
            ilike(s.description, ^pattern) or
            fragment("mcp_array_to_text(?) ILIKE ?", s.tags, ^pattern) or
            fragment("mcp_array_to_text(?) ILIKE ?", s.tools, ^pattern)
        )
    end
  end

  defp filter_q(query, _), do: query

  defp filter_eq(query, _field, value) when value in [nil, ""], do: query
  defp filter_eq(query, field, value), do: where(query, [s], field(s, ^field) == ^value)

  defp filter_tag(query, tag) when tag in [nil, ""], do: query

  defp filter_tag(query, tag),
    do: where(query, [s], fragment("? = ANY(?)", ^String.downcase(tag), s.tags))

  defp limit(opts) do
    opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit) |> max(1)
  end

  defp escape_like(text), do: String.replace(text, ~r/[\\%_]/, "\\\\\\0")
end
