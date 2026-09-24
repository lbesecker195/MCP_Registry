defmodule McpRegistryWeb.ServerLive.Agent do
  @moduledoc """
  One listing, set up in one client: `/servers/:namespace/:name/for/:agent`.

  This answers the highest-volume shape of the question — "how do I install
  <server> in <client>" — at the listing level, where the tool pages answer it
  at the tool level.

  ## Which clients get a page

  Only the ones `McpRegistry.Registry.Clients` can give a working instruction
  for, and the instruction differs in kind between them: a command for Claude
  Code, a JSON file for Cursor or Cline, a UI flow for ChatGPT and Claude.ai,
  Python for LangChain.

  Four names that get asked for are deliberately absent, because no amount of
  page would make them true: **GPTBot** and **BingBot** are crawlers,
  **Chrome Lighthouse** audits page performance, and **Perplexity** publishes
  an MCP server rather than consuming other people's. **Aider** has no native
  MCP support either — only a community bridge. A page telling a reader to
  install this server in Lighthouse would rank for a question it answers
  falsely, which costs more than the traffic is worth.

  ChatGPT and Claude.ai appear only for remote listings: neither will run a
  packaged server locally, so for a `stdio` listing there is genuinely nothing
  to show.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Clients, Server}

  @impl true
  def mount(%{"namespace" => namespace, "name" => name, "agent" => agent_id}, _session, socket) do
    server = Registry.get_server!(namespace <> "/" <> name)
    clients = Clients.configs(server)

    case Enum.find(clients, &(&1.id == agent_id)) do
      nil ->
        {:ok, push_navigate(socket, to: server_path(server))}

      client ->
        {:ok,
         socket
         |> assign(:server, server)
         |> assign(:client, client)
         |> assign(:clients, clients)
         |> assign(:short_name, Server.short_name(server))
         |> assign(:namespace, String.trim_trailing(Server.namespace(server), "/"))
         |> assign(:secrets, Map.new(server.env_vars, &{&1, ""}))
         |> assign(:noindex, server.status != "active")
         |> assign(:page_title, page_title(server, client))
         |> assign(:meta_description, meta_description(server, client))
         |> assign(
           :canonical_url,
           McpRegistryWeb.Endpoint.url() <> agent_path(server, client.id)
         )}
    end
  end

  # The client's name is in the title as well as the server's. The requested
  # wording named the server twice, which would have given all twelve pages for
  # a listing the same <title> -- duplicate titles across 400,000 pages, and
  # nothing to tell a searcher which result answers their client.
  defp page_title(server, client) do
    "How to install #{server.title} MCP Server in #{client.label} — setup guide and tutorial"
  end

  defp meta_description(server, client) do
    where =
      case client.kind do
        :cli -> "Run one command"
        :ui -> "Add it through #{client.label}'s connector settings"
        :code -> "Wire it up in a few lines of Python"
        _ -> "Paste one block into #{client.path}"
      end

    "#{where} and #{server.title} is available in #{client.label}. " <>
      "Step-by-step setup for the #{server.title} MCP server: #{transport_phrase(server)}, " <>
      "#{secrets_phrase(server)}, and what to check when it does not connect."
  end

  defp transport_phrase(%Server{transport: "stdio", package_registry: registry})
       when is_binary(registry),
       do: "installed from #{registry}"

  defp transport_phrase(_server), do: "connected over a hosted endpoint"

  defp secrets_phrase(%Server{env_vars: []}), do: "no API key required"
  defp secrets_phrase(%Server{env_vars: [one]}), do: "sets #{one}"
  defp secrets_phrase(%Server{env_vars: vars}), do: "sets #{length(vars)} environment variables"

  @impl true
  def handle_event("update_secrets", %{"secrets" => submitted}, socket) do
    secrets =
      Map.new(socket.assigns.secrets, fn {var, current} ->
        {var, Map.get(submitted, var, current)}
      end)

    {:noreply, assign(socket, :secrets, secrets)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <:rail>
        <nav aria-label="Breadcrumb" class="min-w-0 font-mono text-xs">
          <ol class="flex flex-wrap items-center gap-x-1.5 gap-y-1 text-dim">
            <li>
              <.link navigate={~p"/servers"} class="transition-colors hover:text-ink">Servers</.link>
            </li>
            <li aria-hidden="true" class="text-rule-strong">/</li>
            <li>
              <.link
                navigate={server_path(@server)}
                class="text-ink transition-colors hover:text-brand"
              >
                {@short_name}
              </.link>
            </li>
            <li aria-hidden="true" class="text-rule-strong">/</li>
            <li class="font-medium text-brand" aria-current="page">for {@client.label}</li>
          </ol>
        </nav>
        <.badge tone="brand">{@client.label}</.badge>
      </:rail>

      <header class="rise space-y-4 border-b border-rule pb-8">
        <div class="flex items-start gap-3.5">
          <.monogram name={@server.name} size="size-12 text-lg" />
          <div class="min-w-0 space-y-1">
            <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
              {@server.title} for {@client.label}
            </h1>
            <p class="font-mono text-xs break-all text-dim">{@server.name}</p>
          </div>
        </div>

        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-ink/90">
          {@server.description}
        </p>

        <div class="flex flex-wrap gap-1.5">
          <.meta_chip key="client" value={@client.label} tone="brand" />
          <.meta_chip key="transport" value={@server.transport} />
          <.meta_chip :if={@server.package_registry} key="runtime" value={@server.package_registry} />
          <.meta_chip :if={@server.tools != []} key="tools" value={length(@server.tools)} />
        </div>
      </header>

      <section aria-labelledby="setup" class="space-y-4">
        <h2 id="setup" class="text-xl font-semibold tracking-tight text-balance">
          Install {@server.title} in {@client.label}
        </h2>

        <p class="flex flex-wrap items-center gap-1.5 font-mono text-[11px] text-dim">
          <.icon name={kind_icon(@client.kind)} class="size-3.5 shrink-0" />
          <span>{@client.path}</span>
          <span :if={@client.path_windows} class="text-rule-strong">·</span>
          <span :if={@client.path_windows}>windows: {@client.path_windows}</span>
        </p>

        <form
          :if={injectable(assigns) != []}
          id="agent-secrets"
          phx-change="update_secrets"
          class="space-y-2"
        >
          <div
            :for={var <- injectable(assigns)}
            class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-3"
          >
            <label
              for={"secret-#{var}"}
              class="shrink-0 font-mono text-[11px] text-accent sm:w-56 sm:truncate"
            >
              {var}
            </label>
            <input
              type="password"
              id={"secret-#{var}"}
              name={"secrets[#{var}]"}
              value={@secrets[var]}
              autocomplete="off"
              placeholder="paste to fill the snippet below"
              class="w-full min-w-0 rounded-field border border-rule bg-canvas px-3 py-1.5 font-mono text-xs text-ink outline-none transition-colors placeholder:text-dim hover:border-rule-strong focus:border-brand"
            />
          </div>
          <p class="text-[11px] text-dim">
            Held in this page only — never stored, logged, or sent anywhere but back to your screen.
          </p>
        </form>

        <.code_block
          id="agent-config"
          code={rendered_code(assigns)}
          copy_label={copy_label(@client.kind)}
          max_height="max-h-96"
        />

        <p :if={@client.note} class="flex items-start gap-1.5 text-xs text-pretty text-dim">
          <.icon name="hero-information-circle" class="mt-px size-3.5 shrink-0" />
          <span>
            {@client.note}
            <a
              href={@client.docs_url}
              rel="nofollow noopener"
              class="whitespace-nowrap underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
            >
              {@client.label} docs
            </a>
          </span>
        </p>
      </section>

      <section
        :if={@server.tools != []}
        aria-labelledby="what-you-get"
        class="space-y-3 border-t border-rule pt-6"
      >
        <h2 id="what-you-get" class="text-lg font-semibold tracking-tight text-balance">
          What {@client.label} can do once it is connected
        </h2>
        <ul class="flex flex-wrap gap-1.5">
          <li :for={tool <- Enum.take(@server.tools, 24)}>
            <.link
              navigate={tool_path(@server, tool)}
              class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
            >
              {tool}
            </.link>
          </li>
        </ul>
        <p :if={length(@server.tools) > 24} class="text-xs text-dim">
          <.link navigate={tools_path(@server)} class="text-brand">
            All {length(@server.tools)} tools →
          </.link>
        </p>
      </section>

      <section aria-labelledby="other-clients" class="space-y-3 border-t border-rule pt-6">
        <h2 id="other-clients" class="font-mono text-[11px] tracking-wide text-dim uppercase">
          {@server.title} in other clients
        </h2>
        <ul class="flex flex-wrap gap-1.5">
          <li :for={other <- Enum.reject(@clients, &(&1.id == @client.id))}>
            <.link
              navigate={agent_path(@server, other.id)}
              class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
            >
              {other.label}
            </.link>
          </li>
        </ul>
      </section>

      <div class="border-t border-rule pt-5">
        <.button variant="soft" navigate={server_path(@server)}>
          <.icon name="hero-arrow-left-micro" class="size-4" /> {@server.title} MCP server
        </.button>
      </div>
    </Layouts.app>
    """
  end

  defp kind_icon(:cli), do: "hero-command-line"
  defp kind_icon(:ui), do: "hero-globe-alt"
  defp kind_icon(:code), do: "hero-code-bracket"
  defp kind_icon(_), do: "hero-code-bracket"

  defp copy_label(:cli), do: "Copy command"
  defp copy_label(:ui), do: "Copy URL"
  defp copy_label(:code), do: "Copy code"
  defp copy_label(_), do: "Copy config"

  defp injectable(%{client: client, server: server}) do
    if client.accepts_secrets do
      Enum.filter(server.env_vars, &String.contains?(client.code, "<#{&1}>"))
    else
      []
    end
  end

  defp rendered_code(%{client: client} = assigns) do
    if client.accepts_secrets do
      Enum.reduce(assigns.secrets, client.code, fn {var, value}, code ->
        case String.trim(value) do
          "" -> code
          filled -> String.replace(code, "<#{var}>", filled)
        end
      end)
    else
      client.code
    end
  end
end
