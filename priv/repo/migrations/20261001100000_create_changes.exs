defmodule McpRegistry.Repo.Migrations.CreateChanges do
  @moduledoc """
  What changed about a listing, and when -- the record behind its changelog.

  A row is about exactly one subject: a listing (`server_id`), for its tools,
  prompts, resources and `server.json` fields; or a document URL
  (`document_url`), for an llms.txt or AGENTS.md. Documents are keyed by URL
  rather than by listing because many listings share one: fifty listings under
  `com.cloudflare` point at a single llms.txt, and recording its change fifty
  times would put the same diff on fifty pages. The check constraint holds the
  "exactly one" rule.
  """
  use Ecto.Migration

  def change do
    create table(:changes) do
      add :server_id, references(:servers, on_delete: :delete_all)
      add :document_url, :text
      add :kind, :string, null: false
      add :added, {:array, :text}, default: [], null: false
      add :removed, {:array, :text}, default: [], null: false
      # For server.json: %{"version" => [old, new], ...}.
      add :fields, :map, default: %{}, null: false
      add :source, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:changes, [:server_id, :inserted_at])
    create index(:changes, [:document_url, :inserted_at])
    create index(:changes, [:inserted_at])

    create constraint(:changes, :exactly_one_subject,
             check: "(server_id IS NOT NULL) <> (document_url IS NOT NULL)"
           )
  end
end
