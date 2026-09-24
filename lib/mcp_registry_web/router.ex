defmodule McpRegistryWeb.Router do
  use McpRegistryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {McpRegistryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpRegistryWeb.Plugs.APIAnalytics
  end

  # Turns a request for a listing that does not exist into a 301 home, before
  # the LiveView can raise. See `McpRegistryWeb.Plugs.KnownServer` for why this
  # cannot live in the LiveView itself.
  pipeline :known_server do
    plug McpRegistryWeb.Plugs.KnownServer
  end

  scope "/", McpRegistryWeb do
    pipe_through :browser

    live "/", ServerLive.Home, :home
    # The exact path has to come before the glob, or `/servers` is matched by
    # `*name` with an empty segment and never reaches the catalogue.
    live "/servers", ServerLive.Index, :index
    live "/submit", ServerLive.New, :new
    live "/book", BookLive, :show
    get "/llms.txt", LlmsController, :show
  end

  scope "/", McpRegistryWeb do
    pipe_through [:browser, :known_server]

    # Before the glob: `*name` would otherwise swallow /tools and everything
    # under it as though it were part of the listing's name.
    live "/servers/:namespace/:name/tools", ServerLive.Tools, :index
    live "/servers/:namespace/:name/tools/:tool", ServerLive.Tools, :show
    live "/servers/:namespace/:name/tools/:tool/:client", ServerLive.Tools, :client

    live "/servers/*name", ServerLive.Show, :show
  end

  # The registry as an MCP server (Streamable HTTP): search, get and submit tools.
  scope "/", McpRegistryWeb do
    post "/mcp", MCPController, :post
    get "/mcp", MCPController, :method_not_allowed
    delete "/mcp", MCPController, :method_not_allowed
  end

  # What crawlers read to find listings: robots.txt, the sitemap and the feed
  # the WebSub hubs fetch. No browser pipeline, so no session cookie, and they
  # stay cacheable. The IndexNow key file is served by a plug in the endpoint.
  scope "/", McpRegistryWeb do
    get "/robots.txt", SitemapController, :robots
    get "/sitemap.xml", SitemapController, :index
    get "/sitemaps/:file", SitemapController, :show
    get "/feed.xml", FeedController, :show
  end

  # JSON API, shaped after the official MCP registry's /v0 endpoints.
  scope "/api/v0", McpRegistryWeb.API, as: :api do
    pipe_through :api

    get "/servers", ServerController, :index
    post "/servers", ServerController, :create
    post "/review", ServerController, :review
    post "/articles/*name", ServerController, :save_article
    get "/servers/*name", ServerController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:mcp_registry, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: McpRegistryWeb.Telemetry
    end
  end

  # --- Catch-alls, last: every route above wins over these. -------------------

  # The API answers a miss honestly; a client following a 301 into HTML would
  # just fail to parse it.
  scope "/api", McpRegistryWeb do
    pipe_through :api

    match :*, "/*path", RedirectController, :api_not_found
  end

  # Anything else a browser asks for goes home, permanently, instead of 404ing.
  # Deliberately GET-only: a stray POST is not a mistyped URL, and redirecting
  # it would silently drop the body.
  scope "/", McpRegistryWeb do
    get "/*path", RedirectController, :home
  end
end
