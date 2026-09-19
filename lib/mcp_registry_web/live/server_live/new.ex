defmodule McpRegistryWeb.ServerLive.New do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  @meta_description "Submit an MCP server to the MCP Registry. Add a listing through the form, " <>
                      "the JSON API or the MCP endpoint; a maintainer reviews it before it appears in search."

  @impl true
  def mount(_params, _session, socket) do
    base = McpRegistryWeb.Endpoint.url()

    {:ok,
     assign(socket,
       page_title: "Submit a server",
       meta_description: @meta_description,
       canonical_url: base <> "/submit",
       mcp_url: base <> "/mcp",
       submit_command:
         "curl -X POST #{base}/api/v0/servers -H 'content-type: application/json' -d @server.json",
       form: to_form(Registry.change_server(%Server{})),
       transports: Server.transports(),
       registries: Server.registries()
     )}
  end

  @impl true
  def handle_event("validate", %{"server" => params}, socket) do
    changeset = Registry.change_server(%Server{}, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"server" => params}, socket) do
    case Registry.create_server(params, status: "pending", source: "web") do
      {:ok, server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thanks! #{server.name} is submitted and pending review.")
         |> push_navigate(to: server_path(server))}

      {:error, :queue_full} ->
        {:noreply,
         put_flash(socket, :error, "The review queue is full right now. Please try again later.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:submit}>
      <.header>
        Submit an MCP server
        <:subtitle>
          A maintainer reviews every listing before it appears in search, so the catalogue stays
          free of endpoints that no longer answer.
        </:subtitle>
      </.header>

      <section
        aria-labelledby="agent-path"
        class="rise rounded-box border border-rule bg-glow p-5 sm:p-6"
      >
        <p class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase">
          <.icon name="hero-command-line" class="size-4 text-brand" /> For agents
        </p>
        <h2 id="agent-path" class="mt-2.5 text-lg font-semibold tracking-tight text-balance">
          Skip the form
        </h2>
        <p class="mt-2 max-w-2xl text-sm text-pretty text-dim">
          This page is for people. An agent posts the same listing as JSON, or calls the
          <code class="font-mono text-ink">submit_server</code>
          tool on the MCP endpoint at <span class="font-mono break-all text-ink">{@mcp_url}</span>.
          Both land in the same review queue.
        </p>

        <.copy_command id="submit-endpoint" command={@submit_command} class="mt-4" />

        <ul class="mt-4 flex flex-wrap gap-x-5 gap-y-2 font-mono text-xs">
          <li>
            <.link
              href={~p"/llms.txt"}
              class="inline-flex items-center gap-1 text-dim underline decoration-rule-strong underline-offset-4 transition-colors hover:text-ink hover:decoration-brand"
            >
              llms.txt <.icon name="hero-arrow-up-right-micro" class="size-3.5" />
            </.link>
          </li>
          <li>
            <.link
              href={~p"/api/v0/servers"}
              class="inline-flex items-center gap-1 text-dim underline decoration-rule-strong underline-offset-4 transition-colors hover:text-ink hover:decoration-brand"
            >
              JSON API <.icon name="hero-arrow-up-right-micro" class="size-3.5" />
            </.link>
          </li>
        </ul>
      </section>

      <p class="text-xs text-dim">
        Fields marked <span class="font-mono text-ink">*</span>
        are required. The rest are optional, and every one of them makes the listing easier to find.
      </p>

      <.form for={@form} id="server-form" phx-change="validate" phx-submit="save" class="space-y-10">
        <.field_group
          index="01"
          title="Identity"
          caption="How the server is addressed, and what the listing says it does."
        >
          <.input
            field={@form[:name]}
            label="Name *"
            required
            hint="Reverse-DNS namespace, a slash, then a short name."
            placeholder="io.github.acme/weather"
            class={name_field_classes()}
          />
          <.input
            field={@form[:title]}
            label="Title *"
            required
            hint="The heading people see in search results."
            placeholder="Weather"
          />
          <div class="sm:col-span-2">
            <.input
              field={@form[:description]}
              type="textarea"
              label="Description *"
              required
              hint="One or two sentences: what it does, and what it needs to run."
              placeholder="Forecasts and severe-weather alerts by location. Needs a WEATHER_API_KEY."
            />
          </div>
        </.field_group>

        <.field_group
          index="02"
          title="Transport"
          caption="How a client reaches the server. stdio runs it locally; streamable-http and sse are hosted."
        >
          <.input
            field={@form[:version]}
            label="Version *"
            required
            hint="The release this listing describes."
            placeholder="0.1.0"
          />
          <.input
            field={@form[:transport]}
            type="select"
            label="Transport *"
            required
            options={@transports}
            hint="Pick the primary one if the server ships both."
          />
          <div class="sm:col-span-2">
            <.input
              field={@form[:remote_url]}
              type="url"
              label="Remote URL"
              hint="Required for streamable-http and sse."
              placeholder="https://mcp.example.com/mcp"
            />
          </div>
        </.field_group>

        <.field_group
          index="03"
          title="Package"
          caption="Where a stdio server is installed from, and what it expects in the environment."
        >
          <.input
            field={@form[:package_registry]}
            type="select"
            label="Registry"
            prompt="No package"
            options={@registries}
            hint="Required for stdio servers."
          />
          <.input
            field={@form[:package_identifier]}
            label="Package identifier"
            hint="Spelled the way the registry spells it."
            placeholder="@acme/weather-mcp"
          />
          <div class="sm:col-span-2">
            <.input
              id="server_env_vars"
              name="server[env_vars]"
              value={list_value(@form[:env_vars])}
              errors={list_errors(@form[:env_vars])}
              label="Environment variables"
              hint="Comma-separated. Variable names only -- never paste a key."
              placeholder="WEATHER_API_KEY, WEATHER_API_BASE"
            />
          </div>
        </.field_group>

        <.field_group
          index="04"
          title="Capabilities"
          caption="What the server exposes. This is most of what search matches on."
        >
          <div class="sm:col-span-2">
            <.input
              id="server_tools"
              name="server[tools]"
              value={list_value(@form[:tools])}
              errors={list_errors(@form[:tools])}
              label="Tools"
              hint="Comma-separated tool names, as the server registers them."
              placeholder="get_forecast, get_alerts"
            />
          </div>
          <div class="sm:col-span-2">
            <.input
              id="server_tags"
              name="server[tags]"
              value={list_value(@form[:tags])}
              errors={list_errors(@form[:tags])}
              label="Tags"
              hint="Comma-separated, up to 12. Lowercased on save."
              placeholder="weather, data"
            />
          </div>
        </.field_group>

        <.field_group
          index="05"
          title="Links"
          caption="Where the source, the docs and the terms live."
        >
          <div class="sm:col-span-2">
            <.input
              field={@form[:repository_url]}
              type="url"
              label="Repository"
              hint="A github.com URL also pulls the README onto the listing page."
              placeholder="https://github.com/acme/weather-mcp"
            />
          </div>
          <.input
            field={@form[:website_url]}
            type="url"
            label="Website"
            placeholder="https://acme.dev/weather"
          />
          <.input field={@form[:license]} label="License" hint="SPDX identifier." placeholder="MIT" />
        </.field_group>

        <%!-- Pinned on phones so the primary action survives a 14-field scroll;
              from sm it settles into the flow at the end of the form. --%>
        <div class="sticky bottom-0 z-10 -mx-4 flex flex-col gap-3 border-t border-rule bg-canvas/90 px-4 py-4 backdrop-blur-md sm:static sm:mx-0 sm:flex-row sm:items-center sm:justify-between sm:rounded-box sm:border sm:bg-surface/40 sm:px-5">
          <p class="text-xs text-pretty text-dim">
            Submitting queues the listing for review. Nothing is published automatically.
          </p>
          <.button
            variant="primary"
            phx-disable-with="Submitting…"
            class="w-full shrink-0 sm:w-auto"
          >
            Submit for review <.icon name="hero-arrow-right-micro" class="size-4" />
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  # One titled section of the form. A real <fieldset>/<legend> pair, so the
  # grouping survives into the accessibility tree; the hairline sits on the
  # inner grid rather than the fieldset, because a border on the fieldset gets
  # notched by the legend.
  attr :index, :string, required: true
  attr :title, :string, required: true
  attr :caption, :string, required: true
  slot :inner_block, required: true

  defp field_group(assigns) do
    ~H"""
    <fieldset>
      <legend class="font-mono text-[11px] tracking-wide uppercase">
        <span class="text-brand">{@index}</span> <span class="text-dim">{@title}</span>
      </legend>
      <p class="mt-1.5 max-w-xl text-sm text-pretty text-dim">{@caption}</p>
      <div class="mt-4 grid gap-x-6 gap-y-5 border-t border-rule pt-6 sm:grid-cols-2">
        {render_slot(@inner_block)}
      </div>
    </fieldset>
    """
  end

  # The default control classes, in mono: `name` is a lowercase identifier and
  # the namespace/short-name split is easier to read while it is being typed.
  defp name_field_classes do
    [
      "w-full rounded-field border border-rule bg-surface px-3 py-2",
      "font-mono text-sm text-ink outline-none transition-colors",
      "placeholder:text-dim hover:border-rule-strong focus:border-brand"
    ]
  end

  # List fields are edited as comma-separated text but stored as arrays.
  defp list_value(%Phoenix.HTML.FormField{value: value}) do
    value |> List.wrap() |> Enum.join(", ")
  end

  defp list_errors(%Phoenix.HTML.FormField{} = field) do
    if used_input?(field), do: Enum.map(field.errors, &translate_error/1), else: []
  end
end
