ExUnit tests for the `McpRegistry` context, the code behind server storage, search, and the official-registry mirror.

- `registry_test.exs` exercises `Registry.create_server/2` and `Registry.list_servers/1`: name normalization and duplicate rejection, requiring a package for stdio transports or a URL for remote ones, searching by name/description/tags/tools, hiding pending listings, and ordering curated entries before recently-updated imports.
- `official_registry_test.exs` exercises `OfficialRegistry`'s sync against the upstream registry API: paginated fetch/cursor handling and mapping upstream entries into local `Server` records.
- `discovery_test.exs` exercises `Discovery` against stubbed IndexNow and WebSub endpoints. It checks the request bodies, the per-run cap, that a 429 is reported and never retried, and that it is a no-op when disabled. It also checks the end-to-end paths: a sync announcing what it inserted, an approval going out through the `Batcher`, and the `announce_all` backfill. It is the one non-async module here, because it turns pushing on in the application environment.
- `rate_limiter_test.exs` exercises `RateLimiter.hit/3`'s per-key request budget and its retry-after response once the limit is hit.

These tests guard the logic that drives search, listings, and submission on the live site, and the background job that mirrors servers from the official MCP Registry. But this directory itself is test code only: it runs under `mix test` in CI and locally, and is never executed in or deployed to production, so it has no direct effect on the live site.
