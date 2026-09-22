This directory holds the app's non-LiveView HTTP entry points: plain-text, JSON-RPC, and REST, as opposed to the LiveView modules that render the browsable pages.

`llms_controller.ex` renders [llms.txt](https://ai.mcpharbor.dev/llms.txt), the plain-text index that tells AI agents how to search, install, and publish MCP servers here.

`mcp_controller.ex` implements the registry's own [Streamable HTTP endpoint](https://ai.mcpharbor.dev/mcp), the JSON-RPC surface behind the `search_servers`, `get_server`, and `submit_server` tools agents call directly.

`api/server_controller.ex`, `api/fallback_controller.ex`, and `api/server_json.ex` implement the [JSON API at /api/v0](https://ai.mcpharbor.dev/api/v0/servers), letting scripts list, fetch, and submit listings much like a person does through [the server submission form](https://ai.mcpharbor.dev/submit), plus maintainer approve/reject review.

`error_html.ex` and `error_json.ex` are Phoenix's generic 404/500 renderers, invoked sitewide whenever any page or endpoint request fails; they hold no page-specific content of their own.

`sitemap_controller.ex` serves `robots.txt` and [the sitemap index](https://ai.mcpharbor.dev/sitemap.xml). The index points at a file of the pages that are not listings, and at one file per 10,000 active listings, each with its `lastmod`. `feed_controller.ex` serves [the newest MCP servers as an Atom feed](https://ai.mcpharbor.dev/feed.xml). The feed declares the WebSub hub that `McpRegistry.Discovery` pings, which is how Google's Feedfetcher hears about new listings. Neither controller uses the browser pipeline, so they set no cookie and their responses stay cacheable.
