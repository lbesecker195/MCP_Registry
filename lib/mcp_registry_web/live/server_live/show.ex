defmodule McpRegistryWeb.ServerLive.Show do
  @moduledoc """
  One listing at `/servers/*name`, laid out as an install console.

  The page answers three questions in the order people ask them: what is this
  (the rail and the identity block), how do I wire it up (the install hub), and
  what can it actually do (the capability explorer and the spec rail). Long-form
  content -- the generated article and the upstream README -- sits below all of
  that, always rendered rather than hidden behind a tab, because it is what the
  page ranks on.

  Tabs and the client switcher are LiveView state rather than CSS, so the
  install hub can rewrite the snippet as you type a secret into it. Nothing
  typed there is stored: it lives in this process's assigns for the life of the
  connection, is filtered out of the logs in `config/config.exs`, and is gone on
  reload.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Clients, Install, Manifest, RemoteContent, Server}

  @impl true
  def mount(%{"name" => segments}, _session, socket) do
    server = Registry.get_server!(Enum.join(segments, "/"))
    clients = Clients.configs(server)

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
        manifest: Jason.encode!(Manifest.to_map(server), pretty: true),
        article_html: markdown_to_html(server.article_content),
        clients: clients,
        selected_client: default_client(clients),
        active_tab: "tools",
        tool_query: "",
        tools: decorate_tools(server.tools),
        secrets: Map.new(server.env_vars, &{&1, ""}),
        website_title: nil,
        website_description: nil,
        readme_html: nil,
        readme_url: nil,
        remote_loading: true
      )

    socket =
      if connected?(socket) do
        lv = self()
        Task.start(fn -> send(lv, {:remote_content, RemoteContent.fetch(server)}) end)
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
  def handle_event("select_client", %{"client" => id}, socket) do
    {:noreply, assign(socket, :selected_client, id)}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("filter_tools", %{"query" => query}, socket) do
    {:noreply, assign(socket, :tool_query, query)}
  end

  # Only keys the listing actually declares are kept, so nothing arbitrary can
  # be pushed into a rendered snippet.
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
          <.badge :if={is_nil(@server.synced_at) and @server.status == "active"}>
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

            <%!-- The version sits beside the <h1>, not inside it: the heading
                  is the page's SEO title and stays exactly that string. --%>
            <div class="min-w-0 space-y-1">
              <div class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                <h1 class="text-2xl font-semibold tracking-tight text-balance">
                  {meta_title(@server)}
                </h1>
                <span class="rounded-field border border-rule bg-surface px-2 py-0.5 font-mono text-xs font-normal text-dim">
                  v{@server.version}
                </span>
              </div>
              <p class="font-mono text-xs break-all text-dim">{@server.name}</p>
            </div>
          </div>

          <p class="max-w-2xl text-sm leading-relaxed text-pretty text-ink/90">
            {display_description(assigns)}
          </p>

          <div class="flex flex-wrap gap-1.5 pt-1">
            <.meta_chip key="transport" value={@server.transport} tone="brand" />
            <.meta_chip
              :if={@server.package_registry}
              key="runtime"
              value={@server.package_registry}
            />
            <.meta_chip :if={@server.license} key="license" value={@server.license} />
            <.meta_chip :if={@tools != []} key="tools" value={length(@tools)} />
          </div>
        </div>

        <div class="flex shrink-0 flex-wrap items-center gap-2">
          <.button
            :if={@server.repository_url}
            variant="soft"
            href={@server.repository_url}
            rel="nofollow ugc noopener"
          >
            <.icon name="hero-code-bracket" class="size-4" /> View source
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
        <div class="flex flex-col justify-between gap-3 border-b border-rule pb-3 sm:flex-row sm:items-center">
          <div class="flex flex-wrap items-center gap-3">
            <h2 id="install-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
              Target client
            </h2>
            <.segmented
              options={@clients}
              selected={@selected_client}
              event="select_client"
              param="client"
              label="Target client"
            />
          </div>

          <p class="flex min-w-0 items-center gap-1.5 font-mono text-[11px] text-dim">
            <.icon
              name={
                if current_client(assigns).kind == :cli,
                  do: "hero-command-line",
                  else: "hero-code-bracket"
              }
              class="size-3.5 shrink-0"
            />
            <span class="truncate" title={current_client(assigns).path}>
              {current_client(assigns).path}
            </span>
          </p>
        </div>

        <%!-- Live secret injector. Each declared variable gets its own field and
              is substituted into the snippet as you type, so the block is
              copy-and-run rather than copy-then-edit. --%>
        <form
          :if={injectable_vars(assigns) != []}
          phx-change="update_secrets"
          class="flex flex-col gap-2"
        >
          <div
            :for={var <- injectable_vars(assigns)}
            class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:gap-3"
          >
            <label
              for={"secret-#{var}"}
              class="shrink-0 font-mono text-[11px] text-accent sm:w-56 sm:truncate"
              title={var}
            >
              {var}
            </label>
            <input
              type="password"
              id={"secret-#{var}"}
              name={"secrets[#{var}]"}
              value={@secrets[var]}
              autocomplete="off"
              spellcheck="false"
              placeholder="paste to fill the snippet below"
              class="w-full min-w-0 rounded-field border border-rule bg-canvas px-3 py-1.5 font-mono text-xs text-ink outline-none transition-colors placeholder:text-dim hover:border-rule-strong focus:border-brand"
            />
          </div>
          <p class="text-[11px] text-dim">
            Held in this page only — never stored, logged, or sent anywhere but back to your screen.
          </p>
        </form>

        <.code_block
          id="client-config"
          code={rendered_config(assigns)}
          copy_label={
            if current_client(assigns).kind == :cli, do: "Copy command", else: "Copy config"
          }
          max_height="max-h-96"
        />

        <p
          :if={current_client(assigns).note}
          class="flex items-start gap-1.5 text-xs text-pretty text-dim"
        >
          <.icon name="hero-information-circle" class="mt-px size-3.5 shrink-0" />
          <span>
            {current_client(assigns).note}
            <a
              href={current_client(assigns).docs_url}
              rel="nofollow noopener"
              class="whitespace-nowrap underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
            >
              {current_client(assigns).label} docs
            </a>
          </span>
        </p>
      </section>

      <p
        :if={@clients == []}
        class="rounded-box border border-dashed border-rule bg-surface/40 px-4 py-3 text-sm text-pretty text-dim"
      >
        This listing carries neither a published package nor a remote endpoint, so there is no
        ready-made client configuration. See the repository or website for setup instructions.
      </p>

      <%!-- --- Capabilities and specs ---------------------------------------- --%>
      <div class="grid gap-8 lg:grid-cols-12">
        <div class="min-w-0 space-y-6 lg:col-span-8">
          <div class="flex gap-6 overflow-x-auto border-b border-rule">
            <.tab_button tab="tools" current={@active_tab} event="select_tab">
              Tools ({length(@tools)})
            </.tab_button>
            <.tab_button tab="environment" current={@active_tab} event="select_tab">
              Environment ({length(@server.env_vars)})
            </.tab_button>
            <.tab_button tab="manifest" current={@active_tab} event="select_tab">
              server.json
            </.tab_button>
          </div>

          <%!-- Tools --%>
          <div :if={@active_tab == "tools"} class="space-y-3">
            <form :if={@tools != []} phx-change="filter_tools" phx-submit="filter_tools">
              <label for="tool-query" class="sr-only">Filter tools</label>
              <input
                type="text"
                id="tool-query"
                name="query"
                value={@tool_query}
                phx-debounce="150"
                autocomplete="off"
                placeholder="Filter tools by name…"
                class="w-full rounded-field border border-rule bg-surface px-3.5 py-2 font-mono text-xs text-ink outline-none transition-colors placeholder:text-dim hover:border-rule-strong focus:border-brand"
              />
            </form>

            <div class="grid gap-2.5 sm:grid-cols-2">
              <article
                :for={tool <- filtered_tools(@tools, @tool_query)}
                class="space-y-1.5 rounded-box border border-rule bg-surface/40 p-3.5 transition-colors hover:border-rule-strong hover:bg-surface"
              >
                <div class="flex items-start justify-between gap-2">
                  <code class="min-w-0 font-mono text-xs font-semibold break-all text-brand">
                    {tool.name}
                  </code>
                  <.badge :if={tool.kind == :mutating} tone="warning">Mutating</.badge>
                  <.badge :if={tool.kind == :readonly} tone="success">Read-only</.badge>
                </div>
                <p class="text-[11px] text-dim">{tool.gloss}</p>
              </article>
            </div>

            <p
              :if={@tools != [] and filtered_tools(@tools, @tool_query) == []}
              class="rounded-box border border-dashed border-rule py-10 text-center text-xs text-dim"
            >
              No tool matches "{@tool_query}".
            </p>

            <p :if={@tools == []} class="text-sm text-pretty text-dim">
              This listing does not declare its tools. Connect the server and your client will
              discover them on the handshake.
            </p>

            <p :if={@tools != []} class="text-[11px] text-pretty text-dim">
              <b class="font-medium text-ink">Mutating</b>
              and <b class="font-medium text-ink">Read-only</b>
              are read off each tool's name, not its schema — a hint, not a guarantee. Check the
              server's own documentation before granting access.
            </p>
          </div>

          <%!-- Environment --%>
          <div :if={@active_tab == "environment"} class="space-y-3">
            <div :if={@server.env_vars != []} class="space-y-2">
              <p class="text-sm text-pretty text-dim">
                This server will not start until these are set. Fill them in above and every snippet
                on this page is rewritten to match.
              </p>
              <ul class="grid gap-2 sm:grid-cols-2">
                <li
                  :for={var <- @server.env_vars}
                  class="flex items-center gap-2 rounded-field border border-rule bg-surface/40 px-3 py-2"
                >
                  <.icon name="hero-shield-check" class="size-3.5 shrink-0 text-accent" />
                  <code class="min-w-0 font-mono text-[11px] break-all text-accent">{var}</code>
                </li>
              </ul>
            </div>

            <p :if={@server.env_vars == []} class="text-sm text-pretty text-dim">
              This server declares no environment variables — nothing to configure before it runs.
            </p>
          </div>

          <%!-- Manifest --%>
          <div :if={@active_tab == "manifest"}>
            <.code_block
              id="manifest-block"
              code={@manifest}
              copy_label="Copy JSON"
              max_height="max-h-[32rem]"
            />
          </div>

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
            <div class="shimmer h-24 w-full rounded-box"></div>
          </section>

          <section :if={@readme_html} aria-labelledby="readme-heading" class="space-y-3">
            <h2 id="readme-heading" class="font-mono text-[11px] tracking-wide text-dim uppercase">
              From the README
            </h2>
            <div class="richtext">{raw(@readme_html)}</div>
          </section>
        </div>

        <aside class="min-w-0 space-y-6 self-start lg:sticky lg:top-32 lg:col-span-4">
          <.panel
            :if={@server.env_vars != []}
            title="Secrets and scopes"
            icon="hero-shield-check"
          >
            <p class="text-xs text-pretty text-dim">
              The registry records which variables this server needs, not what privileges they must
              carry. Issue each one with the narrowest scope that works.
            </p>
            <ul class="space-y-1.5">
              <li :for={var <- @server.env_vars} class="flex items-center gap-2">
                <span class="size-1 shrink-0 rounded-full bg-brand" aria-hidden="true"></span>
                <code class="font-mono text-[11px] break-all text-brand">{var}</code>
              </li>
            </ul>
          </.panel>

          <.panel title="Runtime" icon="hero-cpu-chip">
            <div>
              <.spec_row label="Transport" value={@server.transport} tone="brand" />
              <.spec_row
                :if={@server.package_registry}
                label="Registry"
                value={@server.package_registry}
              />
              <.spec_row
                :if={@server.package_identifier}
                label="Package"
                value={@server.package_identifier}
              />
              <.spec_row :if={@server.license} label="License" value={@server.license} />
              <.spec_row label="Version" value={@server.version} />
              <.spec_row
                label="Provenance"
                value={if @server.synced_at, do: "Official registry", else: "Community"}
                tone={if @server.synced_at, do: "success", else: "dim"}
              />
            </div>
          </.panel>

          <.panel
            :if={@package_manager_options != []}
            title="Package managers"
            icon="hero-cube-transparent"
          >
            <div id="pkg-manager-integration" phx-update="ignore" phx-hook=".PkgManagerTabs">
              <%!-- CSS-only tabs: radios, labels and panels must be DIRECT
                    siblings, because Tailwind's peer variants compile to a
                    sibling combinator. --%>
              <div class="relative flex flex-wrap items-center gap-1.5">
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
          </.panel>

          <Layouts.sponsors />

          <.panel :if={@server.tags != []} title="Tags" icon="hero-funnel">
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
          </.panel>

          <.panel title="Registry record" icon="hero-server-stack">
            <div>
              <.spec_row :if={@server.remote_url} label="Endpoint">
                <a href={@server.remote_url} class={meta_link_class()} rel="nofollow ugc noopener">
                  {@server.remote_url}
                </a>
              </.spec_row>
              <.spec_row :if={@server.repository_url} label="Repository">
                <a href={@server.repository_url} class={meta_link_class()} rel="nofollow ugc noopener">
                  {@server.repository_url}
                </a>
              </.spec_row>
              <.spec_row :if={@website_title} label="Site title" value={@website_title} />
              <.spec_row :if={@server.synced_at} label="Synced">
                <a href={@official_url} class={meta_link_class()} rel="noopener">
                  {synced_phrase(@server.synced_at)}
                </a>
              </.spec_row>
              <.spec_row label="JSON API">
                <a href={api_server_path(@server)} class={meta_link_class()}>
                  {api_server_path(@server)}
                </a>
              </.spec_row>
            </div>
          </.panel>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  # --- Client switching ------------------------------------------------------

  defp default_client([first | _]), do: first.id
  defp default_client(_), do: nil

  defp current_client(%{clients: clients, selected_client: id}) do
    Enum.find(clients, List.first(clients), &(&1.id == id))
  end

  # Which declared variables this client's snippet actually has a slot for.
  #
  # Not simply "every variable the listing declares": a remote server's config
  # is a URL, so none of its variables appear in the snippet even though the
  # registry records them — the server expects them as headers or through its
  # own OAuth. Offering a field that substitutes into nothing would promise an
  # edit the page cannot make, so the form is driven by the snippet itself.
  defp injectable_vars(assigns) do
    client = current_client(assigns)

    if client && client.accepts_secrets do
      Enum.filter(assigns.server.env_vars, &String.contains?(client.code, "<#{&1}>"))
    else
      []
    end
  end

  # Substitution happens at render time rather than in `Clients`, so the module
  # stays a pure description of each client's shape and the secret never leaves
  # this process.
  defp rendered_config(assigns) do
    client = current_client(assigns)

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

  # --- Tools -----------------------------------------------------------------

  # A tool's name is the only thing the registry stores about it -- there are no
  # schemas here -- so the badge is read off the leading verb and the gloss is
  # the name itself, punctuation removed. Neither invents information; an
  # unrecognised verb simply gets no badge.
  @mutating_verbs ~w(create update delete remove write set add insert put patch
                     send post publish merge push upload move rename execute run
                     start stop restart cancel close edit append clear reset
                     revoke assign apply install uninstall import sync)

  @readonly_verbs ~w(get list search read fetch find query describe show view
                     lookup count check resolve inspect export download browse
                     status)

  defp decorate_tools(tools) do
    Enum.map(tools, fn tool ->
      %{name: tool, kind: tool_kind(tool), gloss: gloss(tool)}
    end)
  end

  defp tool_kind(tool) do
    verb = tool |> String.downcase() |> String.split(~r/[^a-z0-9]+/, trim: true) |> List.first()

    cond do
      verb in @mutating_verbs -> :mutating
      verb in @readonly_verbs -> :readonly
      true -> :unknown
    end
  end

  defp gloss(tool) do
    tool
    |> String.replace(~r/[_\-.]+/, " ")
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1 \\2")
    |> String.downcase()
    |> String.trim()
  end

  defp filtered_tools(tools, query) do
    case query |> to_string() |> String.trim() |> String.downcase() do
      "" -> tools
      q -> Enum.filter(tools, &String.contains?(String.downcase(&1.name), q))
    end
  end

  # --- Presentation helpers --------------------------------------------------

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

    cond do
      minutes < 1 -> "just now"
      minutes < 60 -> "#{minutes} min ago"
      minutes < 48 * 60 -> "#{div(minutes, 60)} h ago"
      true -> "#{div(minutes, 1440)} days ago"
    end
  end

  defp markdown_to_html(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown, escape: true) do
      {:ok, html, _warnings} -> html
      {:error, _html, _warnings} -> nil
    end
  end

  defp markdown_to_html(_), do: nil
end
