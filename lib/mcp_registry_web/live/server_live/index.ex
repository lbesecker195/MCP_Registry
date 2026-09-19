defmodule McpRegistryWeb.ServerLive.Index do
  @moduledoc """
  The catalogue at `/servers`: search, filter and page through every listing.

  This page is a tool rather than a pitch. The search row is the centre of
  gravity, filters are reversible one control at a time, and the results stay a
  hairline-ruled list so a long scan reads as a catalogue.
  """
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
     |> assign(
       :meta_description,
       "Search the MCP Registry: an open directory of Model Context Protocol servers. " <>
         "Filter by tag, tool and transport, then connect one to Claude, Cursor or any MCP client."
     )
     |> assign(:canonical_url, McpRegistryWeb.Endpoint.url() <> "/servers")
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
      Analytics.track(:search, %{results: total, path: "/servers"})
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
    <Layouts.app flash={@flash} active={:servers}>
      <div class="rise">
        <.header>
          Browse MCP servers
          <:subtitle>
            MCP Harbor, an MCP Server Registry, Directory, and Tower to Buzz.
          </:subtitle>
          <:actions>
            <p class="flex items-baseline gap-2 font-mono">
              <span class="text-2xl font-semibold tracking-tight">{format_number(@total)}</span>
              <span class="text-xs text-dim">
                {if any_filter?(@q, @transport, @tag), do: "matching", else: "servers"}
              </span>
            </p>
          </:actions>
        </.header>
      </div>

      <section class="rise space-y-3" style="--d: 70ms" aria-label="Search and filter">
        <form
          id="search-form"
          role="search"
          phx-change="search"
          phx-submit="search"
          class="flex flex-col gap-2 sm:flex-row"
        >
          <div class="group flex h-11 flex-1 items-center gap-2.5 rounded-field border border-rule bg-surface px-3 transition-all duration-200 hover:border-rule-strong focus-within:border-brand focus-within:ring-2 focus-within:ring-brand/20">
            <label for="search-input" class="sr-only">Search MCP servers</label>
            <.icon
              name="hero-magnifying-glass"
              class="size-4 shrink-0 text-dim transition-colors group-focus-within:text-brand"
            />
            <input
              id="search-input"
              type="search"
              name="q"
              value={@q}
              placeholder="Search by name, description, tag or tool…"
              phx-debounce="250"
              phx-hook=".SearchShortcut"
              autocomplete="off"
              class="h-full min-w-0 grow bg-transparent font-mono text-sm outline-none placeholder:text-dim focus:outline-none [&::-webkit-search-cancel-button]:hidden"
            />
            <.link
              :if={@q != ""}
              patch={index_path("", @transport, @tag)}
              aria-label="Clear the search"
              class="flex size-6 shrink-0 items-center justify-center rounded-full text-dim transition-colors hover:bg-sunken hover:text-ink"
            >
              <.icon name="hero-x-mark-micro" class="size-3.5" />
            </.link>
            <kbd
              :if={@q == ""}
              class="hidden shrink-0 rounded-field border border-rule px-1.5 py-0.5 font-mono text-[10px] text-dim sm:block"
            >
              /
            </kbd>
          </div>

          <select
            name="transport"
            aria-label="Filter by transport"
            class="h-11 cursor-pointer rounded-field border border-rule bg-surface px-3 font-mono text-sm text-ink outline-none transition-colors hover:border-rule-strong focus:border-brand sm:w-52"
          >
            <option value="">any transport</option>
            <option :for={t <- @transports} value={t} selected={t == @transport}>{t}</option>
          </select>
        </form>

        <nav
          class="-mx-4 flex gap-1.5 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0"
          aria-label="Filter by tag"
        >
          <.link
            patch={index_path(@q, @transport, nil)}
            aria-current={is_nil(@tag) && "true"}
            class={[chip_classes(), chip_tone(is_nil(@tag))]}
          >
            all
          </.link>
          <.link
            :for={{tag, count} <- @tags}
            patch={index_path(@q, @transport, tag)}
            aria-current={@tag == tag && "true"}
            class={[chip_classes(), chip_tone(@tag == tag)]}
          >
            {tag} <span class="opacity-60">{count}</span>
          </.link>
        </nav>

        <div :if={any_filter?(@q, @transport, @tag)} class="flex flex-wrap items-center gap-2">
          <span class="font-mono text-[11px] tracking-wide text-dim uppercase">filtered by</span>
          <.filter_pill
            :if={@q != ""}
            label={@q}
            remove={index_path("", @transport, @tag)}
            remove_label={"Clear the search term #{@q}"}
          />
          <.filter_pill
            :if={@tag}
            label={"##{@tag}"}
            remove={index_path(@q, @transport, nil)}
            remove_label={"Remove the #{@tag} tag filter"}
          />
          <.filter_pill
            :if={@transport}
            label={@transport}
            remove={index_path(@q, nil, @tag)}
            remove_label={"Remove the #{@transport} transport filter"}
          />
          <.link
            patch={~p"/servers"}
            class="rounded-field px-1 py-0.5 font-mono text-[11px] text-dim underline decoration-rule-strong underline-offset-4 transition-colors hover:text-ink hover:decoration-brand"
          >
            clear all
          </.link>
        </div>
      </section>
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

      <div :if={@servers != []} class="space-y-2.5">
        <p id="result-count" aria-live="polite" class="font-mono text-xs text-dim">
          Showing {format_number(@first_shown)}–{format_number(@last_shown)} of {format_number(@total)} servers
        </p>

        <ul class="rule-list border-y border-rule" aria-label="MCP servers">
          <li :for={server <- @servers}>
            <.link
              navigate={server_path(server)}
              class="group/row -mx-3 flex gap-3.5 px-3 py-4 transition-colors hover:bg-surface focus-visible:bg-surface"
            >
              <.monogram name={server.name} size="size-9 text-xs" class="mt-0.5" />

              <div class="min-w-0 flex-1">
                <div class="flex items-start justify-between gap-3">
                  <h2 class="font-medium tracking-tight transition-colors group-hover/row:text-brand">
                    {server.title}
                  </h2>
                  <span class={[
                    "shrink-0 rounded-full border px-2 py-0.5 font-mono text-[11px]",
                    Layouts.transport_tone(server.transport)
                  ]}>
                    {server.transport}
                  </span>
                </div>

                <p class="mt-0.5 font-mono text-xs break-all">
                  <span class="text-dim">{Server.namespace(server)}</span><span class="text-dim">{Server.short_name(
                    server
                  )}</span>
                </p>

                <p class="mt-2 line-clamp-2 text-sm text-pretty text-dim">{server.description}</p>

                <div class="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1.5 font-mono text-[11px] text-dim">
                  <span :if={server.synced_at} class="inline-flex items-center gap-1 text-success">
                    <.icon name="hero-check-badge" class="size-3.5" /> official
                  </span>
                  <span :if={server.tools != []}>{tool_count(length(server.tools))}</span>
                  <span :if={server.env_vars != []}>{length(server.env_vars)} secrets</span>
                  <span :for={tag <- Enum.take(server.tags, 4)}>#{tag}</span>
                </div>
              </div>
            </.link>
          </li>
        </ul>
      </div>

      <div :if={@servers == []} class="rise border-y border-rule px-4 py-14 text-center">
        <.icon name="hero-magnifying-glass" class="mx-auto size-6 text-dim" />

        <h2 class="mt-3 text-base font-medium text-balance">
          No servers {filter_phrase(@q, @transport, @tag) || "are listed yet"}
        </h2>

        <p class="mx-auto mt-1.5 max-w-md text-sm text-pretty text-dim">
          Search covers names, descriptions, tags and tool names. A shorter term, or one filter
          fewer, usually finds it.
        </p>

        <div class="mt-6 flex flex-wrap items-center justify-center gap-2">
          <.button :if={@q != ""} variant="soft" patch={index_path("", @transport, @tag)}>
            <.icon name="hero-x-mark" class="size-4" /> Clear the search
          </.button>
          <.button :if={any_filter?(@q, @transport, @tag)} variant="soft" patch={~p"/servers"}>
            <.icon name="hero-squares-2x2" class="size-4" />
            Browse all {format_number(@stats.servers)} servers
          </.button>
          <.button variant="primary" navigate={~p"/submit"}>
            <.icon name="hero-rocket-launch" class="size-4" /> Submit a server
          </.button>
        </div>
      </div>

      <nav
        :if={@last_page > 1}
        id="pagination"
        aria-label="Pagination"
        class="flex items-center justify-between gap-3"
      >
        <.link
          :if={@page > 1}
          patch={index_path(@q, @transport, @tag, @page - 1)}
          rel="prev"
          class={page_button_classes()}
        >
          <.icon name="hero-arrow-left-micro" class="size-3.5" /> Previous
        </.link>
        <span
          :if={@page == 1}
          aria-hidden="true"
          class={[page_button_classes(), "pointer-events-none opacity-40"]}
        >
          <.icon name="hero-arrow-left-micro" class="size-3.5" /> Previous
        </span>

        <span class="font-mono text-xs text-dim">
          Page {format_number(@page)} of {format_number(@last_page)}
        </span>

        <.link
          :if={@page < @last_page}
          patch={index_path(@q, @transport, @tag, @page + 1)}
          rel="next"
          class={page_button_classes()}
        >
          Next <.icon name="hero-arrow-right-micro" class="size-3.5" />
        </.link>
        <span
          :if={@page == @last_page}
          aria-hidden="true"
          class={[page_button_classes(), "pointer-events-none opacity-40"]}
        >
          Next <.icon name="hero-arrow-right-micro" class="size-3.5" />
        </span>
      </nav>

      <section aria-labelledby="agent-access" class="rounded-box border border-rule bg-surface/60 p-4">
        <div class="flex items-center gap-2">
          <.icon name="hero-command-line" class="size-4 shrink-0 text-brand" />
          <h2 id="agent-access" class="font-mono text-[11px] tracking-wide text-dim uppercase">
            Search this catalogue from your agent
          </h2>
        </div>
        <p class="mt-2 max-w-2xl text-sm text-pretty text-dim">
          The registry is itself an MCP server. Add it once and your agent runs these same
          searches, with no account and no key.
        </p>
        <.copy_command
          id="agent-install"
          class="mt-3"
          command={"claude mcp add --transport http mcp-registry-search #{@mcp_url}"}
        />
      </section>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :remove, :string, required: true
  attr :remove_label, :string, required: true

  defp filter_pill(assigns) do
    ~H"""
    <span class="inline-flex max-w-full items-center gap-1 rounded-full border border-rule bg-surface py-0.5 pr-1 pl-2.5 font-mono text-[11px]">
      <span class="truncate">{@label}</span>
      <.link
        patch={@remove}
        aria-label={@remove_label}
        class="flex size-4 shrink-0 items-center justify-center rounded-full text-dim transition-colors hover:bg-sunken hover:text-ink"
      >
        <.icon name="hero-x-mark-micro" class="size-3" />
      </.link>
    </span>
    """
  end

  defp chip_classes,
    do: "shrink-0 rounded-field border px-2.5 py-1 font-mono text-xs transition-colors"

  defp chip_tone(true), do: "border-brand bg-brand text-brand-ink"

  defp chip_tone(false),
    do: "border-rule text-dim hover:border-rule-strong hover:bg-surface hover:text-ink"

  defp page_button_classes,
    do:
      "inline-flex min-h-10 items-center gap-1.5 rounded-field border border-rule bg-surface px-3.5 font-mono text-xs transition-colors hover:border-rule-strong hover:bg-sunken"

  defp index_path(q, transport, tag, page \\ 1) do
    params =
      [q: q, transport: transport, tag: tag, page: if(page > 1, do: page)]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    ~p"/servers?#{params}"
  end

  defp any_filter?(q, transport, tag), do: q != "" or transport != nil or tag != nil

  # Reads back the active filters as a sentence fragment, so an empty result
  # says what was actually asked for rather than "no matches".
  defp filter_phrase(q, transport, tag) do
    [
      q != "" && ~s(matching "#{q}"),
      tag && "tagged ##{tag}",
      transport && "on #{transport}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      phrase -> phrase
    end
  end

  defp tool_count(1), do: "1 tool"
  defp tool_count(n), do: "#{n} tools"

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
