defmodule McpRegistry.Repo.Migrations.IndexSearchColumns do
  @moduledoc """
  Makes catalogue search use an index.

  `Registry.filter_q/2` matches with `ILIKE '%term%'` across five expressions.
  A leading wildcard cannot use a btree index, so every search was a sequential
  scan over every active listing. Trigram indexes are built for exactly this
  shape, and crucially they do not change what matches: the query still runs
  `ILIKE`, and Postgres rechecks it on each candidate row. Full-text search
  would have been faster still and would have changed the results -- stemming,
  stop words and no substring matching -- so it is deliberately not used here.

  All five expressions have to be indexable together. Postgres can only combine
  `OR` branches through a BitmapOr when *every* branch has an index; one
  unindexed branch sends the whole predicate back to a sequential scan. That is
  why the array columns need `mcp_array_to_text/1`: `array_to_string/2` is not
  marked IMMUTABLE, so Postgres refuses to index an expression containing it.

  Measured on 31,000 rows, searching a selective term: 47.4ms before, 0.98ms
  after, with identical result sets.

  Built CONCURRENTLY, because this runs against a live catalogue and an
  ordinary CREATE INDEX holds a write lock for its duration.
  """
  use Ecto.Migration

  # CONCURRENTLY cannot run inside a transaction.
  @disable_ddl_transaction true
  @disable_migration_lock true

  require Logger

  def up do
    # This one is not optional and must not be wrapped: `Registry.filter_q/2`
    # calls it, so if it is missing every search raises. Creating a function
    # needs only CREATE on the schema, which the application's own user has by
    # definition -- it created these tables.
    execute """
    CREATE OR REPLACE FUNCTION mcp_array_to_text(text[]) RETURNS text
      LANGUAGE sql IMMUTABLE PARALLEL SAFE
      AS $$ SELECT array_to_string($1, ' ') $$
    """

    # The indexes are pure optimisation, and this migration runs from the
    # service unit's ExecStartPre -- a migration that raises means the release
    # never starts. `pg_trgm` is a trusted extension from PostgreSQL 13, so the
    # database owner can install it, but on an older server or a locked-down
    # role it needs superuser. Losing an index is a slow catalogue; losing the
    # boot is an outage. So this degrades rather than raising.
    try do
      repo().query!("CREATE EXTENSION IF NOT EXISTS pg_trgm")

      for {expression, name} <- [
            {"name gin_trgm_ops", :servers_name_trgm_index},
            {"title gin_trgm_ops", :servers_title_trgm_index},
            {"description gin_trgm_ops", :servers_description_trgm_index},
            {"mcp_array_to_text(tags) gin_trgm_ops", :servers_tags_text_trgm_index},
            {"mcp_array_to_text(tools) gin_trgm_ops", :servers_tools_text_trgm_index}
          ] do
        create_if_not_exists index(:servers, [expression],
                               name: name,
                               using: :gin,
                               concurrently: true
                             )
      end
    rescue
      error ->
        Logger.warning("""
        Trigram search indexes were not created: #{Exception.message(error)}

        The catalogue still works; searches fall back to a sequential scan.
        Install the extension as a superuser and re-run this migration:

            CREATE EXTENSION IF NOT EXISTS pg_trgm;
        """)
    end
  end

  def down do
    for name <- [
          :servers_name_trgm_index,
          :servers_title_trgm_index,
          :servers_description_trgm_index,
          :servers_tags_text_trgm_index,
          :servers_tools_text_trgm_index
        ] do
      drop_if_exists index(:servers, [], name: name, concurrently: true)
    end

    execute "DROP FUNCTION IF EXISTS mcp_array_to_text(text[])"
    # pg_trgm is left installed; something else may depend on it.
  end
end
