defmodule McpRegistryWeb.ServerLive.Index do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Analytics
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  @per_page 48

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Browse MCP servers")
     |> assign(:tags, Registry.top_tags(14))
     |> assign(:stats, Registry.stats())
     |> assign(:transports, Server.transports())
     |> assign(:mcp_url, McpRegistryWeb.Endpoint.url() <> "/mcp")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = String.trim(params["q"] || "")
    transport = blank_to_nil(params["transport"])
    tag = blank_to_nil(params["tag"])
    filters = [q: q, transport: transport, tag: tag]

    total = Registry.count_servers(filters)
    last_page = max(div(total + @per_page - 1, @per_page), 1)
    page = params["page"] |> parse_page() |> min(last_page)

    servers =
      Registry.list_servers(filters ++ [limit: @per_page, offset: (page - 1) * @per_page])

    if connected?(socket) and q != "" and page == 1 do
      Analytics.track(:search, %{results: total, path: "/"})
    end

    {:noreply,
     assign(socket,
       q: q,
       transport: transport,
       tag: tag,
       servers: servers,
       page: page,
       last_page: last_page,
       total: total,
       first_shown: if(total == 0, do: 0, else: (page - 1) * @per_page + 1),
       last_shown: min(page * @per_page, total)
     )}
  end

  @impl true
  def handle_event("search", %{"q" => q} = params, socket) do
    transport = Map.get(params, "transport", socket.assigns.transport)
    {:noreply, push_patch(socket, to: index_path(q, transport, socket.assigns.tag))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-5 pb-2">
        <h1 class="max-w-3xl text-4xl font-semibold tracking-tight sm:text-5xl">
          Find MCP servers your agent can use.
        </h1>

        <p class="max-w-2xl text-dim">
          The registry mirrors the whole <span :if={@stats.official > 0}>official MCP Registry</span>
          and stays in sync automatically. Browse below, or <.link
            navigate={~p"/submit"}
            class="text-base-content underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-primary"
          >
            add one
          </.link>.
        </p>

        <dl class="flex flex-wrap items-baseline gap-x-8 gap-y-3 border-y border-rule py-4 font-mono">
          <div class="flex items-baseline gap-2">
            <dd class="text-xl font-semibold tracking-tight">{format_number(@stats.servers)}</dd>
            <dt class="text-xs text-dim">servers</dt>
          </div>
          <div class="flex items-baseline gap-2">
            <dd class="text-xl font-semibold tracking-tight">{format_number(@stats.tools)}</dd>
            <dt class="text-xs text-dim">tools</dt>
          </div>
          <div class="flex items-baseline gap-2">
            <dd class="text-xl font-semibold tracking-tight">{format_number(@stats.remote)}</dd>
            <dt class="text-xs text-dim">hosted remotely</dt>
          </div>
          <div :if={@stats.official > 0} class="flex items-baseline gap-2">
            <dd class="text-xl font-semibold tracking-tight">{format_number(@stats.official)}</dd>
            <dt class="text-xs text-dim">from the official registry</dt>
          </div>
        </dl>
      </section>

      <section id="for-agents" class="rounded-box border border-rule bg-base-200/60">
        <div class="flex flex-col gap-3 p-4">
          <div class="flex items-center gap-2">
            <span class="relative flex size-1.5">
              <span class="absolute inline-flex size-full animate-ping rounded-full bg-accent opacity-75"></span>
              <span class="relative inline-flex size-1.5 rounded-full bg-accent"></span>
            </span>
            <h2 class="font-mono text-xs font-medium tracking-wide uppercase">
              This registry is itself an MCP server
            </h2>
          </div>
          <p class="max-w-2xl text-sm text-dim">
            Connect to it and your agent searches and submits on its own, with no account.
            Details in <a
              href={~p"/llms.txt"}
              class="text-base-content underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-primary"
            >
              /llms.txt
            </a>.
          </p>
          <.copy_command
            id="agent-install"
            command={"claude mcp add --transport http mcp-registry-search #{@mcp_url}"}
          />
        </div>
      </section>

      <form
        id="search-form"
        phx-change="search"
        phx-submit="search"
        class="flex flex-col gap-2 sm:flex-row"
      >
        <label class="group flex flex-1 items-center gap-2.5 rounded-box border border-rule bg-base-200 px-3 py-2.5 transition-colors focus-within:border-primary">
          <.icon name="hero-magnifying-glass" class="size-4 shrink-0 text-dim" />
          <input
            id="search-input"
            type="search"
            name="q"
            value={@q}
            placeholder="Search by name, description, tag or tool name…"
            phx-debounce="250"
            phx-hook=".SearchShortcut"
            class="grow bg-transparent font-mono text-sm outline-none placeholder:text-dim"
            autocomplete="off"
          />
          <kbd class="hidden shrink-0 rounded border border-rule px-1.5 py-0.5 font-mono text-[10px] text-dim sm:block">
            /
          </kbd>
        </label>
        <select
          name="transport"
          class="rounded-box border border-rule bg-base-200 px-3 py-2.5 font-mono text-sm outline-none transition-colors focus:border-primary"
        >
          <option value="">any transport</option>
          <option :for={t <- @transports} value={t} selected={t == @transport}>{t}</option>
        </select>
      </form>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SearchShortcut">
        export default {
          mounted() {
            this.onKey = (e) => {
              const el = document.activeElement
              const typing = el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable)
              if (e.key === "/" && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
                e.preventDefault()
                this.el.focus()
                this.el.select()
              } else if (e.key === "Escape" && el === this.el) {
                this.el.blur()
              }
            }
            window.addEventListener("keydown", this.onKey)
          },
          destroyed() {
            window.removeEventListener("keydown", this.onKey)
          }
        }
      </script>

      <div class="-mx-4 flex gap-1.5 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0">
        <.link
          patch={index_path(@q, @transport, nil)}
          class={[
            "shrink-0 rounded-field border px-2.5 py-1 font-mono text-xs transition-colors",
            if(@tag == nil,
              do: "border-primary bg-primary text-primary-content",
              else: "border-rule text-dim hover:border-rule-strong hover:text-base-content"
            )
          ]}
        >
          all
        </.link>
        <.link
          :for={{tag, count} <- @tags}
          patch={index_path(@q, @transport, tag)}
          class={[
            "shrink-0 rounded-field border px-2.5 py-1 font-mono text-xs transition-colors",
            if(@tag == tag,
              do: "border-primary bg-primary text-primary-content",
              else: "border-rule text-dim hover:border-rule-strong hover:text-base-content"
            )
          ]}
        >
          {tag} <span class="opacity-70">{count}</span>
        </.link>
      </div>

      <div :if={@servers == []} class="border-y border-rule py-16 text-center">
        <p class="font-mono text-sm text-dim">no servers match</p>
        <.link
          navigate={~p"/submit"}
          class="mt-2 inline-block text-sm text-base-content underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-primary"
        >
          submit one?
        </.link>
      </div>

      <p :if={@total > 0} id="result-count" class="font-mono text-xs text-dim">
        Showing {format_number(@first_shown)}–{format_number(@last_shown)} of {format_number(@total)} servers
      </p>

      <ul :if={@servers != []} class="rule-list border-y border-rule">
        <li :for={server <- @servers}>
          <.link
            navigate={server_path(server)}
            class="group/row block px-3 py-3.5 -mx-3 transition-colors hover:bg-base-200"
          >
            <div class="flex items-baseline gap-3">
              <h2 class="truncate font-medium tracking-tight">{server.title}</h2>
              <span class="ml-auto shrink-0 font-mono text-[11px] text-dim">
                {server.transport}
              </span>
            </div>

            <p class="mt-0.5 truncate font-mono text-xs">
              <span class="text-dim">{Server.namespace(server)}</span><span class="text-base-content/90 transition-colors group-hover/row:text-primary">{Server.short_name(
                server
              )}</span>
            </p>

            <p class="mt-1.5 line-clamp-2 text-sm text-dim">{server.description}</p>

            <div class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 font-mono text-[11px] text-dim">
              <span :if={server.tools != []}>{length(server.tools)} tools</span>
              <span :for={tag <- Enum.take(server.tags, 4)} class="text-dim">#{tag}</span>
            </div>
          </.link>
        </li>
      </ul>

      <nav :if={@last_page > 1} id="pagination" class="flex items-center justify-center gap-3 pt-2">
        <.link
          :if={@page > 1}
          patch={index_path(@q, @transport, @tag, @page - 1)}
          class="flex items-center gap-1.5 rounded-field border border-rule px-3 py-1.5 font-mono text-xs transition-colors hover:border-rule-strong hover:bg-base-200"
          rel="prev"
        >
          <.icon name="hero-arrow-left-micro" class="size-3.5" /> Previous
        </.link>
        <span class="px-2 font-mono text-xs text-dim">
          Page {format_number(@page)} of {format_number(@last_page)}
        </span>
        <.link
          :if={@page < @last_page}
          patch={index_path(@q, @transport, @tag, @page + 1)}
          class="flex items-center gap-1.5 rounded-field border border-rule px-3 py-1.5 font-mono text-xs transition-colors hover:border-rule-strong hover:bg-base-200"
          rel="next"
        >
          Next <.icon name="hero-arrow-right-micro" class="size-3.5" />
        </.link>
      </nav>
    </Layouts.app>
    """
  end

  defp index_path(q, transport, tag, page \\ 1) do
    params =
      [q: q, transport: transport, tag: tag, page: if(page > 1, do: page)]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    ~p"/?#{params}"
  end

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
