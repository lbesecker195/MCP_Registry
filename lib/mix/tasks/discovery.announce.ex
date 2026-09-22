defmodule Mix.Tasks.Discovery.Announce do
  @shortdoc "Submits every listing to IndexNow and pings WebSub: mix discovery.announce [--dry-run]"
  @moduledoc """
  #{@shortdoc}

  A one-off backfill for when pushing starts or the domain moves. After that,
  each sync announces only what it changed. `--dry-run` prints what would be
  sent without sending it. Sending needs `config :mcp_registry, :discovery,
  enabled: true`, which only production sets. In production, run `bin/announce`
  from the release instead.
  """
  use Mix.Task

  alias McpRegistry.{Discovery, Registry}

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    if "--dry-run" in args do
      count = Registry.count_servers()
      sample = 1 |> Registry.sitemap_entries(3) |> Enum.map(&Discovery.server_url(elem(&1, 0)))

      Mix.shell().info("""
      Would submit #{count} listings and #{length(Discovery.static_urls())} other pages to IndexNow in #{ceil(count / Discovery.batch_size())} batch(es), e.g.
        #{Enum.join(sample, "\n  ")}
      Key file: #{Discovery.key_url()}
      WebSub: #{Discovery.feed_url()} via #{Enum.join(Discovery.hubs(), ", ")}
      Pushing is #{if Discovery.enabled?(), do: "on", else: "off"} in this environment.
      """)
    else
      case Discovery.announce_all() do
        :disabled -> Mix.raise("Discovery is disabled in this environment; see --dry-run.")
        {:error, reason} -> Mix.raise("Announce failed: #{reason}")
        result -> Mix.shell().info("Announced: #{inspect(result)}")
      end
    end
  end
end
