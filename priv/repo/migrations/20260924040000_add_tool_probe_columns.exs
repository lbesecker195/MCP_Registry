defmodule McpRegistry.Repo.Migrations.AddToolProbeColumns do
  @moduledoc """
  Records where a listing's tool list came from, and how the last probe went.

  Without provenance a probe is destructive: a server that is merely
  auth-gated today would overwrite a publisher's declared tools with nothing.
  `tools_source` says who is speaking, and the probe columns let the runner
  skip what it has already asked recently instead of hammering the same
  endpoints on every pass.
  """
  use Ecto.Migration

  def change do
    alter table(:servers) do
      # "declared" (the publisher's server.json) or "probed" (the server itself)
      add :tools_source, :string
      add :probed_at, :utc_datetime_usec
      # ok | unauthorized | unsupported | unreachable | not_remote
      add :probe_status, :string
    end

    # The runner's working query: remote listings, least recently probed first.
    create index(:servers, [:probed_at])
    create index(:servers, [:probe_status])
  end
end
