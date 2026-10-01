defmodule McpRegistry.Changes do
  @moduledoc """
  What changed about a listing, recorded as it is noticed.

  Two processes already re-read every listing on a schedule: the official
  registry sync (every six hours, for `server.json`) and the prober (for the
  tools, prompts and resources a live server reports). Both used to overwrite
  what they found. This keeps the difference.

  ## What is not a change

  A changelog that reports our own bookkeeping as the publisher's activity is
  worse than none, so most of the rules here are about what *not* to record:

    * **Nothing is recorded on first sight.** A listing's first import, or a
      server's first answer, is a baseline, not an event.
    * **Tools changing from declared to probed is not recorded.** That is our
      knowledge improving, not the server changing. Only probe-to-probe
      differences count.
    * **Prompts and resources from before #{"2026-09-24"} are not compared.**
      Probes before then never asked for them, so an empty list then meant
      "not asked", and comparing it to a real answer would report every
      prompt the server has always had as newly added.
    * **A list at the probe's 500-item cap is not compared.** When a server
      with 1,045 resources adds one, another falls off our end of the list,
      and that would read as a removal that never happened.
    * **The sync's re-apply runs are not recorded.** They change how we read
      upstream data, not the data.
  """
  import Ecto.Query

  alias McpRegistry.Changes.Change
  alias McpRegistry.Probe
  alias McpRegistry.Registry.Server
  alias McpRegistry.Repo

  # When the prober started asking for prompts and resources. See moduledoc.
  @capabilities_since ~U[2026-09-24 19:47:00Z]

  # The server.json fields a reader would call a change. synced_at,
  # source_updated_at and the like are ours, not the publisher's.
  @tracked_fields ~w(title description version transport remote_url package_registry
                     package_identifier repository_url website_url icon_url env_vars
                     license status)a

  @labels %{
    "tools" => "Tools",
    "prompts" => "Prompts",
    "resources" => "Resources",
    "server_json" => "server.json",
    "llms_txt" => "llms.txt",
    "agents_md" => "AGENTS.md"
  }

  # --- Recording -------------------------------------------------------------

  @doc """
  Records what a successful probe found that differs from what the listing
  held before it. `before` is the row as it was; `found` is the probe's map of
  `tools`, `prompts` and `resources`.
  """
  def record_probe(%Server{} = before, %{} = found) do
    [
      tools_change(before, found[:tools] || []),
      list_change(before, :prompts, found[:prompts] || []),
      list_change(before, :resources, found[:resources] || [])
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {kind, diff} -> entry(before, Atom.to_string(kind), diff, "probe") end)
    |> insert_all()
  end

  @doc """
  Records the publisher-visible fields a sync is about to change on an
  existing listing, from the changeset that will write them.
  """
  def record_sync(%Server{id: id} = before, %Ecto.Changeset{changes: changes})
      when not is_nil(id) do
    fields =
      for field <- @tracked_fields,
          Map.has_key?(changes, field),
          Map.get(before, field) != changes[field],
          into: %{},
          do: {Atom.to_string(field), [Map.get(before, field), changes[field]]}

    if map_size(fields) == 0 do
      []
    else
      insert_all([entry(before, "server_json", %{fields: fields}, "sync")])
    end
  end

  def record_sync(_before, _changeset), do: []

  @doc """
  Records a change to a fetched document (llms.txt, AGENTS.md), against its
  URL rather than any one listing -- see the moduledoc on why.
  """
  def record_document(url, kind, attrs) when kind in ["llms_txt", "agents_md"] do
    insert_all([
      Map.merge(
        %{
          server_id: nil,
          document_url: url,
          kind: kind,
          added: [],
          removed: [],
          fields: %{},
          source: "fetch",
          inserted_at: DateTime.utc_now()
        },
        attrs
      )
    ])
  end

  defp tools_change(%Server{tools_source: "probed", tools: old}, [_ | _] = new),
    do: list_entry(%{tools: old}, :tools, new)

  defp tools_change(_before, _new), do: nil

  defp list_change(%Server{probe_status: "ok", probed_at: %DateTime{} = at} = before, kind, new) do
    old = Map.fetch!(before, kind)
    cap = Probe.max_items()

    cond do
      DateTime.compare(at, @capabilities_since) == :lt -> nil
      length(old) >= cap or length(new) >= cap -> nil
      true -> list_entry(before, kind, new)
    end
  end

  defp list_change(_before, _kind, _new), do: nil

  # A set difference, kept in the server's own order: the order a server lists
  # things in is usually the order its author thinks of them in.
  defp list_entry(before, kind, new) do
    old = Map.fetch!(before, kind)
    old_set = MapSet.new(old)
    new_set = MapSet.new(new)

    added = Enum.reject(new, &MapSet.member?(old_set, &1))
    removed = Enum.reject(old, &MapSet.member?(new_set, &1))

    if added == [] and removed == [] do
      nil
    else
      {kind, %{added: added, removed: removed}}
    end
  end

  defp entry(%Server{id: id}, kind, attrs, source) do
    Map.merge(
      %{
        server_id: id,
        document_url: nil,
        kind: kind,
        added: [],
        removed: [],
        fields: %{},
        source: source,
        inserted_at: DateTime.utc_now()
      },
      attrs
    )
  end

  defp insert_all([]), do: []

  defp insert_all(rows) do
    {_, inserted} = Repo.insert_all(Change, rows, returning: true)
    inserted
  end

  # --- Reading ---------------------------------------------------------------

  @doc "A listing's changes, newest first. `kind` narrows to one kind."
  def for_server(%Server{} = server, kind \\ nil, limit \\ 200) do
    server
    |> subject_query()
    |> then(fn q -> if kind, do: where(q, [c], c.kind == ^kind), else: q end)
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "How many changes a listing has of each kind, as `%{kind => count}`."
  def kinds_for_server(%Server{} = server) do
    server
    |> subject_query()
    |> group_by([c], c.kind)
    |> select([c], {c.kind, count(c.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  The most recent changes across the whole registry, each with a listing to
  show it under. A document change is shown under one listing that points at
  the document, since it has none of its own.
  """
  def recent(limit \\ 100) do
    changes =
      Change
      |> order_by([c], desc: c.inserted_at, desc: c.id)
      |> limit(^limit)
      |> Repo.all()

    urls = for %{document_url: url} <- changes, url, uniq: true, do: url

    via =
      from(sd in "server_documents",
        where: sd.url in ^urls,
        group_by: sd.url,
        select: {sd.url, min(sd.server_id)}
      )
      |> Repo.all()
      |> Map.new()

    ids = Enum.uniq(for(%{server_id: id} <- changes, id, do: id) ++ Map.values(via))

    servers =
      from(s in Server, where: s.id in ^ids, select: struct(s, [:id, :name, :title, :status]))
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    for change <- changes,
        server = servers[change.server_id || via[change.document_url]],
        server && server.status == "active",
        do: %{change | server: server}
  end

  @doc "How many active listings have at least one recorded change."
  def count_servers_with_changes do
    by_listing()
    |> join(:inner, [u], s in Server, on: s.id == u.server_id and s.status == "active")
    |> select([u], count(u.server_id, :distinct))
    |> Repo.one()
  end

  @doc """
  A page of active listings with changes, as `{name, kinds, latest}` -- the
  shape the sitemap needs, without loading any listing in full.
  """
  def servers_with_changes(offset, limit) do
    by_listing()
    |> join(:inner, [u], s in Server, on: s.id == u.server_id and s.status == "active")
    |> group_by([u, s], [s.id, s.name])
    |> order_by([u, s], asc: s.id)
    |> offset(^offset)
    |> limit(^limit)
    |> select([u, s], {s.name, fragment("array_agg(DISTINCT ?)", u.kind), max(u.at)})
    |> Repo.all()
  end

  # Every change attributed to a listing: its own, plus those of the documents
  # it points at, which are recorded against their URL.
  defp by_listing do
    own =
      from c in Change,
        where: not is_nil(c.server_id),
        select: %{server_id: c.server_id, kind: c.kind, at: c.inserted_at}

    via_documents =
      from c in Change,
        join: sd in "server_documents",
        on: sd.url == c.document_url,
        select: %{server_id: sd.server_id, kind: c.kind, at: c.inserted_at}

    subquery(union_all(own, ^via_documents))
  end

  # A listing's changelog includes the documents it points at.
  defp subject_query(%Server{id: id}) do
    urls = from(sd in "server_documents", where: sd.server_id == ^id, select: sd.url)
    where(Change, [c], c.server_id == ^id or c.document_url in subquery(urls))
  end

  # --- Naming ----------------------------------------------------------------

  @doc "How a kind is shown to a reader: `llms.txt`, `server.json`, `Tools`."
  def label(kind), do: Map.fetch!(@labels, kind)

  @doc "A kind as a URL segment: `server_json` becomes `server-json`."
  def slug(kind), do: String.replace(kind, "_", "-")

  @doc "The kind a URL segment names, or `nil`."
  def from_slug(slug) when is_binary(slug) do
    kind = String.replace(slug, "-", "_")
    if Map.has_key?(@labels, kind), do: kind
  end
end
