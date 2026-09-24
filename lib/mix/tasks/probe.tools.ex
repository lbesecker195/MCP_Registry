defmodule Mix.Tasks.Probe.Tools do
  @shortdoc "Asks remote MCP servers what tools they have"

  @moduledoc """
  Connects to remote listings and records the tools they report.

      mix probe.tools                      # one batch of 100
      mix probe.tools --limit 500          # a bigger batch
      mix probe.tools --all                # keep going until none are due
      mix probe.tools --concurrency 10

  Packaged (`stdio`) listings are skipped: finding their tools would mean
  running a stranger's code. Expect roughly a quarter of endpoints to answer
  and most of the rest to be auth-gated — that is normal, not a fault.
  """
  use Mix.Task

  alias McpRegistry.Probe.Runner

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [limit: :integer, concurrency: :integer, recheck_days: :integer, all: :boolean]
      )

    pending = Runner.pending(Keyword.get(opts, :recheck_days, 14))
    Mix.shell().info("#{pending} remote listing(s) due")

    if Keyword.get(opts, :all, false), do: loop(opts, %{}), else: report(Runner.run_batch(opts))
  end

  defp loop(opts, totals) do
    tally = Runner.run_batch(opts)

    if Map.get(tally, :asked, 0) == 0 do
      report(totals)
    else
      loop(opts, Map.merge(totals, tally, fn _k, a, b -> a + b end))
    end
  end

  defp report(tally) do
    Mix.shell().info("""

    asked        #{Map.get(tally, :asked, 0)}
    answered     #{Map.get(tally, :ok, 0)}
    auth-gated   #{Map.get(tally, :unauthorized, 0)}
    unsupported  #{Map.get(tally, :unsupported, 0)}
    unreachable  #{Map.get(tally, :unreachable, 0)}
    """)
  end
end
