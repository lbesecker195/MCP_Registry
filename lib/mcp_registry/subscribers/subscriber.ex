defmodule McpRegistry.Subscribers.Subscriber do
  @moduledoc """
  One address on the announcement list. No profile, no name, no preferences.

  Addresses are trimmed and folded to lowercase in the changeset, and the
  database enforces uniqueness on `lower(email)`, so the stored form and the
  indexed form cannot drift apart.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Deliberately loose: something, an @, something with a dot, no whitespace.
  # Stricter patterns reject valid addresses; delivery is the real validator.
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  schema "subscribers" do
    field :email, :string
    field :source, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Casts and normalises a subscription. `source` records which form it came from."
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email, :source])
    |> update_change(:email, &normalize/1)
    |> validate_required([:email])
    |> validate_format(:email, @email_format, message: "must look like you@example.com")
    |> validate_length(:email, max: 254)
    |> unique_constraint(:email, name: :subscribers_email_index)
  end

  defp normalize(email) when is_binary(email), do: email |> String.trim() |> String.downcase()
  defp normalize(email), do: email
end
