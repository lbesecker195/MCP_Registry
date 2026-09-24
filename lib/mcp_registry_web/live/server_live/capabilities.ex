defmodule McpRegistryWeb.ServerLive.Capabilities do
  @moduledoc """
  The prompts and resources silos under a listing: an index, a page per item,
  and a page per item per client, for each of the two kinds.

      /servers/:namespace/:name/prompts[/:item[/:client]]
      /servers/:namespace/:name/resources[/:item[/:client]]

  ## Why two silos and not one

  They are different things and people search for them differently. A prompt
  is something the user invokes deliberately; a resource is data the client
  attaches as context. The pages say which is which, because that is the part
  a reader arriving from a search has usually not sorted out.

  Both were briefly shipped as one "skills" silo. That was the wrong word:
  MCP has no skills, and nobody searches for them. `/skills` now 301s here.

  ## The silos exist only where the data does

  A page is generated only for a listing that has the thing, and the registry
  knows that only because it asked — roughly one remote server in ten has
  prompts and one in four has resources. A listing with neither gets neither
  page, rather than two empty ones. Thin pages at catalogue scale are the
  doorway pattern search engines penalise.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Capability, Clients, Server}

  @impl true
  def mount(%{"namespace" => namespace, "name" => name}, _session, socket) do
    server = Registry.get_server!(namespace <> "/" <> name)

    {:ok,
     socket
     |> assign(:server, server)
     |> assign(:short_name, Server.short_name(server))
     |> assign(:namespace, namespace)
     |> assign(:clients, Clients.configs(server))
     |> assign(:noindex, server.status != "active")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    action = socket.assigns.live_action
    kind = kind(action)

    socket =
      socket
      |> assign(:kind, kind)
      |> assign(:items, items(socket.assigns.server, kind))

    {:noreply, apply_action(socket, stage(action), params)}
  end

  defp kind(action) do
    if action in [:prompts_index, :prompts_show, :prompts_client], do: :prompts, else: :resources
  end

  defp stage(action) do
    cond do
      action in [:prompts_index, :resources_index] -> :index
      action in [:prompts_show, :resources_show] -> :show
      true -> :client
    end
  end

  defp items(server, :prompts), do: server.prompts
  defp items(server, :resources), do: server.resources

  # An index with nothing on it is not worth a URL. This gate is the whole
  # reason the prober was extended first: without a real count, all 34,000
  # listings would have had both pages with nothing on either.
  defp apply_action(socket, :index, _params) do
    %{server: server, kind: kind, items: items} = socket.assigns

    if items == [] do
      push_navigate(socket, to: server_path(server))
    else
      title = "#{server.title} MCP #{plural(kind)}"

      socket
      |> assign(:page_title, title)
      |> assign(:heading, title)
      |> assign(:meta_description, index_description(server, kind, items))
      |> assign(:canonical_url, absolute(capabilities_path(server, kind)))
    end
  end

  defp apply_action(socket, :show, %{"item" => requested}) do
    %{server: server, kind: kind, items: items} = socket.assigns

    case Capability.find(items, requested) do
      nil ->
        push_navigate(socket, to: server_path(server))

      item ->
        title = "#{display(item, kind)} — #{server.title} MCP #{singular(kind)}"

        socket
        |> assign(:item, item)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(:meta_description, show_description(server, kind, item))
        |> assign(:canonical_url, absolute(capability_path(server, kind, item)))
    end
  end

  defp apply_action(socket, :client, %{"item" => requested, "client" => client_id}) do
    %{server: server, kind: kind, items: items} = socket.assigns
    item = Capability.find(items, requested)
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))

    cond do
      is_nil(item) ->
        push_navigate(socket, to: server_path(server))

      is_nil(client) ->
        push_navigate(socket, to: capability_path(server, kind, item))

      true ->
        # Client first: this page exists to answer "<client> <server> <item>",
        # which is the order the question gets typed in.
        title = "#{client.label} #{server.title} #{singular(kind)}/#{display(item, kind)}"

        socket
        |> assign(:item, item)
        |> assign(:client, client)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(:meta_description, client_description(server, kind, item, client))
        |> assign(:canonical_url, absolute(capability_client_path(server, kind, item, client.id)))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail>
        <.crumbs
          server={@server}
          namespace={@namespace}
          short_name={@short_name}
          kind={@kind}
          item={assigns[:item]}
          client={assigns[:client]}
        />
      </:rail>

      <.index_body :if={stage(@live_action) == :index} {assigns} />
      <.show_body :if={stage(@live_action) == :show} {assigns} />
      <.client_body :if={stage(@live_action) == :client} {assigns} />

      <.provenance kind={@kind} server={@server} />

      <div class="border-t border-rule pt-5">
        <.button variant="soft" navigate={server_path(@server)}>
          <.icon name="hero-arrow-left-micro" class="size-4" /> {@server.title} MCP server
        </.button>
      </div>
    </Layouts.app>
    """
  end

  # --- The three page bodies -------------------------------------------------

  defp index_body(assigns) do
    ~H"""
    <header class="rise space-y-3 border-b border-rule pb-6">
      <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">{@heading}</h1>
      <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
        {@server.title} offers {count(length(@items), @kind)}. {blurb(@kind)}
      </p>
    </header>

    <ul class="grid gap-2.5 sm:grid-cols-2">
      <li :for={item <- @items}>
        <.link
          navigate={capability_path(@server, @kind, item)}
          class="group flex h-full flex-col gap-1.5 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-rule-strong hover:bg-surface"
        >
          <div class="flex items-start justify-between gap-2">
            <code class="min-w-0 font-mono text-xs font-semibold break-all text-brand">
              {display(item, @kind)}
            </code>
            <.badge :if={@kind == :resources and Capability.scheme(item)} tone="neutral">
              {Capability.scheme(item)}
            </.badge>
          </div>
          <p :if={@kind == :prompts} class="text-[11px] text-dim">{Capability.gloss(item)}</p>
        </.link>
      </li>
    </ul>

    <.sibling_silo server={@server} kind={@kind} />
    """
  end

  defp show_body(assigns) do
    ~H"""
    <header class="rise space-y-3 border-b border-rule pb-6">
      <h1 class="text-2xl font-semibold tracking-tight break-words text-balance sm:text-3xl">
        {@heading}
      </h1>
      <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
        <code class="font-mono break-all text-ink">{display(@item, @kind)}</code>
        is one of {count(length(@items), @kind)} on the
        <.link navigate={server_path(@server)} class={link_class()}>{@server.title}</.link>
        MCP server. {reach_phrase(@kind)}
      </p>
    </header>

    <section aria-labelledby="clients-heading" class="space-y-4">
      <div class="space-y-1.5">
        <p class="font-mono text-[11px] tracking-wide text-dim uppercase">by client</p>
        <h2 id="clients-heading" class="text-xl font-semibold tracking-tight text-balance">
          How to {verb(@kind)} {display(@item, @kind)} from your client
        </h2>
      </div>

      <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        <li :for={client <- @clients}>
          <.link
            navigate={capability_client_path(@server, @kind, @item, client.id)}
            class="group flex h-full flex-col gap-1 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-brand/40 hover:bg-surface"
          >
            <span class="text-sm font-medium break-words transition-colors group-hover:text-brand">
              {client.label} {@server.title} {singular(@kind)}/{display(@item, @kind)}
            </span>
            <span class="font-mono text-[11px] text-dim">{client.path}</span>
          </.link>
        </li>
      </ul>
    </section>

    <section :if={length(@items) > 1} aria-labelledby="siblings" class="space-y-3">
      <h2 id="siblings" class="font-mono text-[11px] tracking-wide text-dim uppercase">
        Other {plural(@kind) |> String.downcase()} on this server
      </h2>
      <ul class="flex flex-wrap gap-1.5">
        <li :for={other <- @items |> Enum.reject(&(&1 == @item)) |> Enum.take(40)}>
          <.link
            navigate={capability_path(@server, @kind, other)}
            class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] break-all text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
          >
            {display(other, @kind)}
          </.link>
        </li>
      </ul>
    </section>

    <.sibling_silo server={@server} kind={@kind} />
    """
  end

  defp client_body(assigns) do
    ~H"""
    <header class="rise space-y-3 border-b border-rule pb-6">
      <h1 class="text-2xl font-semibold tracking-tight break-words text-balance sm:text-3xl">
        {@heading}
      </h1>
      <h2 class="text-base font-medium break-words text-pretty text-dim">
        How to: {@client.label} {@server.title} {display(@item, @kind)}
      </h2>
      <div class="flex flex-wrap gap-1.5 pt-1">
        <.meta_chip key="client" value={@client.label} tone="brand" />
        <.meta_chip key="transport" value={@server.transport} />
        <.meta_chip
          key={singular(@kind) |> String.downcase()}
          value={short(@item, @kind)}
          tone="accent"
        />
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
        id="capability-client-config"
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
        {@server.title} will not start until these are set, so it never reaches {@client.label}.
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
        Same {singular(@kind) |> String.downcase()}, other clients
      </h2>
      <ul class="flex flex-wrap gap-1.5">
        <li :for={other <- Enum.reject(@clients, &(&1.id == @client.id))}>
          <.link
            navigate={capability_client_path(@server, @kind, @item, other.id)}
            class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
          >
            {other.label}
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  # --- Shared pieces ---------------------------------------------------------

  attr :server, :map, required: true
  attr :namespace, :string, required: true
  attr :short_name, :string, required: true
  attr :kind, :atom, required: true
  attr :item, :string, default: nil
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
            navigate={capabilities_path(@server, @kind)}
            class={if @item, do: "transition-colors hover:text-ink", else: "font-medium text-brand"}
          >
            {@kind}
          </.link>
        </li>
        <li :if={@item} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@item} class="min-w-0">
          <.link
            navigate={capability_path(@server, @kind, @item)}
            class={
              if @client,
                do: "transition-colors hover:text-ink",
                else: "font-medium break-all text-brand"
            }
          >
            {short(@item, @kind)}
          </.link>
        </li>
        <li :if={@client} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@client} class="font-medium text-brand">{@client.label}</li>
      </ol>
    </nav>
    """
  end

  attr :server, :map, required: true
  attr :kind, :atom, required: true

  # Each silo points at the other, so a reader who guessed wrong is one click
  # from the right one rather than back at a search box.
  defp sibling_silo(assigns) do
    ~H"""
    <p :if={other_items(@server, @kind) != []} class="text-xs text-pretty text-dim">
      {@server.title} also offers
      <.link navigate={capabilities_path(@server, other_kind(@kind))} class={link_class()}>
        {count(length(other_items(@server, @kind)), other_kind(@kind))}
      </.link>
      — {contrast(@kind)}
    </p>
    """
  end

  attr :server, :map, required: true
  attr :kind, :atom, required: true

  defp provenance(assigns) do
    ~H"""
    <p class="flex items-start gap-1.5 text-[11px] text-pretty text-dim">
      <.icon name="hero-check-badge" class="mt-px size-3.5 shrink-0 text-success" />
      <span>
        Read from the server itself, by connecting to it and calling <code class="font-mono text-ink">{@kind}/list</code>{probed_phrase(
          @server.probed_at
        )}.
        A listing does not declare its {@kind}, so asking is the only way to know them, and this
        is what the server actually offers rather than what its listing claims. Names only are
        stored; connect the server for {detail_phrase(@kind)}.
      </span>
    </p>
    """
  end

  # --- Words that differ between the two kinds -------------------------------

  defp singular(:prompts), do: "Prompt"
  defp singular(:resources), do: "Resource"

  defp plural(:prompts), do: "Prompts"
  defp plural(:resources), do: "Resources"

  defp other_kind(:prompts), do: :resources
  defp other_kind(:resources), do: :prompts

  defp other_items(server, kind), do: items(server, other_kind(kind))

  defp verb(:prompts), do: "invoke"
  defp verb(:resources), do: "attach"

  defp count(1, kind), do: "1 #{singular(kind) |> String.downcase()}"
  defp count(n, kind), do: "#{n} #{plural(kind) |> String.downcase()}"

  # A prompt name is short enough to print; a resource URI is not.
  defp display(item, :prompts), do: item
  defp display(item, :resources), do: Capability.short_uri(item)

  defp short(item, :prompts), do: item
  defp short(item, :resources), do: Capability.short_uri(item)

  defp blurb(:prompts),
    do:
      "A prompt is one you invoke yourself, rather than a tool the model calls on your behalf — " <>
        "each has its own page with the configuration for every client that can run it."

  defp blurb(:resources),
    do:
      "A resource is data the server exposes for a client to attach as context — a file, a page, " <>
        "an API response — rather than an action. Each has its own page, per client."

  defp contrast(:prompts), do: "data you attach as context, where a prompt is something you run."
  defp contrast(:resources), do: "things you invoke, where a resource is context you attach."

  defp reach_phrase(:prompts),
    do: "Connect the server and it appears in your client, ready to invoke."

  defp reach_phrase(:resources),
    do: "Connect the server and your client can attach it as context."

  defp detail_phrase(:prompts), do: "each prompt's arguments"
  defp detail_phrase(:resources), do: "each resource's type and contents"

  # Where a prompt or resource actually surfaces differs by client, and getting
  # this wrong sends the reader looking for a menu their client does not have.
  defp surfaced_in(:prompts, %{id: "claude-code"}),
    do: "as a slash command — type / and it is in the list"

  defp surfaced_in(:prompts, %{id: "claude-desktop"}),
    do: "in the attachment menu, under the server's name"

  defp surfaced_in(:prompts, %{kind: :cli}), do: "in the session's prompt list"

  defp surfaced_in(:prompts, %{kind: :ui}),
    do: "in the connector's menu once the server is linked"

  defp surfaced_in(:prompts, %{kind: :code}),
    do: "through the client's prompt API, fetched by name"

  defp surfaced_in(:prompts, _), do: "in the client's prompt or command menu"

  defp surfaced_in(:resources, %{id: "claude-desktop"}),
    do: "in the attachment menu, where you pick it as context"

  defp surfaced_in(:resources, %{kind: :code}),
    do: "through the client's resource API, read by URI"

  defp surfaced_in(:resources, _), do: "wherever your client lets you attach context"

  defp steps(%{client: client, item: item, kind: kind, server: server}) do
    name = display(item, kind)

    [
      {"02",
       if(client.kind == :cli,
         do: "Restart your session so the server is picked up.",
         else: "Save the file and restart #{client.label}."
       )},
      {"03",
       "#{name} is surfaced #{surfaced_in(kind, client)}. " <>
         if(kind == :prompts,
           do:
             "Unlike a tool, you invoke it deliberately — #{client.label} will not call it for you.",
           else: "It is context to attach, not an action to run."
         )},
      {"04",
       "If it does not appear, check that #{server.title} is connected and that you are looking " <>
         "at its #{kind} rather than its tools."}
    ]
  end

  # --- Descriptions ----------------------------------------------------------

  defp index_description(server, :prompts, items) do
    "Every prompt the #{server.title} MCP server offers: #{sentence(items, :prompts)}. " <>
      "What each one does and how to invoke it from Claude Code, Claude Desktop, Cursor or VS Code."
  end

  defp index_description(server, :resources, items) do
    "Every resource the #{server.title} MCP server exposes: #{sentence(items, :resources)}. " <>
      "What each one holds and how to attach it as context in Claude Code, Claude Desktop, Cursor or VS Code."
  end

  defp show_description(server, :prompts, item) do
    "#{item} is a prompt on the #{server.title} MCP server (#{Capability.gloss(item)}). " <>
      "How to connect the server and invoke #{item} from Claude Code, Claude Desktop, Cursor or VS Code."
  end

  defp show_description(server, :resources, item) do
    "#{Capability.short_uri(item)} is a resource on the #{server.title} MCP server. " <>
      "How to connect the server and attach it as context in Claude Code, Claude Desktop, Cursor or VS Code."
  end

  defp client_description(server, kind, item, client) do
    "How to #{verb(kind)} #{display(item, kind)} from the #{server.title} MCP server in " <>
      "#{client.label}: where the configuration lives, what to paste, and how it is surfaced once connected."
  end

  defp sentence(items, kind) do
    items |> Enum.take(6) |> Enum.map(&display(&1, kind)) |> Enum.join(", ")
  end

  defp probed_phrase(nil), do: ""
  defp probed_phrase(%DateTime{} = at), do: " on " <> Calendar.strftime(at, "%-d %B %Y")

  defp link_class,
    do:
      "underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"

  defp absolute(path), do: McpRegistryWeb.Endpoint.url() <> path
end
