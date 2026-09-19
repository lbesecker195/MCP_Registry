defmodule McpRegistry.Subscribers do
  @moduledoc """
  The announcement list: one email address per person.

  Subscribing twice is not a mistake worth reporting. `create_subscriber/1`
  answers `{:ok, :already_subscribed}` when the address is on the list already,
  so a returning visitor is never told their own email "has already been
  taken" -- which would also confirm, to anyone who asks, who is subscribed.
  """
  alias McpRegistry.Analytics
  alias McpRegistry.Repo
  alias McpRegistry.Subscribers.Subscriber

  @doc "A changeset for the subscribe form."
  def change_subscriber(%Subscriber{} = subscriber \\ %Subscriber{}, attrs \\ %{}),
    do: Subscriber.changeset(subscriber, attrs)

  @doc """
  Adds an address to the list.

  Returns `{:ok, %Subscriber{}}` on a new subscription, `{:ok, :already_subscribed}`
  when the address is already on it, and `{:error, changeset}` only when the
  address itself is unusable.
  """
  def create_subscriber(attrs) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, subscriber} ->
        # Coarse counts only -- the address never leaves this process.
        Analytics.track(:subscribed, %{source: subscriber.source})
        {:ok, subscriber}

      {:error, changeset} ->
        if taken?(changeset), do: {:ok, :already_subscribed}, else: {:error, changeset}
    end
  end

  defp taken?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:email, {_message, opts}} -> opts[:constraint] == :unique
      _ -> false
    end)
  end
end
