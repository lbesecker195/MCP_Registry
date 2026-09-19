defmodule McpRegistryWeb.ServerLive.Home do
  @moduledoc """
  The landing page.

  `/` used to be the catalogue and still collects deep links from search
  results and shared URLs, so `handle_params/3` forwards any catalogue filter
  it is handed on to `/servers` rather than swallowing it.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server
  alias McpRegistry.Subscribers

  # Query params that used to belong to this route. Anything here means the
  # visitor wanted the catalogue, not the landing page.
  @catalogue_params ~w(q tag transport page)

  @impl true
  def mount(_params, _session, socket) do
    stats = Registry.stats()

    {:ok,
     socket
     |> assign(:page_title, "MCP Registry — find and connect MCP servers")
     # The home page title is already the site name; the usual suffix would
     # repeat it.
     |> assign(:title_suffix, "")
     |> assign(:meta_description, meta_description(stats))
     |> assign(:canonical_url, McpRegistryWeb.Endpoint.url() <> "/")
     |> assign(:mcp_url, McpRegistryWeb.Endpoint.url() <> "/mcp")
     |> assign(:stats, stats)
     |> assign(:tags, Registry.top_tags(12))
     |> assign(:featured, Registry.list_servers(limit: 6))
     |> assign(:subscribed?, false)
     |> assign(:form, to_form(Subscribers.change_subscriber()))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params |> Map.take(@catalogue_params) |> Enum.sort() do
      [] -> {:noreply, socket}
      filters -> {:noreply, push_navigate(socket, to: ~p"/servers?#{filters}")}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    case String.trim(q) do
      "" -> {:noreply, push_navigate(socket, to: ~p"/servers")}
      q -> {:noreply, push_navigate(socket, to: ~p"/servers?q=#{q}")}
    end
  end

  def handle_event("subscribe", %{"subscriber" => params}, socket) do
    case Subscribers.create_subscriber(Map.put(params, "source", "home")) do
      {:ok, _subscriber} ->
        {:noreply, assign(socket, :subscribed?, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:home} wide={true}>
      <section class="relative isolate -mx-4 overflow-hidden px-4 pt-4 pb-12 sm:-mx-6 sm:px-6 sm:pt-8 sm:pb-16">
        <div aria-hidden="true" class="pointer-events-none absolute inset-0 -z-10">
          <div class="absolute -top-40 left-1/2 h-80 w-[48rem] max-w-[160%] -translate-x-1/2 rounded-full bg-glow blur-3xl">
          </div>
          <div class="absolute top-32 -right-20 h-64 w-80 rounded-full bg-beam blur-3xl"></div>
        </div>

        <p class="rise inline-flex items-center gap-2 rounded-full border border-rule bg-surface/70 px-3 py-1 font-mono text-[11px] tracking-wide text-dim uppercase backdrop-blur-sm">
          <span class="text-brand">directory</span>
          <span class="text-rule-strong" aria-hidden="true">/</span>
          <span>json api</span>
          <span class="text-rule-strong" aria-hidden="true">/</span>
          <span>mcp endpoint</span>
        </p>

        <h1
          class="rise mt-5 max-w-3xl text-4xl font-semibold tracking-tight text-balance sm:text-6xl"
          style="--d: 60ms"
        >
          MCP Registry
        </h1>

        <p class="rise mt-4 max-w-2xl text-lg text-pretty text-dim sm:text-xl" style="--d: 120ms">
          MCP Harbor, an MCP Server Registry, Directory, and Tower to Buzz.
        </p>

        <p class="rise mt-4 max-w-2xl text-sm text-pretty text-dim" style="--d: 180ms">
          Search every listing by name, tag, transport or the exact tool you need. The official
          MCP Registry is mirrored in and kept in sync; anything submitted here lands alongside it.
        </p>

        <div class="rise mt-8 flex flex-wrap items-center gap-3" style="--d: 240ms">
          <.button variant="primary" navigate={~p"/servers"}>
            Browse {format_number(@stats.servers)} servers
            <.icon name="hero-arrow-right-micro" class="size-4" />
          </.button>
          <.button variant="soft" href="#mcp-endpoint">
            <.icon name="hero-cpu-chip" class="size-4" /> Connect your agent
          </.button>
        </div>
      </section>

      <section aria-labelledby="search-heading" class="rise" style="--d: 300ms">
        <h2 id="search-heading" class="sr-only">Search the registry</h2>

        <form phx-submit="search" class="flex flex-col gap-2 sm:flex-row">
          <div class="flex min-w-0 flex-1 items-center gap-3 rounded-box border border-rule bg-surface px-4 py-3 transition-colors hover:border-rule-strong focus-within:border-brand focus-within:ring-2 focus-within:ring-brand/20">
            <.icon name="hero-magnifying-glass" class="size-5 shrink-0 text-dim" />
            <label for="home-search" class="sr-only">Search MCP servers</label>
            <input
              id="home-search"
              type="search"
              name="q"
              autocomplete="off"
              placeholder="postgres, github, weather, browser…"
              class="w-full min-w-0 bg-transparent font-mono text-sm text-ink outline-none placeholder:text-dim focus:outline-none"
            />
          </div>
          <.button variant="primary" type="submit" class="sm:px-7">Search</.button>
        </form>

        <p class="mt-2 font-mono text-[11px] text-dim">
          Searches names, descriptions, tags and tool names across every active listing.
        </p>
      </section>

      <section aria-labelledby="stats-heading" class="rise pt-2" style="--d: 340ms">
        <h2 id="stats-heading" class="sr-only">The registry at a glance</h2>

        <dl class="grid grid-cols-2 gap-px overflow-hidden rounded-box border border-rule bg-rule sm:grid-cols-4">
          <.stat label="servers" value={@stats.servers} />
          <.stat label="tools" value={@stats.tools} />
          <.stat label="hosted remotely" value={@stats.remote} />
          <.stat label="only on harbor" value={@stats.unique} />
        </dl>
      </section>

      <section
        id="mcp-endpoint"
        aria-labelledby="mcp-heading"
        class="rise scroll-mt-20 pt-6"
        style="--d: 380ms"
      >
        <div class="rounded-box border border-rule bg-surface/60 p-5 sm:p-7">
          <div class="flex items-center gap-2.5">
            <span class="relative flex size-2" aria-hidden="true">
              <span class="absolute inline-flex size-full animate-ping rounded-full bg-accent opacity-75"></span>
              <span class="relative inline-flex size-2 rounded-full bg-accent"></span>
            </span>
            <h2
              id="mcp-heading"
              class="font-mono text-xs font-medium tracking-wide text-balance uppercase"
            >
              This registry is itself an MCP server
            </h2>
          </div>

          <p class="mt-3 max-w-2xl text-sm text-pretty text-dim">
            Point a client at the endpoint below and your agent searches the catalogue, reads a
            listing and submits a new server on its own — no account, no key. The tool schemas and
            the submission contract are written out for agents in <.link
              href={~p"/llms.txt"}
              class="text-ink underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
            >
              /llms.txt
            </.link>.
          </p>

          <.copy_command
            id="home-mcp-install"
            class="mt-4"
            label="add it to claude code"
            command={"claude mcp add --transport http mcp-harbor #{@mcp_url}"}
          />
        </div>
      </section>

      <section :if={@featured != []} aria-labelledby="featured-heading" class="space-y-5 pt-8">
        <div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-2">
          <div class="space-y-1.5">
            <p class="font-mono text-[11px] tracking-wide text-dim uppercase">
              most recently updated
            </p>
            <h2
              id="featured-heading"
              class="text-xl font-semibold tracking-tight text-balance sm:text-2xl"
            >
              Servers to start with
            </h2>
          </div>
          <.link
            navigate={~p"/servers"}
            class="group flex items-center gap-1.5 rounded-field px-1 py-1 font-mono text-xs text-dim transition-colors hover:text-ink"
          >
            all {format_number(@stats.servers)}
            <.icon
              name="hero-arrow-right-micro"
              class="size-3.5 transition-transform duration-200 group-hover:translate-x-0.5"
            />
          </.link>
        </div>

        <ul class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={server <- @featured}>
            <.link
              navigate={server_path(server)}
              class="group flex h-full flex-col gap-2 rounded-box border border-rule bg-surface/50 p-4 transition-all duration-200 hover:-translate-y-0.5 hover:border-rule-strong hover:bg-surface hover:shadow-md"
            >
              <div class="flex items-start gap-3">
                <.monogram name={server.name} size="size-8 text-[11px]" />

                <div class="min-w-0 flex-1 space-y-1">
                  <div class="flex items-start justify-between gap-3">
                    <h3 class="font-medium tracking-tight text-balance transition-colors group-hover:text-brand">
                      {server.title}
                    </h3>
                    <span class={[
                      "shrink-0 rounded-full border px-2 py-0.5 font-mono text-[10px]",
                      Layouts.transport_tone(server.transport)
                    ]}>
                      {server.transport}
                    </span>
                  </div>

                  <p class="font-mono text-[11px] break-all text-dim">
                    {Server.namespace(server)}{Server.short_name(server)}
                  </p>
                </div>
              </div>

              <p class="line-clamp-3 text-sm text-pretty text-dim">{server.description}</p>

              <div class="mt-auto flex flex-wrap items-center gap-x-3 gap-y-1 pt-1 font-mono text-[11px] text-dim">
                <span :if={server.tools != []}>{length(server.tools)} tools</span>
                <span :for={tag <- Enum.take(server.tags, 2)}>#{tag}</span>
              </div>
            </.link>
          </li>
        </ul>
      </section>

      <section aria-labelledby="how-heading" class="space-y-5 pt-8">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">how it works</p>
          <h2 id="how-heading" class="text-xl font-semibold tracking-tight text-balance sm:text-2xl">
            From search to tool call
          </h2>
        </div>

        <ol class="grid gap-px overflow-hidden rounded-box border border-rule bg-rule sm:grid-cols-3">
          <.step index="01" label="find" icon="hero-magnifying-glass">
            Filter by tag, transport or tool name. Every listing shows what it exposes and what it
            needs before you install anything.
          </.step>
          <.step index="02" label="install" icon="hero-command-line">
            Each page carries the package identifier or remote URL, the environment variables the
            server expects, and a command you can copy.
          </.step>
          <.step index="03" label="call" icon="hero-bolt">
            Your client discovers the tools on connect. Or skip the browser entirely and let your
            agent query this registry through its MCP endpoint.
          </.step>
        </ol>
      </section>

      <section :if={@tags != []} aria-labelledby="tags-heading" class="space-y-4 pt-8">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">by category</p>
          <h2 id="tags-heading" class="text-xl font-semibold tracking-tight text-balance sm:text-2xl">
            Browse by tag
          </h2>
        </div>

        <ul class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0">
          <li :for={{tag, count} <- @tags} class="shrink-0">
            <.link
              navigate={~p"/servers?tag=#{tag}"}
              class="flex items-center gap-2 rounded-full border border-rule bg-surface/50 px-3 py-1.5 font-mono text-xs text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
            >
              {tag} <span class="tabular-nums opacity-60">{count}</span>
            </.link>
          </li>
        </ul>
      </section>

      <section aria-labelledby="subscribe-heading" class="pt-8">
        <div class="rounded-box border border-rule bg-surface/60 p-5 sm:p-7">
          <div class="flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
            <div class="max-w-md space-y-2">
              <p class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase">
                <.icon name="hero-envelope" class="size-3.5 text-brand" /> the short list
              </p>
              <h2
                id="subscribe-heading"
                class="text-xl font-semibold tracking-tight text-balance sm:text-2xl"
              >
                New and notable MCP servers
              </h2>
              <p class="text-sm text-pretty text-dim">
                One email when enough has landed to be worth reading — roughly monthly, sometimes
                less. New listings and notable updates, nothing else. Your address is not shared,
                and every email carries an unsubscribe link.
              </p>
            </div>

            <div class="w-full sm:max-w-xs">
              <p
                :if={@subscribed?}
                role="status"
                class="rise flex items-center gap-2 rounded-field border border-success/40 bg-canvas px-3 py-2.5 text-sm"
              >
                <.icon name="hero-check-circle" class="size-4 shrink-0 text-success" />
                You're on the list.
              </p>

              <.form
                :if={!@subscribed?}
                for={@form}
                id="subscribe-form"
                phx-submit="subscribe"
                class="flex flex-col gap-2 sm:flex-row sm:items-start"
              >
                <div class="min-w-0 flex-1">
                  <.input
                    field={@form[:email]}
                    type="email"
                    placeholder="you@example.com"
                    autocomplete="email"
                    aria-label="Email address"
                    required
                  />
                </div>
                <.button variant="primary" type="submit" phx-disable-with="Adding…">
                  Subscribe
                </.button>
              </.form>
            </div>
          </div>
        </div>
      </section>

      <section aria-labelledby="cta-heading" class="pt-8">
        <div class="flex flex-col items-start gap-5 rounded-box border border-rule bg-sunken/70 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-7">
          <div class="space-y-1.5">
            <h2 id="cta-heading" class="text-lg font-semibold tracking-tight text-balance">
              Start browsing, or add what is missing
            </h2>
            <p class="max-w-md text-sm text-pretty text-dim">
              Listings are free and stay free. Submissions go live after a quick review, and agents
              can submit through the API without a browser.
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.button variant="primary" navigate={~p"/servers"}>Browse the catalogue</.button>
            <.button variant="soft" navigate={~p"/submit"}>Submit a server</.button>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # One figure in the stats band. `flex-col-reverse` keeps the number on top
  # while the markup stays a well-formed dt/dd pair.
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp stat(assigns) do
    ~H"""
    <div class="flex flex-col-reverse gap-1 bg-canvas px-4 py-5">
      <dt class="font-mono text-[11px] tracking-wide text-dim uppercase">{@label}</dt>
      <dd class="text-2xl font-semibold tracking-tight tabular-nums sm:text-3xl">
        {format_number(@value)}
      </dd>
    </div>
    """
  end

  attr :index, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <li class="space-y-2.5 bg-canvas p-5">
      <div class="flex items-center gap-2">
        <.icon name={@icon} class="size-4 text-brand" />
        <span class="font-mono text-[11px] tracking-wide text-dim uppercase">
          {@index} · {@label}
        </span>
      </div>
      <p class="text-sm text-pretty text-dim">{render_slot(@inner_block)}</p>
    </li>
    """
  end

  defp meta_description(stats) do
    "Search #{format_number(stats.servers)} Model Context Protocol servers by tag, transport or " <>
      "tool name. Copy the install command, or connect your agent to the registry's own MCP endpoint."
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
