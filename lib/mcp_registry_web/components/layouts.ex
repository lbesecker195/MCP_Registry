defmodule McpRegistryWeb.Layouts do
  @moduledoc """
  Site chrome: the header, the content column and the footer.

  Every colour here comes from a design token (`bg-canvas`, `text-dim`,
  `border-rule`, `bg-brand`) rather than a literal Tailwind colour, so the
  light and dark themes stay in step. See `McpRegistryWeb.CoreComponents`.

  The wordmark reads "MCP Harbor"; page titles, metadata and body copy stay
  "MCP Registry", which is the term people actually search for.
  """
  use McpRegistryWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout: site header, content column, and footer.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom,
    default: nil,
    values: [nil, :home, :servers, :submit],
    doc: "which primary nav item to mark as current"

  attr :wide, :boolean,
    default: false,
    doc: "drop the reading-width cap, for the landing page's full-bleed sections"

  slot :rail,
    doc: """
    A full-width bar pinned under the site header — breadcrumbs on the left,
    status on the right. It cannot be rendered from inside the content column,
    which is width-capped, so it is a slot here instead.
    """

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <a
      href="#main"
      class="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:rounded-field focus:bg-brand focus:px-3 focus:py-2 focus:text-sm focus:text-brand-ink"
    >
      Skip to content
    </a>

    <header class="sticky top-0 z-30 border-b border-rule bg-canvas/80 backdrop-blur-md">
      <div class="mx-auto flex h-14 max-w-6xl items-center gap-4 px-4 sm:px-6 lg:px-8">
        <.link
          navigate={~p"/"}
          class="group flex w-fit items-center gap-2"
          aria-label="MCP Harbor home"
        >
          <.harbor_mark class="size-6 text-brand transition-transform duration-500 group-hover:-rotate-12" />
          <span class="font-mono text-sm tracking-tight">
            <span class="text-dim">mcp<span class="text-brand">/</span></span><span class="font-semibold">harbor</span>
          </span>
        </.link>

        <nav class="ml-auto flex items-center gap-1" aria-label="Primary">
          <.nav_link navigate={~p"/servers"} current={@active == :servers}>servers</.nav_link>
          <.nav_link href={~p"/api/v0/servers"} current={false}>api</.nav_link>
          <.nav_link href={~p"/llms.txt"} current={false}>llms.txt</.nav_link>
          <span class="mx-1 hidden h-5 w-px bg-rule sm:block"></span>
          <.theme_toggle />
          <.link
            navigate={~p"/submit"}
            class="ml-1 rounded-field bg-brand px-3 py-1.5 font-mono text-xs font-medium text-brand-ink shadow-sm transition-all duration-200 hover:shadow-md hover:brightness-110 active:scale-[0.98]"
          >
            submit
          </.link>
        </nav>
      </div>
    </header>

    <div
      :if={@rail != []}
      class="sticky top-14 z-20 border-b border-rule bg-surface/70 backdrop-blur-md"
    >
      <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-4 gap-y-1.5 px-4 py-2.5 sm:px-6 lg:px-8">
        {render_slot(@rail)}
      </div>
    </div>

    <main id="main" class={["px-4 pb-10 sm:px-6 lg:px-8", if(@rail != [], do: "pt-6", else: "pt-10")]}>
      <div class={["mx-auto space-y-6", if(@wide, do: "max-w-6xl", else: "max-w-5xl")]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="mt-20 border-t border-rule bg-surface/40">
      <div class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
        <div class="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div class="space-y-3">
            <.link navigate={~p"/"} class="flex w-fit items-center gap-2">
              <.harbor_mark class="size-5 text-brand" />
              <span class="font-mono text-sm tracking-tight">
                <span class="text-dim">mcp<span class="text-brand">/</span></span><span class="font-semibold">harbor</span>
              </span>
            </.link>
            <p class="max-w-xs text-xs leading-relaxed text-dim">
              An MCP server registry and directory. Mirrors the official MCP Registry, and is
              itself an MCP server your agent can call.
            </p>
          </div>

          <.footer_column title="Browse">
            <:link_item navigate={~p"/servers"}>All servers</:link_item>
            <:link_item navigate={~p"/servers?transport=streamable-http"}>
              Remote servers
            </:link_item>
            <:link_item navigate={~p"/servers?tag=developer-tools"}>Developer tools</:link_item>
            <:link_item navigate={~p"/submit"}>Submit a server</:link_item>
          </.footer_column>

          <.footer_column title="For agents">
            <:link_item href={~p"/llms.txt"}>llms.txt</:link_item>
            <:link_item href={~p"/api/v0/servers"}>JSON API</:link_item>
            <:link_item href={~p"/mcp"}>MCP endpoint</:link_item>
          </.footer_column>

          <.footer_column title="Project">
            <:link_item href="https://github.com/lbesecker195/MCP_Registry">
              Source on GitHub
            </:link_item>
            <:link_item href="https://github.com/lbesecker195/MCP_Registry/wiki">Wiki</:link_item>
            <:link_item href="https://seriouslysimpleanalytics.com">
              Seriously Simple Analytics
            </:link_item>
          </.footer_column>
        </div>

        <div class="mt-10 flex flex-col justify-between gap-3 border-t border-rule pt-6 font-mono text-xs text-dim sm:flex-row">
          <span>Copyright LoganBesecker.com 2026 &middot; Apache 2.0</span>
          <span>
            Analytics by
            <a
              href="https://seriouslysimpleanalytics.com"
              class="text-ink underline decoration-rule-strong underline-offset-4 transition-colors hover:decoration-brand"
              rel="noopener"
            >
              Seriously Simple Analytics
            </a>
            &mdash; free, unlimited, one script tag. We use it and recommend it.
          </span>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  attr :current, :boolean, default: false
  attr :rest, :global, include: ~w(href navigate patch)
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      class={[
        "hidden rounded-field px-3 py-1.5 font-mono text-xs transition-colors sm:block",
        if(@current, do: "bg-surface text-ink", else: "text-dim hover:bg-surface hover:text-ink")
      ]}
      aria-current={@current && "page"}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :title, :string, required: true

  slot :link_item, required: true do
    attr :navigate, :string
    attr :href, :string
  end

  defp footer_column(assigns) do
    ~H"""
    <div class="space-y-3">
      <h2 class="font-mono text-[11px] tracking-wide text-dim uppercase">{@title}</h2>
      <ul class="space-y-2">
        <li :for={item <- @link_item}>
          <.link
            navigate={item[:navigate]}
            href={item[:href]}
            class="text-xs text-dim transition-colors hover:text-ink"
          >
            {render_slot(item)}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  The sponsored block: four square slots, two up.

  Lives here rather than in `CoreComponents` because it is site chrome: it
  belongs to the page frame, not to the listing being described, and any page
  can drop it into a sidebar.

  The book is a live affiliate link and carries `rel="sponsored"`, which is
  what Google asks for on paid or affiliate placements — without it the link
  reads as an editorial endorsement and puts the whole page's ranking at risk.
  The other three are unsold placeholders and are not links at all.

  ## Examples

      <Layouts.sponsors />
  """
  attr :class, :any, default: nil

  @sponsor_slots [
    %{
      image: "/images/Book.png",
      alt: "Book cover — buy on Amazon",
      href: "https://amzn.to/4cPvd4j"
    },
    %{image: "/images/sponsor-1.png", alt: "Sponsor slot one", href: nil},
    %{image: "/images/sponsor-2.png", alt: "Sponsor slot two", href: nil},
    %{image: "/images/sponsor-3.png", alt: "Sponsor slot three", href: nil}
  ]

  def sponsors(assigns) do
    assigns = assign(assigns, :slots, @sponsor_slots)

    ~H"""
    <section
      aria-labelledby="sponsors-heading"
      class={["space-y-3 rounded-box border border-rule bg-surface/30 p-4", @class]}
    >
      <h2
        id="sponsors-heading"
        class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase"
      >
        <.icon name="hero-sparkles" class="size-3.5 text-accent" /> Sponsored
      </h2>

      <ul class="grid grid-cols-2 gap-2">
        <li :for={slot <- @slots}>
          <%!-- The frame clips; the image inside it scales. Putting the
                transform on the <img> rather than the frame means the tile
                keeps its place in the grid and nothing reflows on hover.

                If you ever check this in the console: Tailwind v4's `scale-*`
                sets the standalone CSS `scale` property, so the hover state
                shows up as `scale: 1.1` and `transform` stays `none`. --%>
          <a
            :if={slot.href}
            href={slot.href}
            target="_blank"
            rel="sponsored noopener noreferrer"
            class="group block aspect-square overflow-hidden rounded-field border border-rule bg-sunken transition-colors hover:border-brand/50"
          >
            <img
              src={slot.image}
              alt={slot.alt}
              loading="lazy"
              decoding="async"
              class="size-full object-contain p-1.5 transition-transform duration-500 ease-out will-change-transform group-hover:scale-110"
            />
          </a>

          <div
            :if={is_nil(slot.href)}
            class="group aspect-square overflow-hidden rounded-field border border-dashed border-rule bg-sunken transition-colors hover:border-rule-strong"
          >
            <img
              src={slot.image}
              alt={slot.alt}
              loading="lazy"
              decoding="async"
              class="size-full object-contain p-1.5 transition-transform duration-500 ease-out will-change-transform group-hover:scale-110"
            />
          </div>
        </li>
      </ul>
    </section>
    """
  end

  @doc """
  The MCP Harbor mark: an anchor riding a waterline.

  Inline rather than an asset so it inherits `currentColor` and can be animated
  by the surrounding group on hover.
  """
  attr :class, :any, default: "size-6"

  def harbor_mark(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class={["inline-block shrink-0", @class]}
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="4.25" r="1.75" />
      <path d="M12 6v13" />
      <path d="M8.25 9h7.5" />
      <path d="M4.5 13.5a7.5 7.5 0 0 0 15 0" />
      <path d="M3 13.5h3M18 13.5h3" />
    </svg>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      class="relative flex flex-row items-center rounded-full border border-rule bg-surface p-0.5"
      role="group"
      aria-label="Colour theme"
    >
      <div class="absolute left-0.5 h-[calc(100%-4px)] w-[calc(33.333%-2px)] rounded-full bg-canvas shadow-sm transition-[left] duration-300 ease-out [[data-theme-source=user][data-theme=dark]_&]:left-[66.6%] [[data-theme-source=user][data-theme=light]_&]:left-[33.7%]" />

      <button
        class="relative flex w-1/3 cursor-pointer justify-center p-1.5 text-dim transition-colors hover:text-ink"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="Match system theme"
        aria-label="Match system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="relative flex w-1/3 cursor-pointer justify-center p-1.5 text-dim transition-colors hover:text-ink"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="relative flex w-1/3 cursor-pointer justify-center p-1.5 text-dim transition-colors hover:text-ink"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end

  @doc "Accent colour for a transport, as Tailwind token classes."
  def transport_tone("stdio"), do: "border-rule text-dim"
  def transport_tone("streamable-http"), do: "border-brand/40 text-brand"
  def transport_tone("sse"), do: "border-accent/40 text-accent"
  def transport_tone(_), do: "border-rule text-dim"
end
