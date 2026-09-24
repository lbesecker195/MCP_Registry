defmodule McpRegistry.Probe.Runner do
  @moduledoc """
  Walks the remote listings a batch at a time, asking each what tools it has.

  There are about 21,000 remote endpoints. This is deliberately a resumable
  batch job rather than one long sweep: it takes the least recently probed
  listings, asks them, writes what it learns, and stops. Run it repeatedly —
  from a cron, or `mix probe.tools` — and the catalogue converges.

  ## Rules it will not break

    * **Nothing is executed.** Packaged (`stdio`) listings are skipped; finding
      their tools would mean running a stranger's code on our host.
    * **A failed probe never empties a tool list.** Roughly seven in ten
      endpoints are auth-gated, and treating silence as "no tools" would wipe
      what publishers declared. Tools are only ever written on success.
    * **Memory stays flat.** Each batch loads a bounded number of rows and
      writes them back before the next; the catalogue is never in memory.
  """
  require Logger

  import Ecto.Query

  alias McpRegistry.{Probe, Repo}
  alias McpRegistry.Registry.Server

  @default_batch 100
  @default_concurrency 6
  @default_recheck_days 14

  @doc """
  Probes one batch and returns a tally.

  Options: `:limit` (default #{@default_batch}), `:concurrency`
  (default #{@default_concurrency}), and `:recheck_days` (default
  #{@default_recheck_days}) — how stale a previous probe must be before an
  endpoint is asked again.
  """
  def run_batch(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_batch)
    concurrency = Keyword.get(opts, :concurrency, @default_concurrency)
    servers = due(limit, Keyword.get(opts, :recheck_days, @default_recheck_days))

    results =
      servers
      |> Task.async_stream(&probe_and_record/1,
        max_concurrency: concurrency,
        # Generous: the probe's own receive timeout is 12s and there are three
        # round trips. A task killed here would still have written nothing.
        timeout: 60_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, outcome} -> outcome
        {:exit, _} -> :unreachable
      end)

    tally = Enum.frequencies(results)

    Logger.info(
      "Probe batch: #{length(servers)} asked, " <>
        "#{Map.get(tally, :ok, 0)} answered, #{Map.get(tally, :unauthorized, 0)} auth-gated"
    )

    Map.put(tally, :asked, length(servers))
  end

  @doc "How many remote listings are still waiting to be asked."
  def pending(recheck_days \\ @default_recheck_days) do
    recheck_days |> due_query() |> Repo.aggregate(:count)
  end

  defp due(limit, recheck_days) do
    recheck_days
    |> due_query()
    # Never probed first, then the longest-stale.
    |> order_by([s], asc_nulls_first: s.probed_at, asc: s.id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp due_query(recheck_days) do
    cutoff = DateTime.add(DateTime.utc_now(), -recheck_days * 24 * 3600, :second)

    Server
    |> where([s], s.status == "active")
    |> where([s], s.transport in ["streamable-http", "sse"])
    |> where([s], not is_nil(s.remote_url))
    |> where([s], is_nil(s.probed_at) or s.probed_at < ^cutoff)
  end

  defp probe_and_record(%Server{} = server) do
    case Probe.probe(server) do
      {:ok, found} ->
        # Only a successful probe writes tools, and only when it actually found
        # some: an empty list from a server that answered is still not a reason
        # to delete what the publisher declared.
        tools =
          if found.tools == [],
            do: %{},
            else: %{tools: found.tools, tools_source: "probed"}

        # Prompts and resources are written even when empty, and the difference
        # is not an inconsistency. Nothing declares them -- there is no publisher
        # claim to protect, so the only source is the probe, and "this server
        # answered and has none" is the finding. Left unwritten, a server with
        # no prompts would be indistinguishable from one never asked, which is
        # exactly the count this is being collected to settle.
        changes = Map.merge(tools, %{prompts: found.prompts, resources: found.resources})

        record(server, :ok, changes)
        :ok

      {:error, reason} ->
        record(server, reason, %{})
        reason
    end
  end

  defp record(server, status, changes) do
    attrs =
      Map.merge(changes, %{
        probe_status: to_string(status),
        probed_at: DateTime.utc_now()
      })

    server
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        updated

      {:error, changeset} ->
        Logger.warning("Probe could not record #{server.name}: #{inspect(changeset.errors)}")
        server
    end
  rescue
    # `Repo.update/1` returns a changeset for a validation failure but raises
    # for a database one, and the raise leaves through `Task.async_stream` and
    # takes the whole batch with it. One resource URI longer than the column
    # cost the other 399 probes in its batch that way. What one endpoint
    # answers is not under our control, so this must not be fatal to the rest.
    error ->
      Logger.warning("Probe could not record #{server.name}: #{Exception.message(error)}")
      server
  end
end
