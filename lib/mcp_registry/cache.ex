defmodule McpRegistry.Cache do
  @moduledoc """
  A small in-memory cache for values that every page needs and almost nothing
  changes: the catalogue counters and the tag cloud.

  Entries expire on a TTL *and* are dropped whenever a listing is written, so
  the day-long lifetime is a ceiling rather than a staleness guarantee. A
  submission or an official-registry sync is reflected on the next request, not
  a day later.

  Deliberately not a dependency and deliberately tiny. It holds a handful of
  tuples, not query results by the thousand -- this application has already
  been taken down once by putting something large in memory alongside Postgres.

  Reads go straight to ETS with no GenServer in the path, so a hot page does
  not serialise behind a single process. The GenServer exists only to own the
  table so it survives the caller.

  ## Off under test

  The table is global while `async: true` tests each hold their own database
  sandbox, so a value one test computed can be handed to another that cannot
  see the rows behind it. That is a flaky failure with no bearing on the code
  under test, and caching a count nobody is measuring buys nothing, so
  `config/test.exs` turns it off.
  """
  use GenServer

  @table :mcp_registry_cache

  @doc "One day, the default lifetime for catalogue-wide figures."
  def day, do: :timer.hours(24)

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))

  @doc """
  Returns the cached value for `key`, or computes it with `fun` and stores it.

  If the table does not exist -- in a unit test that never starts the
  application, say -- `fun` is called directly. A cache is an optimisation; it
  must never be the reason something fails.
  """
  def fetch(key, ttl \\ nil, fun) when is_function(fun, 0) do
    if Application.get_env(:mcp_registry, :cache_enabled, true) do
      cached(key, ttl, fun)
    else
      fun.()
    end
  end

  defp cached(key, ttl, fun) do
    ttl = ttl || day()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        value

      _ ->
        value = fun.()
        :ets.insert(@table, {key, value, now + ttl})
        value
    end
  rescue
    ArgumentError -> fun.()
  end

  @doc "Drops everything. Called after any write that could change a count."
  def invalidate do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end
end
