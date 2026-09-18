defmodule McpRegistry.Repo.Migrations.AddArticleContentToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :article_content, :text, null: true
      add :article_generated_at, :utc_datetime_usec, null: true
    end

    create index(:servers, [:article_generated_at])
  end
end
