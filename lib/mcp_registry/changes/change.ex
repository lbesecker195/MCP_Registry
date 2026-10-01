defmodule McpRegistry.Changes.Change do
  @moduledoc """
  One recorded change: items added and removed from a list, or fields that
  moved from one value to another. See `McpRegistry.Changes` for what is
  recorded and, as importantly, what is not.
  """
  use Ecto.Schema

  @kinds ~w(tools prompts resources server_json llms_txt agents_md)

  schema "changes" do
    belongs_to :server, McpRegistry.Registry.Server
    field :document_url, :string
    field :kind, :string
    field :added, {:array, :string}, default: []
    field :removed, {:array, :string}, default: []
    field :fields, :map, default: %{}
    field :source, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def kinds, do: @kinds
end
