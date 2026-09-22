defmodule McpRegistry.ContentGenerator do
  @moduledoc """
  Saves technical articles for MCP servers to the database.
  Articles are generated externally and passed in as markdown content.
  """
  require Logger
  alias McpRegistry.Registry.Server
  alias McpRegistry.Repo

  @doc """
  Save a pre-generated article for a server.
  Returns {:ok, server} or {:error, reason}.
  """
  def save_article(server_or_name, content) when is_binary(content) do
    server = get_server!(server_or_name)
    Logger.info("Saving #{String.length(content)} chars article for #{server.name}...")
    save_article_to_server(server, content)
  end

  @doc """
  Save multiple articles for servers.
  Expects list of {server_name_or_struct, article_content} tuples.
  Returns {success_count, failed_count}.
  """
  def save_articles_batch(articles_list) do
    Logger.info("Saving #{length(articles_list)} articles to database...")

    {success, failed} =
      Enum.reduce(articles_list, {0, 0}, fn {server_or_name, content}, {ok, err} ->
        case save_article(server_or_name, content) do
          {:ok, _} ->
            {ok + 1, err}

          {:error, reason} ->
            Logger.warning("Failed to save article: #{reason}")
            {ok, err + 1}
        end
      end)

    Logger.info("✓ Saved: #{success} successful, #{failed} failed")
    {success, failed}
  end

  defp save_article_to_server(server, content) do
    server
    |> Ecto.Changeset.change(%{
      article_content: content,
      article_generated_at: DateTime.utc_now()
    })
    |> Repo.update()
    |> tap(fn
      # The article is most of the page, so search engines should read it again.
      {:ok, %Server{status: "active", name: name}} -> McpRegistry.Discovery.announce_later([name])
      _ -> :ok
    end)
  end

  defp get_server!(name) when is_binary(name) do
    case Repo.get_by(Server, name: String.downcase(name)) do
      nil -> raise "Server not found: #{name}"
      server -> server
    end
  end

  defp get_server!(server = %Server{}), do: server
end
