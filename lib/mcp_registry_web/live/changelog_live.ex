defmodule McpRegistryWeb.ChangelogLive do
  @moduledoc """
  `/changelog`: the latest recorded changes across every listing.

  The one page on the site that is different every few hours, which is the
  point -- it gives a returning reader and a crawler alike a reason to come
  back, and every entry links into the listing it changed.
  """
  use McpRegistryWeb, :live_view

  alias McpRegistry.Changes
  alias McpRegistryWeb.ServerLive.Changelog

  @impl true
  def mount(_params, _session, socket) do
    changes = Changes.recent(100)

    {:ok,
     socket
     |> assign(:days, by_day(changes))
     |> assign(:empty?, changes == [])
     |> assign(:page_title, "MCP Server Changelog — new tools, prompts, resources and versions")
     |> assign(
       :meta_description,
       "What changed across the MCP server registry: tools added and removed, new prompts and " <>
         "resources, and version and description updates, read from the servers themselves."
     )
     |> assign(:canonical_url, McpRegistryWeb.Endpoint.url() <> ~p"/changelog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:servers} wide={true}>
      <header class="rise space-y-3 border-b border-rule pb-6">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
          What changed in MCP servers
        </h1>
        <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
          The latest changes across the registry. Every listing is re-read from the official MCP
          registry every six hours, and remote servers are asked what they expose; this is what
          was different from the time before.
        </p>
      </header>

      <p
        :if={@empty?}
        class="rounded-box border border-dashed border-rule py-10 text-center text-sm text-dim"
      >
        Nothing recorded yet. Changes appear here as listings are re-read.
      </p>

      <section :for={{day, changes} <- @days} class="space-y-3">
        <h2 class="font-mono text-[11px] tracking-wide text-dim uppercase">
          <time datetime={Date.to_iso8601(day)}>{Calendar.strftime(day, "%-d %B %Y")}</time>
        </h2>
        <ul class="space-y-2.5">
          <li :for={change <- changes} class="space-y-1.5">
            <.link
              navigate={changelog_path(change.server.name)}
              class="inline-flex items-center gap-2 text-sm font-medium transition-colors hover:text-brand"
            >
              {change.server.title}
              <span class="font-mono text-[11px] font-normal text-dim">{change.server.name}</span>
            </.link>
            <Changelog.change_card change={change} server={change.server} />
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  defp by_day(changes) do
    changes
    |> Enum.group_by(&DateTime.to_date(&1.inserted_at))
    |> Enum.sort_by(fn {day, _} -> day end, {:desc, Date})
  end
end
