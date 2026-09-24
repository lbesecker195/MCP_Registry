defmodule McpRegistry.Probe.Scheduler do
  @moduledoc """
  Runs `McpRegistry.Probe.Runner` batches on a timer, so the catalogue's tool
  data fills in on its own instead of waiting for someone to run a Mix task on
  the box.

  ## Pace, and why it is slow on purpose

  This makes outbound requests to other people's servers — about 21,000 of
  them. The defaults ask 50 endpoints every five minutes with a concurrency of
  four, which is roughly 600 an hour and means a first pass takes a day and a
  half. That is deliberate: a faster sweep would look like scanning, and there
  is no deadline here.

  Requests carry a user agent naming the registry and linking to it, and a
  probed endpoint is not asked again for two weeks, so a steady state is a
  trickle rather than a sweep.

  Set `PROBE_ENABLED=false` to stop it entirely.
  """
  use GenServer

  require Logger

  alias McpRegistry.Probe.Runner

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    config = config()

    if config[:enabled] do
      Process.send_after(self(), :tick, config[:initial_delay_ms])
      {:ok, %{}}
    else
      :ignore
    end
  end

  @impl true
  def handle_info(:tick, state) do
    config = config()

    # Never let a failed batch take the scheduler down with it: the next tick
    # is scheduled whatever happened.
    try do
      Runner.run_batch(
        limit: config[:batch_size],
        concurrency: config[:concurrency],
        recheck_days: config[:recheck_days]
      )
    rescue
      error -> Logger.warning("Probe batch failed: #{Exception.message(error)}")
    catch
      kind, reason -> Logger.warning("Probe batch #{kind}: #{inspect(reason)}")
    end

    Process.send_after(self(), :tick, config[:interval_ms])
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp config, do: Application.get_env(:mcp_registry, :probe, [])
end
