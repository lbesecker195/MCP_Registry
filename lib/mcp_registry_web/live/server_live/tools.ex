defmodule McpRegistryWeb.ServerLive.Tools do
  @moduledoc """
  The tools silo under a listing: an index, a page per tool, and a page per
  tool per client.

  Three actions share one module because they share one lookup and one set of
  breadcrumbs.

    * `:index`  — `/servers/:namespace/:name/tools`
    * `:show`   — `/servers/:namespace/:name/tools/:tool`
    * `:client` — `/servers/:namespace/:name/tools/:tool/:client`

  ## Why these pages exist and the rest of the silo does not

  The registry holds 34,000 listings but only about 130 tool names, because the
  official registry's `server.json` carries no tool list. So this silo is small
  by nature, and that is the point: a page is generated only where there is
  something real to say. A `/skills` page would have no data behind it at all,
  and an `llms.txt` page would be an empty template on every listing — both
  would be thin pages at catalogue scale, which is the doorway pattern search
  engines penalise.

  The client pages are limited to the clients `McpRegistry.Registry.Clients`
  can produce a working configuration for. Crawlers such as GPTBot or BingBot
  do not call MCP tools, so a "how to" page addressed to them would be fiction.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Clients, Server, Tool}

  @impl true
  def mount(%{"namespace" => namespace, "name" => name}, _session, socket) do
    server = Registry.get_server!(namespace <> "/" <> name)

    {:ok,
     socket
     |> assign(:server, server)
     |> assign(:short_name, Server.short_name(server))
     |> assign(:namespace, namespace)
     |> assign(:clients, Clients.configs(server))
     |> assign(:tools, server.tools)
     |> assign(:noindex, server.status != "active")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # An index with nothing on it is not worth a URL; send it to the listing.
  defp apply_action(socket, :index, _params) do
    if socket.assigns.tools == [] do
      push_navigate(socket, to: server_path(socket.assigns.server))
    else
      server = socket.assigns.server
      title = "#{server.title} MCP Tools"

      socket
      |> assign(:page_title, title)
      |> assign(:heading, title)
      |> assign(
        :meta_description,
        "Every tool exposed by the #{server.title} MCP server: #{tool_sentence(socket.assigns.tools)}. " <>
          "Install it in Claude Code, Claude Desktop, Cursor, VS Code, Zed or Windsurf."
      )
      |> assign(:canonical_url, absolute(tools_path(server)))
    end
  end

  defp apply_action(socket, :show, %{"tool" => slug}) do
    server = socket.assigns.server

    case Tool.find(socket.assigns.tools, slug) do
      nil ->
        push_navigate(socket, to: server_path(server))

      tool ->
        title = "#{tool} — #{server.title} MCP Tool"

        socket
        |> assign(:tool, tool)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(
          :meta_description,
          "#{tool} is a tool on the #{server.title} MCP server (#{Tool.gloss(tool)}). " <>
            "How to connect the server and call #{tool} from Claude Code, Cursor, VS Code, Zed or Windsurf."
        )
        |> assign(:canonical_url, absolute(tool_path(server, tool)))
    end
  end

  defp apply_action(socket, :client, %{"tool" => slug, "client" => client_id}) do
    server = socket.assigns.server
    tool = Tool.find(socket.assigns.tools, slug)
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))

    cond do
      is_nil(tool) ->
        push_navigate(socket, to: server_path(server))

      is_nil(client) ->
        push_navigate(socket, to: tool_path(server, tool))

      true ->
        # Title and H1 name the client first: this page exists to answer
        # "<client> <server> <tool>", which is how the question gets typed.
        title = "#{client.label} #{server.title} #{tool}"

        socket
        |> assign(:tool, tool)
        |> assign(:client, client)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(
          :meta_description,
          "How to use the #{tool} tool from the #{server.title} MCP server in #{client.label}: " <>
            "where the configuration lives, what to paste, and what to check when it does not connect."
        )
        |> assign(:canonical_url, absolute(client_path(server, tool, client.id)))
    end
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail><.crumbs server={@server} namespace={@namespace} short_name={@short_name} /></:rail>

      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">{@heading}</h1>
        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
          {@server.title} exposes {tool_count(length(@tools))}. Each one has its own page with the
          configuration for every client that can run this server.
        </p>
      </header>

      <ul class="grid gap-2.5 sm:grid-cols-2">
        <li :for={tool <- @tools}>
          <.link
            navigate={tool_path(@server, tool)}
            class="group flex h-full flex-col gap-1.5 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-rule-strong hover:bg-surface"
          >
            <div class="flex items-start justify-between gap-2">
              <code class="min-w-0 font-mono text-xs font-semibold break-all text-brand">
                {tool}
              </code>
              <.kind_badge tool={tool} />
            </div>
            <p class="text-[11px] text-dim">{Tool.gloss(tool)}</p>
          </.link>
        </li>
      </ul>

      <.derivation_note server={@server} />
      <.back_to_server server={@server} />
    </Layouts.app>
    """
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail>
        <.crumbs server={@server} namespace={@namespace} short_name={@short_name} tool={@tool} />
      </:rail>

      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="flex flex-wrap items-center gap-x-3 gap-y-2 text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
          {@heading} <.kind_badge tool={@tool} />
        </h1>
        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
          <code class="font-mono text-ink">{@tool}</code>
          ({Tool.gloss(@tool)}) is one of {tool_count(length(@tools))} on the
          <.link navigate={server_path(@server)} class={link_class()}>{@server.title}</.link>
          MCP server. Connect the server and your client discovers it on the handshake.
        </p>
      </header>

      <section :if={@clients != []} aria-labelledby="clients-heading" class="space-y-4">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">by client</p>
          <h2 id="clients-heading" class="text-xl font-semibold tracking-tight text-balance">
            How to call {@tool} from your client
          </h2>
        </div>

        <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={client <- @clients}>
            <.link
              navigate={client_path(@server, @tool, client.id)}
              class="group flex h-full flex-col gap-1 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-brand/40 hover:bg-surface"
            >
              <span class="text-sm font-medium transition-colors group-hover:text-brand">
                {client.label} {@server.title} {@tool}
              </span>
              <span class="font-mono text-[11px] text-dim">{client.path}</span>
            </.link>
          </li>
        </ul>
      </section>

      <section :if={@clients != []} aria-labelledby="quick-heading" class="space-y-3">
        <h2 id="quick-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
          Fastest route
        </h2>
        <.code_block
          id="tool-quick-install"
          code={List.first(@clients).code}
          copy_label={if List.first(@clients).kind == :cli, do: "Copy command", else: "Copy config"}
          max_height="max-h-80"
        />
      </section>

      <.sibling_tools server={@server} tools={@tools} current={@tool} />
      <.derivation_note server={@server} />
      <.back_to_server server={@server} />
    </Layouts.app>
    """
  end

  def render(%{live_action: :client} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail>
        <.crumbs
          server={@server}
          namespace={@namespace}
          short_name={@short_name}
          tool={@tool}
          client={@client}
        />
      </:rail>

      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">{@heading}</h1>
        <h2 class="text-base font-medium text-pretty text-dim">
          How to: {@client.label} {@server.title} {@tool}
        </h2>
        <div class="flex flex-wrap gap-1.5 pt-1">
          <.meta_chip key="client" value={@client.label} tone="brand" />
          <.meta_chip key="transport" value={@server.transport} />
          <.meta_chip key="tool" value={@tool} tone="accent" />
        </div>
      </header>

      <section aria-labelledby="steps-heading" class="space-y-4">
        <h2 id="steps-heading" class="text-xl font-semibold tracking-tight text-balance">
          Add {@server.title} to {@client.label}
        </h2>

        <ol class="space-y-3">
          <li class="flex gap-3">
            <span class="font-mono text-xs text-dim">01</span>
            <p class="text-sm text-pretty text-dim">
              {if @client.kind == :cli,
                do: "Run this in your project directory.",
                else: "Open #{@client.path} and merge this in. Keep any servers already there."}
            </p>
          </li>
        </ol>

        <.code_block
          id="client-config"
          code={@client.code}
          copy_label={if @client.kind == :cli, do: "Copy command", else: "Copy config"}
          max_height="max-h-96"
        />

        <ol class="space-y-3" start="2">
          <li :for={{index, step} <- steps(assigns)} class="flex gap-3">
            <span class="font-mono text-xs text-dim">{index}</span>
            <p class="text-sm text-pretty text-dim">{step}</p>
          </li>
        </ol>

        <p :if={@client.note} class="flex items-start gap-1.5 text-xs text-pretty text-dim">
          <.icon name="hero-information-circle" class="mt-px size-3.5 shrink-0" />
          <span>
            {@client.note}
            <a href={@client.docs_url} rel="nofollow noopener" class={link_class()}>
              {@client.label} docs
            </a>
          </span>
        </p>
      </section>

      <section
        :if={@server.env_vars != []}
        aria-labelledby="secrets-heading"
        class="space-y-2 rounded-box border border-rule bg-surface/30 p-4"
      >
        <h2
          id="secrets-heading"
          class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase"
        >
          <.icon name="hero-shield-check" class="size-3.5 text-brand" /> Set these first
        </h2>
        <p class="text-xs text-pretty text-dim">
          {@server.title} will not start until these are set, so {@tool} never becomes available.
        </p>
        <ul class="flex flex-wrap gap-1.5">
          <li :for={var <- @server.env_vars}>
            <code class="rounded-field border border-rule bg-sunken px-2 py-0.5 font-mono text-[11px] text-accent">
              {var}
            </code>
          </li>
        </ul>
      </section>

      <section aria-labelledby="other-clients" class="space-y-3">
        <h2 id="other-clients" class="font-mono text-[11px] tracking-wide text-dim uppercase">
          Same tool, other clients
        </h2>
        <ul class="flex flex-wrap gap-1.5">
          <li :for={other <- Enum.reject(@clients, &(&1.id == @client.id))}>
            <.link
              navigate={client_path(@server, @tool, other.id)}
              class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
            >
              {other.label}
            </.link>
          </li>
        </ul>
      </section>

      <.derivation_note server={@server} />
      <.back_to_server server={@server} />
    </Layouts.app>
    """
  end

  # --- Pieces shared by the three pages --------------------------------------

  attr :server, :map, required: true
  attr :namespace, :string, required: true
  attr :short_name, :string, required: true
  attr :tool, :string, default: nil
  attr :client, :map, default: nil

  defp crumbs(assigns) do
    ~H"""
    <nav aria-label="Breadcrumb" class="min-w-0 font-mono text-xs">
      <ol class="flex flex-wrap items-center gap-x-1.5 gap-y-1 text-dim">
        <li>
          <.link navigate={~p"/servers"} class="transition-colors hover:text-ink">Servers</.link>
        </li>
        <li aria-hidden="true" class="text-rule-strong">/</li>
        <li>
          <.link navigate={server_path(@server)} class="text-ink transition-colors hover:text-brand">
            {@short_name}
          </.link>
        </li>
        <li aria-hidden="true" class="text-rule-strong">/</li>
        <li>
          <.link
            navigate={tools_path(@server)}
            class={if @tool, do: "transition-colors hover:text-ink", else: "font-medium text-brand"}
          >
            tools
          </.link>
        </li>
        <li :if={@tool} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@tool}>
          <.link
            navigate={tool_path(@server, @tool)}
            class={
              if @client,
                do: "transition-colors hover:text-ink",
                else: "font-medium break-all text-brand"
            }
          >
            {@tool}
          </.link>
        </li>
        <li :if={@client} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@client} class="font-medium text-brand">{@client.label}</li>
      </ol>
    </nav>
    """
  end

  attr :tool, :string, required: true

  defp kind_badge(assigns) do
    ~H"""
    <.badge :if={Tool.kind(@tool) == :mutating} tone="warning">Mutating</.badge>
    <.badge :if={Tool.kind(@tool) == :readonly} tone="success">Read-only</.badge>
    """
  end

  attr :server, :map, required: true
  attr :tools, :list, required: true
  attr :current, :string, required: true

  defp sibling_tools(assigns) do
    ~H"""
    <section :if={length(@tools) > 1} aria-labelledby="siblings" class="space-y-3">
      <h2 id="siblings" class="font-mono text-[11px] tracking-wide text-dim uppercase">
        Other tools on this server
      </h2>
      <ul class="flex flex-wrap gap-1.5">
        <li :for={tool <- Enum.reject(@tools, &(&1 == @current))}>
          <.link
            navigate={tool_path(@server, tool)}
            class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
          >
            {tool}
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :server, :map, required: true

  defp derivation_note(assigns) do
    ~H"""
    <p
      :if={@server.tools_source == "probed"}
      class="flex items-start gap-1.5 text-[11px] text-pretty text-dim"
    >
      <.icon name="hero-check-badge" class="mt-px size-3.5 shrink-0 text-success" />
      <span>
        This list was read from the server itself, by connecting to it and calling <code class="font-mono text-ink">tools/list</code>{probed_phrase(
          @server.probed_at
        )}. It is what
        the server actually exposes, not what its listing claims.
      </span>
    </p>
    <p class="text-[11px] text-pretty text-dim">
      <b class="font-medium text-ink">Mutating</b>
      and <b class="font-medium text-ink">Read-only</b>
      are read off each tool's name, not its schema — a hint, not a guarantee. The registry stores
      tool names only; connect the server for its live schemas.
    </p>
    """
  end

  attr :server, :map, required: true

  defp back_to_server(assigns) do
    ~H"""
    <div class="border-t border-rule pt-5">
      <.button variant="soft" navigate={server_path(@server)}>
        <.icon name="hero-arrow-left-micro" class="size-4" /> {@server.title} MCP server
      </.button>
    </div>
    """
  end

  # --- Helpers ---------------------------------------------------------------

  defp steps(%{client: client, tool: tool, server: server}) do
    [
      {"02",
       if(client.kind == :cli,
         do: "Restart your session so the server is picked up.",
         else: "Save the file and restart #{client.label}."
       )},
      {"03",
       "Ask for something #{tool} does. #{client.label} lists the server's tools on connect and " <>
         "calls #{tool} itself — you do not invoke it by name."},
      {"04",
       "If nothing happens, check the server is running and that #{server.title}'s identifier in " <>
         "your config matches the one above exactly."}
    ]
  end

  defp probed_phrase(nil), do: ""

  defp probed_phrase(%DateTime{} = at),
    do: " on " <> Calendar.strftime(at, "%-d %B %Y")

  defp tool_sentence(tools) do
    tools |> Enum.take(6) |> Enum.join(", ")
  end

  defp tool_count(1), do: "1 tool"
  defp tool_count(n), do: "#{n} tools"

  defp link_class,
    do:
      "underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"

  # Not `url/1`: that name is taken by Phoenix.VerifiedRoutes, whose macro
  # requires a compile-time ~p literal and rejects a built path.
  defp absolute(path), do: McpRegistryWeb.Endpoint.url() <> path
end
