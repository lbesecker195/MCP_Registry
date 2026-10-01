defmodule McpRegistry.ChangesTest do
  use McpRegistry.DataCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Changes
  alias McpRegistry.Changes.Change
  alias McpRegistry.Repo

  # After the census, so prompts and resources were genuinely asked for.
  @asked ~U[2026-09-28 12:00:00.000000Z]

  defp probed(attrs) do
    server = server_fixture(Map.drop(attrs, [:probe_status, :probed_at, :tools_source]))

    server
    |> Ecto.Changeset.change(
      Map.merge(
        %{probe_status: "ok", probed_at: @asked, tools_source: "probed"},
        Map.take(attrs, [:probe_status, :probed_at, :tools_source])
      )
    )
    |> Repo.update!()
  end

  defp found(attrs), do: Map.merge(%{tools: [], prompts: [], resources: []}, attrs)

  describe "from a probe" do
    test "tools a server added and dropped are recorded, in its own order" do
      server = probed(%{tools: ~w(a b c)})

      assert [change] = Changes.record_probe(server, found(%{tools: ~w(d a c e)}))
      assert change.kind == "tools"
      assert change.added == ~w(d e)
      assert change.removed == ~w(b)
      assert change.source == "probe"
      assert change.server_id == server.id
    end

    test "the same answer twice records nothing" do
      server = probed(%{tools: ~w(a b), prompts: ~w(p)})
      assert Changes.record_probe(server, found(%{tools: ~w(b a), prompts: ~w(p)})) == []
    end

    test "declared tools giving way to probed ones is our knowledge changing, not the server" do
      server = probed(%{tools: ~w(declared), tools_source: nil})
      assert Changes.record_probe(server, found(%{tools: ~w(real)})) == []
    end

    test "prompts are compared once they were actually being asked for" do
      server = probed(%{prompts: ~w(old)})

      assert [change] = Changes.record_probe(server, found(%{prompts: ~w(old new)}))
      assert change.kind == "prompts"
      assert change.added == ~w(new)
    end

    test "an empty list from before the census meant 'not asked', so it is not compared" do
      server = probed(%{prompts: [], probed_at: ~U[2026-09-01 00:00:00.000000Z]})

      # Otherwise every prompt this server always had would read as new.
      assert Changes.record_probe(server, found(%{prompts: ~w(long_standing)})) == []
    end

    test "a list at the probe's cap is not compared, because its tail is not ours to see" do
      cap = McpRegistry.Probe.max_items()
      full = Enum.map(1..cap, &"r#{&1}")
      server = probed(%{resources: full})

      # One new item at the top pushes the last off our end -- not a removal.
      shifted = ["r0" | Enum.take(full, cap - 1)]
      assert Changes.record_probe(server, found(%{resources: shifted})) == []
    end

    test "a server whose last probe failed is not compared against stale lists" do
      server = probed(%{prompts: ~w(a), probe_status: "unauthorized"})
      assert Changes.record_probe(server, found(%{prompts: ~w(a b)})) == []
    end
  end

  describe "from a sync" do
    test "publisher-visible fields are recorded as old → new" do
      server = server_fixture(%{version: "1.0.0", description: "The original description."})

      changeset =
        McpRegistry.Registry.Server.changeset(server, %{
          version: "1.1.0",
          description: "A better description."
        })

      assert [change] = Changes.record_sync(server, changeset)
      assert change.kind == "server_json"
      assert change.fields["version"] == ["1.0.0", "1.1.0"]

      assert change.fields["description"] == [
               "The original description.",
               "A better description."
             ]
    end

    test "our own bookkeeping is not a change" do
      server = server_fixture()

      changeset =
        server
        |> Ecto.Changeset.change(
          synced_at: DateTime.utc_now(),
          source_updated_at: DateTime.utc_now()
        )

      assert Changes.record_sync(server, changeset) == []
    end
  end

  test "a change belongs to exactly one subject" do
    # The check constraint, not just the code paths: a row about nothing, or
    # about both a listing and a document, cannot be stored.
    assert_raise Postgrex.Error, ~r/exactly_one_subject/, fn ->
      Repo.insert_all(Change, [
        %{kind: "tools", source: "probe", inserted_at: DateTime.utc_now()}
      ])
    end
  end

  test "kind slugs round-trip, and unknown ones are refused" do
    for kind <- Change.kinds() do
      assert kind |> Changes.slug() |> Changes.from_slug() == kind
    end

    assert Changes.slug("server_json") == "server-json"
    assert Changes.from_slug("gptbot") == nil
  end
end
