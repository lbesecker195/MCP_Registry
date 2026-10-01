defmodule McpRegistry.Repo.Migrations.AddIconUrl do
  @moduledoc """
  The icon a publisher declares for their server in `server.json`.

  One URL rather than the whole `icons` array: the page shows one logo, and
  `McpRegistry.Registry.Manifest` picks it at sync time so the choice is made
  once rather than on every render. Text, not varchar(255) -- icon URLs are
  publisher-controlled and the census already found that 255 is not enough
  for what publishers put in a URL.
  """
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :icon_url, :text
    end
  end
end
