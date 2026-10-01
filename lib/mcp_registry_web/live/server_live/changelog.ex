defmodule McpRegistryWeb.ServerLive.Changelog do
  @moduledoc """
  A listing's changelog: `/servers/:namespace/:name/changelog`, and one kind of
  change at `/servers/:namespace/:name/changelog/:kind`.

  Built from `McpRegistry.Changes`, which records what the official sync and
  the prober notice is different from last time. Like the other silos, a page
  exists only where there is something on it: a listing with no recorded
  change redirects to the listing, and so does a kind it has none of.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Changes
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  # Past this many items, one change lists the first few and says how many more.
  @shown 40

  @impl true
  def mount(%{"namespace" => namespace, "name" => name}, _session, socket) do
    server = Registry.get_server!(namespace <> "/" <> name)

    {:ok,
     socket
     |> assign(:server, server)
     |> assign(:short_name, Server.short_name(server))
     |> assign(:kinds, Changes.kinds_for_server(server))
     |> assign(:noindex, server.status != "active")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{server: server, kinds: kinds} = socket.assigns
    kind = params["kind"] && Changes.from_slug(params["kind"])

    cond do
      kinds == %{} ->
        {:noreply, push_navigate(socket, to: server_path(server))}

      params["kind"] && (is_nil(kind) or not Map.has_key?(kinds, kind)) ->
        {:noreply, push_navigate(socket, to: changelog_path(server))}

      true ->
        changes = Changes.for_server(server, kind)

        {:noreply,
         socket
         |> assign(:kind, kind)
         |> assign(:days, by_day(changes))
         |> assign(:total, if(kind, do: kinds[kind], else: kinds |> Map.values() |> Enum.sum()))
         |> assign(:page_title, title(server, kind))
         |> assign(:meta_description, description(server, kind, changes))
         |> assign(:canonical_url, McpRegistryWeb.Endpoint.url() <> changelog_path(server, kind))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true} sponsors={true}>
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
            <li>
              <.link
                navigate={changelog_path(@server)}
                class={
                  if @kind, do: "transition-colors hover:text-ink", else: "font-medium text-brand"
                }
              >
                changelog
              </.link>
            </li>
            <li :if={@kind} aria-hidden="true" class="text-rule-strong">/</li>
            <li :if={@kind} class="font-medium text-brand">{Changes.label(@kind)}</li>
          </ol>
        </nav>
      </:rail>

      <header class="rise space-y-4 border-b border-rule pb-6">
        <div class="flex items-start gap-3.5">
          <.server_logo server={@server} size="size-12 text-lg" />
          <div class="min-w-0 space-y-1">
            <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
              {heading(@server, @kind)}
            </h1>
            <p class="font-mono text-xs break-all text-dim">{@server.name}</p>
          </div>
        </div>
        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
          {count_phrase(@total)} recorded. MCP Harbor re-reads this listing from the official
          registry every six hours and asks the live server what it exposes, and keeps what
          changed between one look and the next.
        </p>

        <nav aria-label="Kinds of change" class="flex flex-wrap gap-1.5">
          <.link
            navigate={changelog_path(@server)}
            class={chip_class(is_nil(@kind))}
          >
            All · {@kinds |> Map.values() |> Enum.sum()}
          </.link>
          <.link
            :for={{kind, n} <- Enum.sort(@kinds)}
            navigate={changelog_path(@server, kind)}
            class={chip_class(@kind == kind)}
          >
            {Changes.label(kind)} · {n}
          </.link>
        </nav>
      </header>

      <section :for={{day, changes} <- @days} class="space-y-3">
        <h2 class="font-mono text-[11px] tracking-wide text-dim uppercase">
          <time datetime={Date.to_iso8601(day)}>{Calendar.strftime(day, "%-d %B %Y")}</time>
        </h2>
        <ul class="space-y-2.5">
          <li :for={change <- changes}>
            <.change_card change={change} server={@server} />
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

  attr :change, :map, required: true
  attr :server, :map, required: true

  @doc false
  def change_card(assigns) do
    ~H"""
    <article class="space-y-2 rounded-box border border-rule bg-surface/40 p-3.5">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <.badge tone="neutral">{Changes.label(@change.kind)}</.badge>
        <span class="font-mono text-[11px] text-dim">{summary(@change)}</span>
      </div>

      <dl :if={@change.fields != %{}} class="space-y-1.5">
        <div :for={{field, [old, new]} <- Enum.sort(@change.fields)} class="text-xs">
          <dt class="font-mono text-[11px] text-dim">{field}</dt>
          <dd class="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 break-words">
            <del class="text-dim decoration-danger/60">{shown_value(old)}</del>
            <span aria-hidden="true" class="text-rule-strong">→</span>
            <ins class="text-ink no-underline">{shown_value(new)}</ins>
          </dd>
        </div>
      </dl>

      <p :if={@change.document_url} class="font-mono text-[11px] break-all text-dim">
        <a
          href={@change.document_url}
          rel="nofollow noopener"
          class="underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
        >
          {@change.document_url}
        </a>
      </p>

      <%!-- A document changes by lines of prose, which read as a diff, not as chips. --%>
      <pre
        :if={@change.document_url && (@change.added != [] or @change.removed != [])}
        class="scroll-thin max-h-80 overflow-auto rounded-field border border-rule bg-sunken p-3 font-mono text-[11px] leading-relaxed whitespace-pre-wrap"
      ><span :for={line <- Enum.take(@change.removed, shown())} class="block text-dim line-through decoration-danger/50"><span class="text-danger no-underline" aria-label="removed">− </span>{line}</span><span :for={line <- Enum.take(@change.added, shown())} class="block text-ink"><span class="text-success" aria-label="added">+ </span>{line}</span></pre>

      <ul
        :if={is_nil(@change.document_url) and (@change.added != [] or @change.removed != [])}
        class="flex flex-wrap gap-1.5"
      >
        <li :for={item <- Enum.take(@change.added, shown())}>
          <span class="inline-block rounded-full border border-success/40 px-2 py-0.5 font-mono text-[11px] break-all text-ink">
            <span class="text-success" aria-label="added">+</span> {item}
          </span>
        </li>
        <li :for={item <- Enum.take(@change.removed, shown())}>
          <span class="inline-block rounded-full border border-danger/40 px-2 py-0.5 font-mono text-[11px] break-all text-dim line-through">
            <span class="text-danger no-underline" aria-label="removed">−</span> {item}
          </span>
        </li>
      </ul>
      <p
        :if={length(@change.added) + length(@change.removed) > 2 * shown()}
        class="text-[11px] text-dim"
      >
        Showing the first {shown()} of each.
      </p>
    </article>
    """
  end

  defp shown, do: @shown

  defp by_day(changes) do
    changes
    |> Enum.group_by(&DateTime.to_date(&1.inserted_at))
    |> Enum.sort_by(fn {day, _} -> day end, {:desc, Date})
  end

  defp summary(%{fields: fields}) when map_size(fields) > 0,
    do: "#{map_size(fields)} field#{if map_size(fields) == 1, do: "", else: "s"} changed"

  defp summary(%{added: added, removed: removed}) do
    [
      added != [] && "+#{length(added)}",
      removed != [] && "−#{length(removed)}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join("  ")
  end

  defp shown_value(nil), do: "—"

  defp shown_value(list) when is_list(list),
    do: if(list == [], do: "none", else: Enum.join(list, ", "))

  defp shown_value(value), do: to_string(value)

  defp heading(server, nil), do: "#{server.title} changelog"
  defp heading(server, kind), do: "#{server.title} #{Changes.label(kind)} changelog"

  defp title(server, nil),
    do: "#{server.title} MCP Server Changelog — tools, prompts, resources and version history"

  defp title(server, kind),
    do: "#{server.title} MCP #{Changes.label(kind)} Changelog — what was added and removed"

  defp description(server, kind, changes) do
    first = changes |> List.last() |> then(&(&1 && DateTime.to_date(&1.inserted_at)))
    since = if first, do: " since #{Calendar.strftime(first, "%-d %B %Y")}", else: ""

    what =
      if kind,
        do: "#{Changes.label(kind)} changes",
        else: "tools added and removed, prompt and resource changes, and server.json updates"

    "Every recorded change to the #{server.title} MCP server#{since}: #{what}, " <>
      "read from the server itself and the official MCP registry."
  end

  defp count_phrase(1), do: "1 change"
  defp count_phrase(n), do: "#{n} changes"

  defp chip_class(active?) do
    [
      "rounded-full border px-2.5 py-1 font-mono text-[11px] transition-colors",
      if(active?,
        do: "border-brand/50 bg-brand/10 text-ink",
        else: "border-rule text-dim hover:border-brand/40 hover:bg-surface hover:text-ink"
      )
    ]
  end
end
