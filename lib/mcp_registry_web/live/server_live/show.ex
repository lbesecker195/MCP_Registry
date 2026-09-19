defmodule McpRegistryWeb.ServerLive.Show do
  @moduledoc """
  One listing at `/servers/*name`, laid out as an install console rather than
  an article.

  The page answers three questions in the order people ask them: what is this
  (the rail and the hero), how do I wire it up (the install hub), and what can
  it actually do (the tool explorer and the metadata rail). Long-form content --
  the generated article and the upstream README -- sits below all of that,
  always rendered rather than hidden behind a tab, because it is what the page
  ranks on.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Clients, Install, Manifest, RemoteContent, Server}

  @impl true
  def mount(%{"name" => segments}, _session, socket) do
    server = Registry.get_server!(Enum.join(segments, "/"))

    article_html =
      if server.article_content do
        markdown_to_html(server.article_content)
      else
        nil
      end

    socket =
      assign(socket,
        page_title: meta_title(server),
        title_suffix: "",
        meta_description: meta_description(server),
        canonical_url: McpRegistryWeb.Endpoint.url() <> server_path(server),
        noindex: server.status != "active",
        official_url:
          if(server.synced_at, do: McpRegistry.OfficialRegistry.server_url(server.name)),
        server: server,
        short_name: Server.short_name(server),
        namespace: String.trim_trailing(Server.namespace(server), "/"),
        package_manager_options: Install.package_manager_options(server),
        clients: Clients.configs(server),
        manifest: Jason.encode!(Manifest.to_map(server), pretty: true),
        article_html: article_html,
        website_title: nil,
        website_description: nil,
        readme_html: nil,
        readme_url: nil,
        remote_loading: true
      )

    socket =
      if connected?(socket) do
        lv = self()

        Task.start(fn ->
          send(lv, {:remote_content, RemoteContent.fetch(server)})
        end)

        socket
      else
        assign(socket, remote_loading: false)
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:remote_content, remote}, socket) do
    # page_title/meta_description/the <h1> all keep their fixed SEO format
    # regardless of what the server's own website calls itself.
    {:noreply,
     assign(socket,
       website_title: remote.website_title,
       website_description: remote.website_description,
       readme_html: remote.readme_html,
       readme_url: remote.readme_url,
       remote_loading: false
     )}
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
                navigate={~p"/servers?q=#{@namespace}"}
                class="text-ink transition-colors hover:text-brand"
              >
                {@namespace}
              </.link>
            </li>
            <li aria-hidden="true" class="text-rule-strong">/</li>
            <li class="font-medium break-all text-brand" aria-current="page">{@short_name}</li>
          </ol>
        </nav>

        <div class="flex shrink-0 items-center gap-2">
          <.badge :if={@server.synced_at} tone="success" dot>Verified official</.badge>
          <.badge :if={is_nil(@server.synced_at) and @server.status == "active"} tone="neutral">
            Community listing
          </.badge>
          <.badge :if={@server.status == "pending"} tone="warning" dot>Pending review</.badge>
          <.badge :if={@server.status == "deprecated"} tone="danger">Deprecated</.badge>
        </div>
      </:rail>

      <div
        :if={@server.status != "active"}
        role="status"
        class="flex items-start gap-2.5 rounded-box border border-warning/30 bg-warning/5 px-4 py-3 text-sm"
      >
        <.icon name="hero-clock" class="mt-0.5 size-4 shrink-0 text-warning" />
        <p class="text-pretty">
          This listing is <b class="font-semibold">{@server.status}</b>
          and is not shown in search results{if @server.status == "pending",
            do: " until a maintainer approves it"}.
        </p>
      </div>

      <%!-- --- Identity ------------------------------------------------------ --%>
      <section class="rise flex flex-col gap-6 border-b border-rule pb-8 md:flex-row md:items-start md:justify-between">
        <div class="min-w-0 space-y-3">
          <div class="flex items-start gap-3.5">
            <.monogram name={@server.name} size="size-12 text-lg" />

            <div class="min-w-0 space-y-1">
              <h1 class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-2xl font-semibold tracking-tight text-balance">
                {meta_title(@server)}
                <span class="rounded-field border border-rule bg-surface px-2 py-0.5 font-mono text-xs font-normal text-dim">
                  v{@server.version}
                </span>
              </h1>
              <p class="font-mono text-xs break-all text-dim">{@server.name}</p>
            </div>
          </div>

          <p class="max-w-2xl text-sm leading-relaxed text-pretty text-ink/90">
            {display_description(assigns)}
          </p>

          <div class="flex flex-wrap gap-1.5 pt-1">
            <.meta_chip key="transport" value={@server.transport} tone="brand" />
            <.meta_chip :if={@server.package_registry} key="runtime" value={@server.package_registry} />
            <.meta_chip :if={@server.license} key="license" value={@server.license} />
            <.meta_chip :if={@server.tools != []} key="tools" value={length(@server.tools)} />
            <.meta_chip :if={@server.env_vars != []} key="secrets" value={length(@server.env_vars)} />
          </div>
        </div>

        <div class="flex shrink-0 flex-wrap items-center gap-2">
          <.button
            :if={@server.repository_url}
            variant="soft"
            href={@server.repository_url}
            rel="nofollow ugc noopener"
          >
            <.icon name="hero-code-bracket" class="size-4" /> Source repository
          </.button>
          <.button
            :if={@server.website_url}
            variant="soft"
            href={@server.website_url}
            rel="nofollow ugc noopener"
          >
            <.icon name="hero-globe-alt" class="size-4" /> Website
          </.button>
        </div>
      </section>

      <%!-- --- Install hub --------------------------------------------------- --%>
      <section
        :if={@clients != []}
        id="install"
        aria-labelledby="install-heading"
        class="rise scroll-mt-32 space-y-4 rounded-box border border-rule bg-surface/60 p-4 sm:p-5"
        style="--d: 80ms"
      >
        <%!-- CSS-only tabs: no round trip, and the choice survives a LiveView
              patch. Radios, labels and panels must be DIRECT siblings in one
              container -- Tailwind's peer variants compile to a sibling
              combinator, so a label nested one div deeper would never react to
              its radio, and every tab would look inert. --%>
        <div
          id="client-tabs"
          phx-update="ignore"
          phx-hook=".ClientTabs"
          class="flex flex-wrap items-center gap-x-3 gap-y-2"
        >
          <h2 id="install-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
            Target environment
          </h2>

          <input
            :for={{client, index} <- Enum.with_index(@clients)}
            type="radio"
            name="client-tab"
            id={"client-tab-#{client.id}"}
            value={client.id}
            checked={index == 0}
            class={"peer/#{client.id} sr-only"}
          />

          <label
            :for={client <- @clients}
            for={"client-tab-#{client.id}"}
            class={client_tab_class(client.id)}
          >
            {client.label}
          </label>

          <div :for={client <- @clients} class={tab_panel_class(client.id)}>
            <div class="mt-3 space-y-2">
              <div class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
                <p class="flex min-w-0 items-center gap-1.5 font-mono text-[11px] text-dim">
                  <.icon
                    name={if client.kind == :cli, do: "hero-command-line", else: "hero-code-bracket"}
                    class="size-3.5 shrink-0"
                  />
                  <span class="truncate">{client.path}</span>
                </p>
                <p :if={client.path_windows} class="font-mono text-[11px] text-dim">
                  <span class="opacity-70">windows:</span> {client.path_windows}
                </p>
              </div>

              <.code_block
                id={"client-config-#{client.id}"}
                code={client.code}
                copy_label={if client.kind == :cli, do: "Copy command", else: "Copy config"}
                max_height="max-h-96"
              />

              <p :if={client.note} class="flex items-start gap-1.5 text-xs text-pretty text-dim">
                <.icon name="hero-information-circle" class="mt-px size-3.5 shrink-0" />
                <span>
                  {client.note}
                  <a
                    href={client.docs_url}
                    rel="nofollow noopener"
                    class="whitespace-nowrap underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
                  >
                    {client.label} docs
                  </a>
                </span>
              </p>
            </div>
          </div>
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".ClientTabs">
          export default {
            mounted() {
              const COOKIE = "mcp_client"

              const saved = document.cookie
                .split("; ")
                .find(row => row.startsWith(COOKIE + "="))
                ?.split("=")[1]

              if (saved) {
                const radio = this.el.querySelector(`input[value="${CSS.escape(decodeURIComponent(saved))}"]`)
                if (radio) radio.checked = true
              }

              this.el.addEventListener("change", e => {
                if (e.target.matches('input[type="radio"]')) {
                  document.cookie = `${COOKIE}=${encodeURIComponent(e.target.value)}; path=/; max-age=31536000; SameSite=Lax`
                }
              })
            }
          }
        </script>
      </section>

      <p
        :if={@clients == []}
        class="rounded-box border border-dashed border-rule bg-surface/40 px-4 py-3 text-sm text-pretty text-dim"
      >
        This listing carries neither a published package nor a remote endpoint, so there is no
        ready-made client configuration. See the repository or website for setup instructions.
      </p>

      <%!-- --- Capabilities and metadata ------------------------------------- --%>
      <div class="grid gap-8 lg:grid-cols-12">
        <div class="min-w-0 space-y-6 lg:col-span-8">
          <div id="capabilities" phx-update="ignore" phx-hook=".ToolFilter">
            <div class="flex flex-wrap items-center gap-x-4 border-b border-rule">
              <h2 class="-mb-px border-b-2 border-brand pb-2 text-sm font-medium text-brand">
                Tools <span data-tool-count>{length(@server.tools)}</span>
                <span :if={@server.tools != []} class="text-dim">/ {length(@server.tools)}</span>
              </h2>
            </div>

            <div :if={@server.tools != []} class="mt-4 space-y-3">
              <label for="tool-filter" class="sr-only">Filter tools</label>
              <input
                id="tool-filter"
                type="search"
                data-tool-filter
                autocomplete="off"
                placeholder="Filter tools by name…"
                class="w-full rounded-field border border-rule bg-surface px-3.5 py-2 font-mono text-xs text-ink outline-none transition-colors placeholder:text-dim hover:border-rule-strong focus:border-brand [&::-webkit-search-cancel-button]:hidden"
              />

              <ul class="grid gap-2 sm:grid-cols-2">
                <li
                  :for={tool <- @server.tools}
                  data-tool={String.downcase(tool)}
                  class="group/tool flex items-center justify-between gap-2 rounded-field border border-rule bg-surface/40 px-3 py-2 transition-colors hover:border-rule-strong hover:bg-surface"
                >
                  <code class="min-w-0 truncate font-mono text-xs font-medium text-brand" title={tool}>
                    {tool}
                  </code>
                  <.badge :if={tool_kind(tool) == :mutating} tone="warning" class="shrink-0">
                    writes
                  </.badge>
                  <.badge :if={tool_kind(tool) == :readonly} tone="success" class="shrink-0">
                    reads
                  </.badge>
                </li>
              </ul>

              <p data-tool-empty hidden class="py-6 text-center text-sm text-dim">
                No tool matches that filter.
              </p>

              <p class="text-xs text-pretty text-dim">
                <b class="font-medium text-ink">reads</b>
                and <b class="font-medium text-ink">writes</b>
                are inferred from each tool's name, not from its schema — treat them as a hint and
                check the server's own documentation before granting access.
              </p>
            </div>

            <p :if={@server.tools == []} class="mt-4 text-sm text-pretty text-dim">
              This listing does not declare its tools. Connect the server and your client will
              discover them on the handshake.
            </p>
          </div>

          <script :type={Phoenix.LiveView.ColocatedHook} name=".ToolFilter">
            export default {
              mounted() {
                const input = this.el.querySelector("input[data-tool-filter]")
                if (!input) return

                const rows = Array.from(this.el.querySelectorAll("[data-tool]"))
                const count = this.el.querySelector("[data-tool-count]")
                const empty = this.el.querySelector("[data-tool-empty]")

                input.addEventListener("input", () => {
                  const q = input.value.trim().toLowerCase()
                  let shown = 0

                  for (const row of rows) {
                    const match = !q || row.dataset.tool.includes(q)
                    row.hidden = !match
                    if (match) shown++
                  }

                  if (count) count.textContent = shown
                  if (empty) empty.hidden = shown > 0
                })
              }
            }
          </script>

          <details class="group/manifest overflow-hidden rounded-box border border-rule">
            <summary class="flex cursor-pointer items-center gap-2 px-4 py-3 font-mono text-[11px] tracking-wide text-dim uppercase transition-colors hover:text-ink">
              <.icon
                name="hero-chevron-right-micro"
                class="size-3.5 transition-transform duration-200 group-open/manifest:rotate-90"
              /> server.json manifest
            </summary>
            <div class="border-t border-rule">
              <pre class="scroll-thin overflow-x-auto bg-sunken p-4 font-mono text-xs leading-relaxed"><code>{@manifest}</code></pre>
            </div>
          </details>

          <section
            :if={@article_html}
            aria-labelledby="article-heading"
            class="space-y-4 rounded-box border border-rule bg-surface/40 p-5 sm:p-6"
          >
            <div class="space-y-1">
              <h2 id="article-heading" class="text-lg font-semibold tracking-tight text-balance">
                Technical article
              </h2>
              <p
                :if={@server.article_generated_at}
                class="font-mono text-[11px] tracking-wide text-dim uppercase"
              >
                Generated {Calendar.strftime(@server.article_generated_at, "%B %d, %Y")}
              </p>
            </div>
            <div class="richtext">{raw(@article_html)}</div>
          </section>

          <section
            :if={@remote_loading}
            aria-busy="true"
            aria-label="Loading README"
            class="space-y-3"
          >
            <div class="shimmer h-3 w-40 rounded-field"></div>
            <div class="shimmer h-3 w-full rounded-field"></div>
            <div class="shimmer h-3 w-11/12 rounded-field"></div>
            <div class="shimmer h-3 w-4/5 rounded-field"></div>
            <div class="shimmer h-24 w-full rounded-box"></div>
          </section>

          <section :if={@readme_html} aria-labelledby="readme-heading" class="space-y-3">
            <h2 id="readme-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
              From the README
            </h2>
            <div class="richtext">{raw(@readme_html)}</div>
          </section>
        </div>

        <aside class="min-w-0 space-y-6 self-start lg:col-span-4 lg:sticky lg:top-32">
          <section
            :if={@server.env_vars != []}
            aria-labelledby="secrets-heading"
            class="space-y-3 rounded-box border border-rule bg-surface/30 p-4"
          >
            <h2
              id="secrets-heading"
              class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase"
            >
              <.icon name="hero-shield-check" class="size-3.5 text-brand" /> Secrets and environment
            </h2>
            <p class="text-xs text-pretty text-dim">
              This server will not start until these are set. The snippets above leave each one as a
              placeholder for you to fill in.
            </p>
            <ul class="space-y-1.5">
              <li :for={var <- @server.env_vars} class="flex items-start gap-2">
                <span class="mt-1.5 size-1 shrink-0 rounded-full bg-accent" aria-hidden="true"></span>
                <code class="font-mono text-[11px] break-all text-accent">{var}</code>
              </li>
            </ul>
          </section>

          <section
            :if={@package_manager_options != []}
            aria-labelledby="integration-heading"
            class="space-y-2"
          >
            <h2
              id="integration-heading"
              class="font-mono text-[11px] tracking-wide text-dim uppercase"
            >
              Package managers
            </h2>

            <%!-- Same CSS-only tab mechanism as the install hub above. --%>
            <div id="pkg-manager-integration" phx-update="ignore" phx-hook=".PkgManagerTabs">
              <div class="relative flex flex-wrap items-center gap-1.5 rounded-box border border-rule bg-surface/60 p-2">
                <input
                  :for={{opt, index} <- Enum.with_index(@package_manager_options)}
                  type="radio"
                  name="pkg-manager-tab"
                  id={"pkg-manager-tab-#{opt.id}"}
                  value={opt.id}
                  checked={index == 0}
                  class={"peer/#{opt.id} sr-only"}
                />

                <label
                  :for={opt <- @package_manager_options}
                  for={"pkg-manager-tab-#{opt.id}"}
                  class={tab_label_class(opt)}
                >
                  {opt.label}
                </label>

                <div :for={opt <- @package_manager_options} class={tab_panel_class(opt.id)}>
                  <pre
                    :if={opt.available}
                    class="cmd scroll-thin mt-1 overflow-x-auto rounded-box border border-rule bg-sunken py-2.5 pr-3 font-mono text-xs leading-relaxed"
                  ><code>{opt.code}</code></pre>
                  <p
                    :if={!opt.available}
                    class="mt-1 rounded-box border border-dashed border-rule bg-sunken/60 px-3 py-2.5 text-xs text-pretty text-dim"
                  >
                    Not available via {opt.label}. Try one of the other package managers above.
                  </p>
                </div>
              </div>
            </div>

            <script :type={Phoenix.LiveView.ColocatedHook} name=".PkgManagerTabs">
              export default {
                mounted() {
                  const COOKIE = "pkg_manager"

                  const read = () => document.cookie
                    .split("; ")
                    .find(row => row.startsWith(COOKIE + "="))
                    ?.split("=")[1]

                  const saved = read()
                  if (saved) {
                    const radio = this.el.querySelector(`input[value="${CSS.escape(decodeURIComponent(saved))}"]`)
                    if (radio) radio.checked = true
                  }

                  this.el.addEventListener("change", e => {
                    if (e.target.matches('input[type="radio"]')) {
                      document.cookie = `${COOKIE}=${encodeURIComponent(e.target.value)}; path=/; max-age=31536000; SameSite=Lax`
                    }
                  })
                }
              }
            </script>
          </section>

          <section :if={@server.tags != []} aria-labelledby="tags-heading" class="space-y-2">
            <h2 id="tags-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
              Tags
            </h2>
            <ul class="flex flex-wrap gap-1.5">
              <li :for={tag <- @server.tags}>
                <.link
                  navigate={~p"/servers?tag=#{tag}"}
                  class="block rounded-full border border-rule px-2.5 py-1 font-mono text-[11px] text-dim transition-colors hover:border-brand/40 hover:bg-surface hover:text-ink"
                >
                  #{tag}
                </.link>
              </li>
            </ul>
          </section>

          <section aria-labelledby="details-heading" class="space-y-2">
            <h2 id="details-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
              Registry record
            </h2>

            <.list>
              <:item title="Transport">{@server.transport}</:item>
              <:item :if={@server.remote_url} title="Endpoint">
                <a href={@server.remote_url} class={meta_link_class()} rel="nofollow ugc noopener">
                  {@server.remote_url}
                </a>
              </:item>
              <:item :if={@server.package_identifier} title="Package">
                <span class="text-dim">{@server.package_registry}</span>
                <code class="break-all">{@server.package_identifier}</code>
              </:item>
              <:item :if={@server.repository_url} title="Repository">
                <a href={@server.repository_url} class={meta_link_class()} rel="nofollow ugc noopener">
                  {@server.repository_url}
                </a>
              </:item>
              <:item :if={@server.website_url} title="Website">
                <a href={@server.website_url} class={meta_link_class()} rel="nofollow ugc noopener">
                  {@server.website_url}
                </a>
              </:item>
              <:item :if={@website_title} title="Website title">{@website_title}</:item>
              <:item :if={@website_description} title="Website description">
                <span class="text-pretty text-dim">{@website_description}</span>
              </:item>
              <:item :if={@server.license} title="License">{@server.license}</:item>
              <:item :if={@server.synced_at} title="Official registry">
                <a href={@official_url} class={meta_link_class()} rel="noopener">
                  Listed{synced_phrase(@server.synced_at)}
                </a>
              </:item>
              <:item title="API">
                <a href={api_server_path(@server)} class={[meta_link_class(), "font-mono text-xs"]}>
                  {api_server_path(@server)}
                </a>
              </:item>
            </.list>
          </section>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  # A tool's name is the only thing the registry stores about it -- there are no
  # schemas here -- so read/write is inferred from the leading verb and shown as
  # a hint, with the page saying so. An unrecognised verb gets no badge rather
  # than a guess.
  @mutating_verbs ~w(create update delete remove write set add insert put patch
                     send post publish merge push upload move rename execute run
                     start stop restart cancel close edit append clear reset
                     revoke assign apply install uninstall import sync)

  @readonly_verbs ~w(get list search read fetch find query describe show view
                     lookup count check resolve inspect export download browse
                     status has is)

  defp tool_kind(tool) do
    verb =
      tool
      |> String.downcase()
      |> String.split(~r/[^a-z0-9]+/, trim: true)
      |> List.first()

    cond do
      verb in @mutating_verbs -> :mutating
      verb in @readonly_verbs -> :readonly
      true -> :unknown
    end
  end

  # The radio is sr-only, so its focus ring has to be drawn on the label.
  defp client_tab_class(id) do
    [
      "cursor-pointer rounded-[0.3125rem] px-3 py-1 font-mono text-xs transition-colors duration-200",
      "text-dim hover:text-ink",
      "peer-focus-visible/#{id}:ring-2 peer-focus-visible/#{id}:ring-brand",
      "peer-checked/#{id}:bg-surface peer-checked/#{id}:text-ink peer-checked/#{id}:shadow-sm"
    ]
  end

  defp tab_label_class(%{id: id, available: available}) do
    [
      "cursor-pointer rounded-field border px-2.5 py-1 font-mono text-xs transition-colors duration-200",
      "peer-focus-visible/#{id}:ring-2 peer-focus-visible/#{id}:ring-brand",
      "peer-checked/#{id}:border-rule-strong peer-checked/#{id}:bg-canvas peer-checked/#{id}:text-ink",
      if(available,
        do: "border-transparent text-dim hover:border-rule-strong hover:text-ink",
        else: "border-dashed border-transparent text-dim/60 hover:border-rule hover:text-dim"
      )
    ]
  end

  defp tab_panel_class(id), do: "hidden w-full peer-checked/#{id}:block"

  defp meta_link_class do
    "break-all underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
  end

  defp meta_title(server), do: "#{server.title} MCP"

  defp meta_description(server) do
    name = server.title
    company = Server.company_name(server)

    "#{name} MCP server integration.  #{company} #{name} MCP server.  " <>
      "How to integrate with Claude #{name} using MCP and Cursor #{name} using MCP " <>
      "so I can use them in Claude Code and Grok Bot."
  end

  defp display_description(%{website_description: desc}) when is_binary(desc) and desc != "",
    do: desc

  defp display_description(%{server: server}), do: server.description

  defp synced_phrase(%DateTime{} = at) do
    minutes = max(DateTime.diff(DateTime.utc_now(), at, :minute), 0)

    ago =
      cond do
        minutes < 1 -> "just now"
        minutes < 60 -> "#{minutes} min ago"
        minutes < 48 * 60 -> "#{div(minutes, 60)} h ago"
        true -> "#{div(minutes, 1440)} days ago"
      end

    ", synced #{ago}"
  end

  defp markdown_to_html(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown, escape: true) do
      {:ok, html, _warnings} -> html
      {:error, _html, _warnings} -> nil
    end
  end

  defp markdown_to_html(_), do: nil
end
