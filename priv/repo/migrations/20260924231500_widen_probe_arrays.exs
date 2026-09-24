defmodule McpRegistry.Repo.Migrations.WidenProbeArrays do
  @moduledoc """
  `{:array, :string}` becomes `varchar(255)[]`, which is too narrow for a
  resource: resources are identified by URI, and URIs go past 255 characters
  routinely. The first census pass hit it within seconds.

  The length was not the whole cost. The write raised `Postgrex.Error` out of
  the `Task.async_stream` in the probe runner, which killed the batch around
  it, so one long URI cost the other 399 probes in its batch. The runner is
  being made resilient to that separately; this removes the cause.

  Tools move too. Tool names are short by convention and have not hit the
  limit, but they are written by the same call in the same batch, so the same
  failure was one unusual publisher away.

  `tags` and `env_vars` stay as they are: those come from user input, where a
  length limit is a constraint worth keeping rather than an accident.
  """
  use Ecto.Migration

  def up do
    alter table(:servers) do
      modify :tools, {:array, :text}
      modify :prompts, {:array, :text}
      modify :resources, {:array, :text}
    end
  end

  def down do
    alter table(:servers) do
      modify :tools, {:array, :string}
      modify :prompts, {:array, :string}
      modify :resources, {:array, :string}
    end
  end
end
