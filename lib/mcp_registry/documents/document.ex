defmodule McpRegistry.Documents.Document do
  @moduledoc "One fetched llms.txt or AGENTS.md, keyed by URL. See `McpRegistry.Documents`."
  use Ecto.Schema

  schema "documents" do
    field :url, :string
    field :kind, :string
    field :status, :string, default: "pending"
    field :etag, :string
    field :last_modified, :string
    field :sha256, :string
    field :content, :string
    field :last_error, :string
    field :checked_at, :utc_datetime_usec
    field :changed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end
end
