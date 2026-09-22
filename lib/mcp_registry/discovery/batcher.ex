defmodule McpRegistry.Discovery.Batcher do
  @moduledoc """
  Collects the listings `McpRegistry.Discovery.announce_later/2` is handed on
  request paths (an approval, a publish over the API, a saved article) and
  sends them as one `Discovery.announce/2` once `:batch_window_ms` has passed
  since the first arrived.

  A content run saving a few hundred articles then costs a handful of IndexNow
  requests rather than one per article, and IndexNow reads a flood of
  one-URL requests from one host as spam.
  """
  use GenServer

  alias McpRegistry.Discovery

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def enqueue(names, feed?), do: GenServer.cast(__MODULE__, {:enqueue, names, feed?})

  @doc "Sends whatever is waiting now. For tests and shutdown."
  def flush, do: GenServer.call(__MODULE__, :flush, 60_000)

  @impl true
  def init(_opts), do: {:ok, empty()}

  @impl true
  def handle_cast({:enqueue, names, feed?}, state) do
    timer =
      state.timer ||
        Process.send_after(self(), :flush, Discovery.config()[:batch_window_ms] || 60_000)

    {:noreply,
     %{state | names: Enum.reverse(names, state.names), feed: state.feed or feed?, timer: timer}}
  end

  @impl true
  def handle_info(:flush, state), do: {:noreply, send_batch(state)}

  @impl true
  def handle_call(:flush, _from, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:reply, :ok, send_batch(state)}
  end

  defp send_batch(%{names: [], feed: false}), do: empty()

  defp send_batch(state) do
    Discovery.announce(Enum.reverse(state.names), feed: state.feed)
    empty()
  end

  defp empty, do: %{names: [], feed: false, timer: nil}
end
