defmodule McpRegistry.Documents.Scheduler do
  @moduledoc """
  Checks llms.txt and AGENTS.md files on a timer, and rediscovers which
  listings point at which once a day.

  ## Why a timer and not GitHub webhooks

  A webhook needs admin rights on the repository, or a GitHub App its owner
  installs; this registry has neither for almost every listing, and llms.txt
  is served by websites that offer no webhooks at all. Polling with
  conditional requests is the only thing that covers the whole catalogue, and
  it is cheap: an unchanged file answers `304` with no body. See
  `McpRegistry.Documents`.

  ## Pace

  A batch every five minutes at a concurrency of four, and each URL once a
  week. That is a trickle -- a few thousand requests a day spread across
  thousands of hosts -- which is what fetching other people's files should be.

  Set `DOCUMENTS_ENABLED=false` to stop it.
  """
  use GenServer

  require Logger

  alias McpRegistry.Documents

  @rediscover_every :timer.hours(24)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    config = config()

    if config[:enabled] do
      Process.send_after(self(), :tick, config[:initial_delay_ms])
      {:ok, %{discovered_at: nil}}
    else
      :ignore
    end
  end

  @impl true
  def handle_info(:tick, state) do
    config = config()
    now = System.monotonic_time(:millisecond)

    # Never let one bad tick stop the next: it is scheduled whatever happened.
    state =
      try do
        state = maybe_discover(state, now)

        tally =
          Documents.check_batch(
            limit: config[:batch_size],
            concurrency: config[:concurrency],
            recheck_days: config[:recheck_days]
          )

        if tally != %{}, do: Logger.info("Document check: #{inspect(tally)}")
        state
      rescue
        error ->
          Logger.warning("Document check failed: #{Exception.message(error)}")
          state
      catch
        kind, reason ->
          Logger.warning("Document check #{kind}: #{inspect(reason)}")
          state
      end

    Process.send_after(self(), :tick, config[:interval_ms])
    {:noreply, state}
  end

  defp maybe_discover(%{discovered_at: at} = state, now)
       when is_integer(at) and now - at < @rediscover_every,
       do: state

  defp maybe_discover(state, now) do
    links = Documents.discover()
    Logger.info("Document discovery: #{links} listing-to-document links")
    %{state | discovered_at: now}
  end

  defp config, do: Application.get_env(:mcp_registry, :documents, [])
end
