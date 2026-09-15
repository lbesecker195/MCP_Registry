defmodule McpRegistryWeb.ServerLive.Show do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Install, Manifest, RemoteContent, Server}

  @impl true
  def mount(%{"name" => segments}, _session, socket) do
    server = Registry.get_server!(Enum.join(segments, "/"))

    socket =
      assign(socket,
        page_title: server.title,
        noindex: server.status != "active",
        official_url:
          if(server.synced_at, do: McpRegistry.OfficialRegistry.server_url(server.name)),
        server: server,
        short_name: Server.short_name(server),
        snippets: Install.snippets(server),
        manifest: Jason.encode!(Manifest.to_map(server), pretty: true),
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
    title = remote.website_title || socket.assigns.server.title

    {:noreply,
     assign(socket,
       page_title: title,
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
        {display_title(assigns)}
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
            <p :if={@server.repository_url} class="text-xs text-base-content/60">
              Opening of the GitHub README (through the paragraph that crosses 200 words).
              <a href={@server.repository_url} class="link" rel="nofollow ugc noopener">View repository</a>
            </p>
          </div>
        </div>

        <aside>
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

  defp display_title(%{website_title: title}) when is_binary(title) and title != "", do: title
  defp display_title(%{server: server}), do: server.title

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
end
