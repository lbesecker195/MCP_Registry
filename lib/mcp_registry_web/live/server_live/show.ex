defmodule McpRegistryWeb.ServerLive.Show do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Install, Manifest, RemoteContent, Server}

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
        noindex: server.status != "active",
        official_url:
          if(server.synced_at, do: McpRegistry.OfficialRegistry.server_url(server.name)),
        server: server,
        short_name: Server.short_name(server),
        snippets: Install.snippets(server),
        package_manager_options: Install.package_manager_options(server),
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
    <Layouts.app flash={@flash}>
      <div class="breadcrumbs text-sm">
        <ul>
          <li><.link navigate={~p"/"}>Servers</.link></li>
          <li class="font-mono">{@server.name}</li>
        </ul>
      </div>

      <div :if={@server.status != "active"} class="alert alert-warning">
        <.icon name="hero-clock" class="size-5" />
        <span>
          This listing is <b>{@server.status}</b>
          and is not shown in search results{if @server.status ==
                                                  "pending",
                                                do: " until a maintainer approves it"}.
        </span>
      </div>

      <.header>
        {meta_title(@server)}
        <:subtitle>
          <span class="font-mono">{@server.name}</span> &middot; v{@server.version}
        </:subtitle>
        <:actions>
          <span class={["badge", Layouts.transport_badge(@server.transport)]}>{@server.transport}</span>
        </:actions>
      </.header>

      <p class="text-base leading-relaxed">{display_description(assigns)}</p>

      <p
        :if={@server.synced_at}
        id="official-provenance"
        class="text-sm text-base-content/70 flex items-center gap-2"
      >
        <.icon name="hero-check-badge" class="size-4 text-success" />
        <span>
          Listed in the <a href={@official_url} class="link" rel="noopener">official MCP Registry</a>{synced_phrase(
            @server.synced_at
          )}.
        </span>
      </p>

      <div :if={@server.tags != []} class="flex flex-wrap gap-2">
        <.link :for={tag <- @server.tags} navigate={~p"/?tag=#{tag}"} class="badge badge-ghost">
          {tag}
        </.link>
      </div>

      <section class="grid gap-8 md:grid-cols-[3fr_2fr]">
        <div class="space-y-6">
          <p :if={@snippets == []} class="text-sm text-base-content/70">
            There's no ready-made install snippet for this package type yet. See the repository or
            website for setup instructions.
          </p>

          <div :for={snippet <- @snippets} class="space-y-2">
            <h3 class="font-semibold">{snippet.label}</h3>
            <pre class="bg-base-300 rounded-box p-4 text-xs overflow-x-auto"><code>{snippet.code}</code></pre>
          </div>

          <div :if={@server.tools != []} class="space-y-2">
            <h3 class="font-semibold">Tools ({length(@server.tools)})</h3>
            <div class="flex flex-wrap gap-1">
              <code :for={tool <- @server.tools} class="badge badge-outline font-mono">{tool}</code>
            </div>
          </div>

          <details class="collapse collapse-arrow bg-base-200">
            <summary class="collapse-title font-semibold">server.json manifest</summary>
            <div class="collapse-content">
              <pre class="text-xs overflow-x-auto"><code>{@manifest}</code></pre>
            </div>
          </details>

          <div
            :if={@article_html}
            class="prose prose-sm max-w-none rounded-box bg-base-100 border border-base-300 p-6 my-6"
          >
            <h3 class="font-semibold mb-4">Technical Article</h3>
            <div class={[
              "leading-relaxed prose prose-sm",
              "[&_a]:link [&_pre]:bg-base-300 [&_pre]:rounded-box [&_pre]:p-3 [&_pre]:overflow-x-auto",
              "[&_code]:font-mono [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5",
              "[&_h2]:text-lg [&_h2]:font-bold [&_h2]:mt-6 [&_h2]:mb-3",
              "[&_h3]:text-base [&_h3]:font-semibold [&_h3]:mt-4 [&_h3]:mb-2"
            ]}>
              {raw(@article_html)}
            </div>
            <p :if={@server.article_generated_at} class="text-xs text-base-content/60 mt-4">
              Article generated on {Calendar.strftime(@server.article_generated_at, "%B %d, %Y")}
            </p>
          </div>

          <div :if={@remote_loading} class="text-sm text-base-content/60">
            Loading README…
          </div>

          <div :if={@readme_html} class="space-y-2">
            <h3 class="font-semibold">From the README</h3>
            <div class={[
              "text-sm leading-relaxed space-y-3",
              "[&_a]:link [&_pre]:bg-base-300 [&_pre]:rounded-box [&_pre]:p-3 [&_pre]:overflow-x-auto",
              "[&_code]:font-mono [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5"
            ]}>
              {raw(@readme_html)}
            </div>
          </div>
        </div>

        <aside>
          <div
            :if={@package_manager_options != []}
            class="mb-6"
            id="pkg-manager-integration"
            phx-update="ignore"
            phx-hook=".PkgManagerTabs"
          >
            <h3 class="font-semibold mb-2">Integration</h3>
            <div class="tabs tabs-box">
              <%= for {opt, index} <- Enum.with_index(@package_manager_options) do %>
                <input
                  type="radio"
                  name="pkg-manager-tab"
                  class="tab"
                  aria-label={opt.label}
                  value={opt.id}
                  checked={index == 0}
                  id={"pkg-manager-tab-#{opt.id}"}
                />
                <div class="tab-content bg-base-100 border-base-300 p-3">
                  <pre class="text-xs overflow-x-auto"><code>{opt.code}</code></pre>
                </div>
              <% end %>
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
          </div>

          <.list>
            <:item title="Transport">{@server.transport}</:item>
            <:item :if={@server.remote_url} title="Endpoint">
              <a href={@server.remote_url} class="link break-all" rel="nofollow ugc noopener">{@server.remote_url}</a>
            </:item>
            <:item :if={@server.package_identifier} title="Package">
              {@server.package_registry}: <code>{@server.package_identifier}</code>
            </:item>
            <:item :if={@server.env_vars != []} title="Environment">
              <code :for={var <- @server.env_vars} class="block">{var}</code>
            </:item>
            <:item :if={@server.repository_url} title="Repository">
              <a href={@server.repository_url} class="link break-all" rel="nofollow ugc noopener">
                {@server.repository_url}
              </a>
            </:item>
            <:item :if={@server.website_url} title="Website">
              <a href={@server.website_url} class="link break-all" rel="nofollow ugc noopener">
                {@server.website_url}
              </a>
            </:item>
            <:item :if={@website_title} title="Website title">{@website_title}</:item>
            <:item :if={@website_description} title="Website description">
              <span class="text-sm">{@website_description}</span>
            </:item>
            <:item :if={@server.license} title="License">{@server.license}</:item>
            <:item title="API">
              <a href={api_server_path(@server)} class="link font-mono text-xs break-all">
                {api_server_path(@server)}
              </a>
            </:item>
          </.list>
        </aside>
      </section>
    </Layouts.app>
    """
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
