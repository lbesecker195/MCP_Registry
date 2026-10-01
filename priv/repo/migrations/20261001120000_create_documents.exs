defmodule McpRegistry.Repo.Migrations.CreateDocuments do
  @moduledoc """
  The machine-readable files a listing points at -- its site's llms.txt and its
  repository's AGENTS.md -- fetched on a schedule so their changes can be
  recorded.

  `documents` holds one row per URL, because many listings share one: fifty
  listings under one company point at a single llms.txt, and fetching or
  recording it fifty times would be wasteful for us and rude to them.
  `server_documents` says which listing points at which URL, and is rebuilt by
  discovery as listings change.

  Content is kept only to diff the next version against, capped at 256 KB.
  """
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :url, :text, null: false
      add :kind, :string, null: false
      # pending: never checked. ok: present. missing: confirmed absent.
      add :status, :string, null: false, default: "pending"
      add :etag, :text
      add :last_modified, :text
      add :sha256, :string
      add :content, :text
      add :last_error, :text
      add :checked_at, :utc_datetime_usec
      add :changed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:documents, [:url])
    create index(:documents, [:checked_at])

    create table(:server_documents, primary_key: false) do
      add :server_id, references(:servers, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :url, :text, null: false
    end

    create unique_index(:server_documents, [:server_id, :kind])
    create index(:server_documents, [:url])
  end
end
