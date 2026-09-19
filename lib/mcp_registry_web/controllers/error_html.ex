defmodule McpRegistryWeb.ErrorHTML do
  @moduledoc """
  The 404 and 500 pages.

  Error responses are rendered with `layout: false` (see `config/config.exs`),
  so nothing from `McpRegistryWeb.Layouts` is available here -- no root layout,
  no `@flash`, no LiveView socket. Each page is therefore a whole document:
  it links the token stylesheet, pulls in the Tailwind CDN build with the same
  `@theme inline` bridge the root layout uses, and sets `data-theme` from the
  same `phx:theme` key, so a 404 looks like the rest of the site in either
  theme. Nothing else is loaded -- an error page should not depend on the app
  bundle that may be the thing that broke.

  404 carries real traffic: server names change when a publisher moves
  namespace, and old deep links keep arriving. The page's job is to get that
  visitor into the catalogue rather than to apologise.
  """
  use McpRegistryWeb, :html

  def render("404.html", _assigns) do
    assigns = %{}

    ~H"""
    <.error_page
      code="404"
      title="No page at this address"
      status="Not Found"
      lead="Listings move when a publisher changes namespace, and links from elsewhere on the web go stale. The catalogue is searchable and current -- the server you wanted is probably still there under a new name."
    >
      <.error_action href={~p"/servers"} primary>
        Search the catalogue <.icon name="hero-arrow-right-micro" class="size-4" />
      </.error_action>
      <.error_action href={~p"/"}>Home</.error_action>
      <.error_action href={~p"/submit"}>Submit a server</.error_action>
    </.error_page>
    """
  end

  def render("500.html", _assigns) do
    assigns = %{}

    ~H"""
    <.error_page
      code="500"
      title="Something broke on our end"
      status="Internal Server Error"
      lead="The request reached the registry and failed there. Nothing you did caused it, and nothing you submitted was lost. Try again in a moment; the JSON API is a separate path to the same data if you need it now."
    >
      <.error_action href={~p"/"} primary>
        Back to the registry <.icon name="hero-arrow-right-micro" class="size-4" />
      </.error_action>
      <.error_action href={~p"/servers"}>Browse servers</.error_action>
      <.error_action href={~p"/api/v0/servers"}>JSON API</.error_action>
    </.error_page>
    """
  end

  # Everything else -- 400, 403, 422, 503 -- gets the same shell with the
  # status Phoenix derives from the template name.
  def render(template, _assigns) do
    status = Phoenix.Controller.status_message_from_template(template)
    code = template |> String.split(".") |> List.first()

    assigns = %{code: code, status: status}

    ~H"""
    <.error_page
      code={@code}
      title={@status}
      status={@status}
      lead="That request could not be served. The catalogue, the JSON API and the MCP endpoint are all still up."
    >
      <.error_action href={~p"/"} primary>
        Back to the registry <.icon name="hero-arrow-right-micro" class="size-4" />
      </.error_action>
      <.error_action href={~p"/servers"}>Browse servers</.error_action>
    </.error_page>
    """
  end

  attr :code, :string, required: true
  attr :title, :string, required: true
  attr :status, :string, required: true
  attr :lead, :string, required: true
  slot :inner_block, required: true

  defp error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <title>{@code} {@status} · MCP Registry</title>

        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4">
        </script>
        <style type="text/tailwindcss">
          /* The same bridge as root.html.heex: `inline` makes each utility emit
             var(--canvas) rather than one theme's computed value. */
          @theme inline {
            --color-canvas: var(--canvas);
            --color-surface: var(--surface);
            --color-sunken: var(--sunken);
            --color-ink: var(--ink);
            --color-dim: var(--dim);
            --color-rule: var(--rule);
            --color-rule-strong: var(--rule-strong);
            --color-brand: var(--brand);
            --color-brand-ink: var(--brand-ink);
            --color-accent: var(--accent);
            --color-danger: var(--danger);
            --color-glow: var(--glow);
            --radius-box: 0.625rem;
            --radius-field: 0.375rem;
            --font-sans: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto,
              "Helvetica Neue", Arial, sans-serif;
            --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas,
              "Liberation Mono", monospace;
          }
        </style>
        <script>
          // Read the theme the visitor already chose. Same key as the site's
          // toggle, so an error page does not flash the other theme at them.
          (() => {
            const system = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
            let stored = null;
            // Storage throws outright in some privacy modes; the system theme
            // is a fine answer and this page must never fail to render.
            try { stored = localStorage.getItem("phx:theme"); } catch (_) {}
            document.documentElement.setAttribute("data-theme", stored || system);
          })();
        </script>
      </head>
      <body>
        <main class="grid min-h-screen place-items-center px-4 py-16 sm:px-6">
          <div class="w-full max-w-xl">
            <a
              href={~p"/"}
              class="group inline-flex items-center gap-2 rounded-field transition-colors"
              aria-label="MCP Harbor home"
            >
              <Layouts.harbor_mark class="size-6 text-brand transition-transform duration-500 group-hover:-rotate-12" />
              <span class="font-mono text-sm tracking-tight">
                <span class="text-dim">mcp<span class="text-brand">/</span></span><span class="font-semibold">harbor</span>
              </span>
            </a>

            <p class="rise mt-10 font-mono text-6xl leading-none font-semibold tracking-tight text-brand sm:text-7xl">
              {@code}
            </p>

            <h1
              class="rise mt-4 text-2xl font-semibold tracking-tight text-balance sm:text-3xl"
              style="--d: 60ms"
            >
              {@title}
            </h1>

            <p class="rise mt-3 text-sm leading-relaxed text-pretty text-dim" style="--d: 120ms">
              {@lead}
            </p>

            <div class="rise mt-8 flex flex-wrap items-center gap-3" style="--d: 180ms">
              {render_slot(@inner_block)}
            </div>

            <p class="mt-10 border-t border-rule pt-6 font-mono text-[11px] tracking-wide text-dim uppercase">
              MCP Registry &middot; {@status}
            </p>
          </div>
        </main>
      </body>
    </html>
    """
  end

  # Plain anchors: nothing on this page posts, and it ships no app JavaScript.
  attr :href, :string, required: true
  attr :primary, :boolean, default: false
  slot :inner_block, required: true

  defp error_action(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "inline-flex items-center justify-center gap-2 rounded-field px-4 py-2",
        "text-sm font-medium transition-all duration-200 active:scale-[0.98]",
        if(@primary,
          do: "bg-brand text-brand-ink shadow-sm hover:shadow-md hover:brightness-110",
          else: "border border-rule bg-surface text-ink hover:border-rule-strong hover:bg-sunken"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end
end
