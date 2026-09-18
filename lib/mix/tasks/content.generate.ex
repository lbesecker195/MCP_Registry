defmodule Mix.Tasks.Content.Generate do
  use Mix.Task
  require Logger

  alias McpRegistry.ContentGenerator
  alias McpRegistry.Registry

  # ContentGenerator.generate_articles_batch/2 isn't implemented yet -- this
  # task is a stub until the actual article-generation call lands.
  @compile {:no_warn_undefined, {ContentGenerator, :generate_articles_batch, 2}}

  @moduledoc """
  Generate technical articles for MCP servers.

  Usage:
    mix content.generate --limit 5          # Generate for 5 servers (PoC)
    mix content.generate --limit 500 --long # Generate 20k+ word articles for 500 servers
    mix content.generate --limit 30000 --short # Generate 500 word articles for 30k servers

  Options:
    --limit N        Number of servers to process (default: 5)
    --long           Generate 20,000+ word articles (default)
    --short          Generate 500 word articles
    --resume SERVER  Resume from a specific server name
  """

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [limit: :integer, long: :boolean, short: :boolean, resume: :string],
        aliases: [l: :limit]
      )

    limit = Keyword.get(opts, :limit, 5)
    word_count = if Keyword.get(opts, :short, false), do: :short, else: :long
    resume_from = Keyword.get(opts, :resume)

    Logger.info("Generating articles for up to #{limit} servers (#{word_count} format)...")

    servers = fetch_servers(limit, resume_from)
    Logger.info("Fetched #{length(servers)} servers from registry")

    {success, failed} = ContentGenerator.generate_articles_batch(servers, word_count)

    Logger.info("✓ Completed: #{success} articles generated, #{failed} failed")

    if failed > 0, do: System.halt(1)
  end

  defp fetch_servers(limit, resume_from) do
    query = Registry.list_servers(status: "active", limit: limit)

    case resume_from do
      nil ->
        query

      resume_name ->
        # Skip until we find the resume point
        Enum.drop_while(query, fn s -> s.name != resume_name end)
        |> Enum.take(limit)
    end
  end
end
