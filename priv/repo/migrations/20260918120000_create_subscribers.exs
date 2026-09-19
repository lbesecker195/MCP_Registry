defmodule McpRegistry.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers) do
      add :email, :string, null: false
      add :source, :string

      timestamps(type: :utc_datetime)
    end

    # Uniqueness is on the folded address, so Ada@Example.com and
    # ada@example.com cannot both sit on the list.
    create unique_index(:subscribers, ["lower(email)"], name: :subscribers_email_index)
  end
end
