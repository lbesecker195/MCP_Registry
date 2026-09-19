# `test/render_dump_test.exs` is a design tool, not a test: it writes rendered
# pages to tmp/. Run it on purpose with `mix test --include render_dump`.
ExUnit.start(exclude: [:render_dump])
Ecto.Adapters.SQL.Sandbox.mode(McpRegistry.Repo, :manual)
