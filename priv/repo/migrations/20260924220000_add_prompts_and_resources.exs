defmodule McpRegistry.Repo.Migrations.AddPromptsAndResources do
  @moduledoc """
  Stores the other two things an MCP server can expose.

  A sample of eight live servers found prompts at zero on every one of them,
  including servers that declare the prompts capability, and resources on two.
  That is a sample, not a census: these columns let the prober answer the same
  question across the whole catalogue, so a skills or resources silo can be
  built on a real count rather than a guess about whether one is worth having.
  """
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :prompts, {:array, :string}, default: [], null: false
      add :resources, {:array, :string}, default: [], null: false
    end
  end
end
