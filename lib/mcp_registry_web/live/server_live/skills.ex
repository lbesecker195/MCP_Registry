defmodule McpRegistryWeb.ServerLive.Skills do
  @moduledoc """
  The skills silo under a listing: an index, a page per skill, and a page per
  skill per client.

    * `:index`  — `/servers/:namespace/:name/skills`
    * `:show`   — `/servers/:namespace/:name/skills/:skill`
    * `:client` — `/servers/:namespace/:name/skills/:skill/:client`

  A skill is an MCP **prompt**: something the user invokes deliberately, as
  against a tool, which the model reaches for on its own. The pages lean on
  that difference, because it is the part a reader arriving from a search has
  usually not understood.

  ## This silo exists only where the data does

  A page is generated only for a listing that actually has prompts, and the
  registry knows that only because it asked. Roughly one remote server in ten
  has any — so this silo covers a small slice of the catalogue by design, and
  a listing with none gets no page rather than an empty one. Thin pages at
  catalogue scale are the doorway pattern search engines penalise.

  Client pages are limited to the clients that can actually invoke a prompt.
  That is a narrower set than for tools: a prompt is surfaced in a client's
  own UI (Claude Code's slash commands, Claude Desktop's attachment menu), so
  a client with no such surface gets no page, however well it runs the server.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Clients, Server, Skill}

  @impl true
  def mount(%{"namespace" => namespace, "name" => name}, _session, socket) do
    server = Registry.get_server!(namespace <> "/" <> name)

    {:ok,
     socket
     |> assign(:server, server)
     |> assign(:short_name, Server.short_name(server))
     |> assign(:namespace, namespace)
     |> assign(:clients, Clients.configs(server))
     |> assign(:skills, server.prompts)
     |> assign(:noindex, server.status != "active")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # A listing with no prompts has no skills page. This is the whole reason the
  # prober was extended -- without a real count, every listing would get one.
  defp apply_action(socket, :index, _params) do
    if socket.assigns.skills == [] do
      push_navigate(socket, to: server_path(socket.assigns.server))
    else
      server = socket.assigns.server
      title = "#{server.title} MCP Skills"

      socket
      |> assign(:page_title, title)
      |> assign(:heading, title)
      |> assign(
        :meta_description,
        "Every skill the #{server.title} MCP server offers: #{skill_sentence(socket.assigns.skills)}. " <>
          "What each one does and how to invoke it from Claude Code, Claude Desktop, Cursor or VS Code."
      )
      |> assign(:canonical_url, absolute(skills_path(server)))
    end
  end

  defp apply_action(socket, :show, %{"skill" => slug}) do
    server = socket.assigns.server

    case Skill.find(socket.assigns.skills, slug) do
      nil ->
        push_navigate(socket, to: server_path(server))

      skill ->
        title = "#{skill} — #{server.title} MCP Skill"

        socket
        |> assign(:skill, skill)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(
          :meta_description,
          "#{skill} is a skill on the #{server.title} MCP server (#{Skill.gloss(skill)}). " <>
            "How to connect the server and invoke #{skill} from Claude Code, Claude Desktop, Cursor or VS Code."
        )
        |> assign(:canonical_url, absolute(skill_path(server, skill)))
    end
  end

  defp apply_action(socket, :client, %{"skill" => slug, "client" => client_id}) do
    server = socket.assigns.server
    skill = Skill.find(socket.assigns.skills, slug)
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))

    cond do
      is_nil(skill) ->
        push_navigate(socket, to: server_path(server))

      is_nil(client) ->
        push_navigate(socket, to: skill_path(server, skill))

      true ->
        # Client first, as on the tool pages: this page exists to answer
        # "<client> <server> <skill>", which is the order it gets typed in.
        title = "#{client.label} #{server.title} Skill/#{skill}"

        socket
        |> assign(:skill, skill)
        |> assign(:client, client)
        |> assign(:page_title, title)
        |> assign(:heading, title)
        |> assign(
          :meta_description,
          "How to invoke the #{skill} skill from the #{server.title} MCP server in #{client.label}: " <>
            "where the configuration lives, what to paste, and how the prompt is surfaced once connected."
        )
        |> assign(:canonical_url, absolute(skill_client_path(server, skill, client.id)))
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
          {@server.title} offers {skill_count(length(@skills))}. A skill is a prompt you invoke
          yourself, rather than a tool the model calls on your behalf — each has its own page with
          the configuration for every client that can run it.
        </p>
      </header>

      <ul class="grid gap-2.5 sm:grid-cols-2">
        <li :for={skill <- @skills}>
          <.link
            navigate={skill_path(@server, skill)}
            class="group flex h-full flex-col gap-1.5 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-rule-strong hover:bg-surface"
          >
            <code class="min-w-0 font-mono text-xs font-semibold break-all text-brand">
              {skill}
            </code>
            <p class="text-[11px] text-dim">{Skill.gloss(skill)}</p>
          </.link>
        </li>
      </ul>

      <.also_tools server={@server} />
      <.provenance server={@server} />
      <.back_to_server server={@server} />
    </Layouts.app>
    """
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail>
        <.crumbs server={@server} namespace={@namespace} short_name={@short_name} skill={@skill} />
      </:rail>

      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">{@heading}</h1>
        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
          <code class="font-mono text-ink">{@skill}</code>
          ({Skill.gloss(@skill)}) is one of {skill_count(length(@skills))} on the
          <.link navigate={server_path(@server)} class={link_class()}>{@server.title}</.link>
          MCP server. Connect the server and it appears in your client, ready to invoke.
        </p>
      </header>

      <section aria-labelledby="clients-heading" class="space-y-4">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">by client</p>
          <h2 id="clients-heading" class="text-xl font-semibold tracking-tight text-balance">
            How to invoke {@skill} from your client
          </h2>
        </div>

        <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={client <- @clients}>
            <.link
              navigate={skill_client_path(@server, @skill, client.id)}
              class="group flex h-full flex-col gap-1 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-brand/40 hover:bg-surface"
            >
              <span class="text-sm font-medium transition-colors group-hover:text-brand">
                {client.label} {@server.title} Skill/{@skill}
              </span>
              <span class="font-mono text-[11px] text-dim">{client.path}</span>
            </.link>
          </li>
        </ul>
      </section>

      <.sibling_skills server={@server} skills={@skills} current={@skill} />
      <.also_tools server={@server} />
      <.provenance server={@server} />
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
          skill={@skill}
          client={@client}
        />
      </:rail>

      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">{@heading}</h1>
        <h2 class="text-base font-medium text-pretty text-dim">
          How to: {@client.label} {@server.title} {@skill}
        </h2>
        <div class="flex flex-wrap gap-1.5 pt-1">
          <.meta_chip key="client" value={@client.label} tone="brand" />
          <.meta_chip key="transport" value={@server.transport} />
          <.meta_chip key="skill" value={@skill} tone="accent" />
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
          id="skill-client-config"
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
          {@server.title} will not start until these are set, so {@skill} never appears in {@client.label}.
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
          Same skill, other clients
        </h2>
        <ul class="flex flex-wrap gap-1.5">
          <li :for={other <- Enum.reject(@clients, &(&1.id == @client.id))}>
            <.link
              navigate={skill_client_path(@server, @skill, other.id)}
              class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
            >
              {other.label}
            </.link>
          </li>
        </ul>
      </section>

      <.provenance server={@server} />
      <.back_to_server server={@server} />
    </Layouts.app>
    """
  end

  # --- Pieces shared by the three pages --------------------------------------

  attr :server, :map, required: true
  attr :namespace, :string, required: true
  attr :short_name, :string, required: true
  attr :skill, :string, default: nil
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
            navigate={skills_path(@server)}
            class={if @skill, do: "transition-colors hover:text-ink", else: "font-medium text-brand"}
          >
            skills
          </.link>
        </li>
        <li :if={@skill} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@skill}>
          <.link
            navigate={skill_path(@server, @skill)}
            class={
              if @client,
                do: "transition-colors hover:text-ink",
                else: "font-medium break-all text-brand"
            }
          >
            {@skill}
          </.link>
        </li>
        <li :if={@client} aria-hidden="true" class="text-rule-strong">/</li>
        <li :if={@client} class="font-medium text-brand">{@client.label}</li>
      </ol>
    </nav>
    """
  end

  attr :server, :map, required: true
  attr :skills, :list, required: true
  attr :current, :string, required: true

  defp sibling_skills(assigns) do
    ~H"""
    <section :if={length(@skills) > 1} aria-labelledby="siblings" class="space-y-3">
      <h2 id="siblings" class="font-mono text-[11px] tracking-wide text-dim uppercase">
        Other skills on this server
      </h2>
      <ul class="flex flex-wrap gap-1.5">
        <li :for={skill <- Enum.reject(@skills, &(&1 == @current))}>
          <.link
            navigate={skill_path(@server, skill)}
            class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
          >
            {skill}
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :server, :map, required: true

  defp also_tools(assigns) do
    ~H"""
    <p :if={@server.tools != []} class="text-xs text-pretty text-dim">
      {@server.title} also exposes
      <.link navigate={tools_path(@server)} class={link_class()}>
        {length(@server.tools)} {if length(@server.tools) == 1, do: "tool", else: "tools"}
      </.link>
      — those the model calls by itself, where the skills above are ones you invoke.
    </p>
    """
  end

  attr :server, :map, required: true

  defp provenance(assigns) do
    ~H"""
    <p class="flex items-start gap-1.5 text-[11px] text-pretty text-dim">
      <.icon name="hero-check-badge" class="mt-px size-3.5 shrink-0 text-success" />
      <span>
        Read from the server itself, by connecting to it and calling <code class="font-mono text-ink">prompts/list</code>{probed_phrase(
          @server.probed_at
        )}.
        Nothing declares prompts in a listing, so this is the only way to know them — and it is
        what the server actually offers, not what its listing claims. The registry stores names
        only; connect the server for each skill's arguments.
      </span>
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

  # Where a prompt actually shows up differs by client, and getting this wrong
  # is the difference between a page that works and one that sends the reader
  # looking for a menu their client does not have.
  defp surfaced_in(%{id: "claude-code"}), do: "as a slash command — type / and it is in the list"
  defp surfaced_in(%{id: "claude-desktop"}), do: "in the attachment menu, under the server's name"
  defp surfaced_in(%{kind: :cli}), do: "in the session's prompt list"
  defp surfaced_in(%{kind: :ui}), do: "in the connector's menu once the server is linked"
  defp surfaced_in(%{kind: :code}), do: "through the client's prompt API, fetched by name"
  defp surfaced_in(_), do: "in the client's prompt or command menu"

  defp steps(%{client: client, skill: skill, server: server}) do
    [
      {"02",
       if(client.kind == :cli,
         do: "Restart your session so the server is picked up.",
         else: "Save the file and restart #{client.label}."
       )},
      {"03",
       "#{skill} is surfaced #{surfaced_in(client)}. Unlike a tool, you invoke a skill " <>
         "deliberately — #{client.label} will not call it for you."},
      {"04",
       "If it does not appear, check that #{server.title} is connected and that it is the " <>
         "prompts list you are looking at, not the tools list."}
    ]
  end

  defp probed_phrase(nil), do: ""

  defp probed_phrase(%DateTime{} = at), do: " on " <> Calendar.strftime(at, "%-d %B %Y")

  defp skill_sentence(skills), do: skills |> Enum.take(6) |> Enum.join(", ")

  defp skill_count(1), do: "1 skill"
  defp skill_count(n), do: "#{n} skills"

  defp link_class,
    do:
      "underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"

  defp absolute(path), do: McpRegistryWeb.Endpoint.url() <> path
end
