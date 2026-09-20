defmodule McpRegistryWeb.BookLive do
  @moduledoc """
  The landing page for *MCP Server Optimization*, at `/book`.

  The sidebar slot on every listing points here rather than straight at Amazon.
  A cold click from a 250px tile to a product page converts badly; a page that
  names the reader's problem first, and only then asks for the click, converts
  better and keeps the visit on the site in the meantime.

  Every factual claim here — page count, ISBN, prices, publication date — comes
  from the product listing. The prose is written for this page rather than
  lifted from it, and there is no rating or bestseller claim anywhere, because
  the book has no ratings yet and inventing them would be a lie that a reader
  can check in one click.
  """
  use McpRegistryWeb, :live_view

  @asin "B0HJXTLC9F"
  @buy_url "https://amzn.to/4cPvd4j"
  @title "MCP Server Optimization"
  @subtitle "SEO for MCP Servers — Make Your Servers Findable, Trusted, and Easy to Connect"
  @author "Logan R Besecker"
  @isbn "979-8174638471"
  @pages 244
  @published "September 15, 2026"
  @hardcover "$49.99"
  @paperback "$29.99"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "#{@title}: #{@subtitle}")
     |> assign(:title_suffix, " · MCP Registry")
     |> assign(
       :meta_description,
       "#{@title} by #{@author}. A #{@pages}-page field guide to making Model Context " <>
         "Protocol servers findable, trusted and easy to connect — registry identity, " <>
         "server.json metadata, tool design, transports, llms.txt and a 30-day playbook."
     )
     |> assign(:canonical_url, McpRegistryWeb.Endpoint.url() <> "/book")
     |> assign(:structured_data, structured_data())
     # Inside ~H, `@name` is `assigns.name` -- never the module attribute. The
     # facts have to be assigned or the template reads an assign that is not
     # there and the page raises at render.
     |> assign(
       buy_url: @buy_url,
       asin: @asin,
       title: @title,
       subtitle: @subtitle,
       author: @author,
       isbn: @isbn,
       pages: @pages,
       published: @published,
       hardcover: @hardcover,
       paperback: @paperback
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide={true}>
      <:rail>
        <nav aria-label="Breadcrumb" class="min-w-0 font-mono text-xs">
          <ol class="flex flex-wrap items-center gap-x-1.5 gap-y-1 text-dim">
            <li><.link navigate={~p"/"} class="transition-colors hover:text-ink">Home</.link></li>
            <li aria-hidden="true" class="text-rule-strong">/</li>
            <li class="font-medium text-brand" aria-current="page">The book</li>
          </ol>
        </nav>
        <.badge tone="accent">Written by the maintainer of this registry</.badge>
      </:rail>

      <%!-- EEx, not `{...}`: HEEx treats a <script> body as literal text and
            will not interpolate curly-brace expressions inside it, so `{...}`
            here ships the source of the expression to crawlers verbatim. --%>
      <script type="application/ld+json">
        <%= raw(@structured_data) %>
      </script>

      <%!-- --- Hero: cover, promise, price, CTA above the fold ------------- --%>
      <section class="rise grid gap-8 border-b border-rule pb-10 md:grid-cols-[minmax(0,280px)_1fr] md:gap-10">
        <div class="mx-auto w-full max-w-[280px] md:mx-0">
          <img
            src={~p"/images/Book.png"}
            alt={"Cover of #{@title} by #{@author}"}
            width="1000"
            height="1000"
            fetchpriority="high"
            decoding="async"
            class="w-full rounded-box border border-rule bg-sunken object-contain shadow-lg"
          />
        </div>

        <div class="min-w-0 space-y-5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">
            For developers shipping MCP servers
          </p>

          <div class="space-y-3">
            <h1 class="text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
              Your MCP server works. Agents still can't find it.
            </h1>
            <p class="max-w-2xl text-base leading-relaxed text-pretty text-dim">
              It runs on your machine. The tools return clean results. Then nothing happens — no
              connects, no repeat use, and a registry listing that agents skip straight past.
              <b class="font-medium text-ink">{@title}</b>
              is the {@pages}-page repair manual for the gap between a server that runs and a
              server that gets adopted.
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <.button
              variant="primary"
              href={@buy_url}
              rel="sponsored noopener noreferrer"
              target="_blank"
              class="px-6 py-3 text-base"
            >
              Get the book on Amazon <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            </.button>
            <p class="font-mono text-xs text-dim">
              Paperback <span class="text-ink">{@paperback}</span>
              &middot; Hardcover <span class="text-ink">{@hardcover}</span>
            </p>
          </div>

          <ul class="grid gap-x-6 gap-y-2 text-sm text-dim sm:grid-cols-2">
            <li
              :for={
                point <- [
                  "Why one resolvable name beats a clever one",
                  "Fixing the empty tools: [] metadata bug",
                  "Tool design agents can actually call",
                  "stdio, Streamable HTTP and SSE, concretely",
                  "llms.txt, AGENTS.md and SKILL.md, separated",
                  "A 30-day playbook, not a pep talk"
                ]
              }
              class="flex items-start gap-2"
            >
              <.icon name="hero-check-micro" class="mt-0.5 size-4 shrink-0 text-success" />
              <span class="text-pretty">{point}</span>
            </li>
          </ul>
        </div>
      </section>

      <%!-- --- The problem, named specifically ---------------------------- --%>
      <section aria-labelledby="problem-heading" class="space-y-5 pt-4">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">the symptom</p>
          <h2 id="problem-heading" class="text-2xl font-semibold tracking-tight text-balance">
            A server that runs is not a server that gets used
          </h2>
        </div>

        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={
              {title, body} <- [
                {"Agents never find it",
                 "Discovery is several layers deep — the official registry, this one, client catalogues, curated lists, llms.txt. Missing one is enough to stay invisible."},
                {"The name does not resolve",
                 "A long, keyword-stuffed identifier looks clever until a lookup 404s and your own docs teach agents the wrong name."},
                {"Your metadata says nothing",
                 "An empty tool list is not cosmetic. An agent cannot evaluate what it cannot see before connecting, so it moves on."},
                {"Installed once, then removed",
                 "A cryptic error on first run is the end of the relationship. Actionable failures are a retention feature."},
                {"The README serves nobody",
                 "One file written for humans and agents at once converts neither. They need different documents."},
                {"You measure the wrong thing",
                 "Traffic is vanity. Connect success and tool error rates are the numbers that move adoption."}
              ]
            }
            class="space-y-1.5 rounded-box border border-rule bg-surface/40 p-4"
          >
            <h3 class="text-sm font-medium">{title}</h3>
            <p class="text-xs leading-relaxed text-pretty text-dim">{body}</p>
          </div>
        </div>
      </section>

      <%!-- --- What's inside ---------------------------------------------- --%>
      <section aria-labelledby="inside-heading" class="space-y-5 pt-6">
        <div class="space-y-1.5">
          <p class="font-mono text-[11px] tracking-wide text-dim uppercase">what is inside</p>
          <h2 id="inside-heading" class="text-2xl font-semibold tracking-tight text-balance">
            Ten problems, in the order they bite
          </h2>
        </div>

        <ol class="grid gap-px overflow-hidden rounded-box border border-rule bg-rule sm:grid-cols-2">
          <li
            :for={
              {index, title, body} <- [
                {"01", "Discovery",
                 "How the official registry, MCP Harbor, client catalogues and curated lists actually feed agents — and which to fix first."},
                {"02", "Identity and naming",
                 "Reverse-DNS names that resolve, and keeping titles, READMEs and llms.txt saying the same thing."},
                {"03", "Manifests and metadata",
                 "server.json, remotes, website URLs and pre-connect tool lists — the signals that decide trust before anyone connects."},
                {"04", "Tool UX",
                 "Verb-noun names, one job per tool, search-versus-get instead of mega-tools, and errors that say what to do next."},
                {"05", "Resources and prompts",
                 "Declare what you support, wire what you advertise, keep capabilities honest."},
                {"06", "Local and remote",
                 "stdio, Streamable HTTP and SSE, aligned timeouts, and health checks that do not panic at a 405."},
                {"07", "Security without walls",
                 "Least privilege and scoped auth for secrets, without an onboarding gate that kills adoption."},
                {"08", "Documentation that converts",
                 "A human README and SEO spokes for people; llms.txt and skill maps for agents. Install snippets that match live identity."},
                {"09", "Publishing",
                 "Submitting cleanly, keeping identity consistent, and avoiding the empty-tools freeze."},
                {"10", "The 30-day playbook",
                 "Ship identity and machine-readable entrypoints, fix tool UX, verify presence, and run a daily friction kill list."}
              ]
            }
            class="space-y-1.5 bg-canvas p-4"
          >
            <p class="font-mono text-[11px] tracking-wide text-dim uppercase">
              {index} &middot; {title}
            </p>
            <p class="text-sm text-pretty text-dim">{body}</p>
          </li>
        </ol>
      </section>

      <%!-- --- Credibility, the honest kind ------------------------------- --%>
      <section aria-labelledby="trust-heading" class="pt-6">
        <div class="space-y-4 rounded-box border border-rule bg-surface/60 p-5 sm:p-7">
          <div class="space-y-1.5">
            <p class="font-mono text-[11px] tracking-wide text-dim uppercase">why take its word</p>
            <h2 id="trust-heading" class="text-xl font-semibold tracking-tight text-balance">
              The book describes this site, and you can check it
            </h2>
          </div>

          <p class="max-w-2xl text-sm leading-relaxed text-pretty text-dim">
            {@author} writes and runs MCP Harbor. Every technique in the book is visible in the
            registry you are reading it on — so you can audit the advice before you buy it, which
            is more than a review score would tell you.
          </p>

          <ul class="grid gap-2 sm:grid-cols-3">
            <li :for={
              {label, href, note} <- [
                {"/llms.txt", ~p"/llms.txt", "The agent-facing entrypoint, written out in full"},
                {"JSON API", ~p"/api/v0/servers", "Machine-readable listings, the shape agents read"},
                {"A listing", ~p"/servers", "Identity, manifest and tool metadata on every page"}
              ]
            }>
              <.link
                href={href}
                class="group flex h-full flex-col gap-1 rounded-field border border-rule bg-canvas p-3 transition-colors hover:border-brand/40"
              >
                <span class="font-mono text-xs text-brand">{label}</span>
                <span class="text-[11px] text-pretty text-dim">{note}</span>
              </.link>
            </li>
          </ul>
        </div>
      </section>

      <%!-- --- Formats, specs, FAQ ---------------------------------------- --%>
      <div class="grid gap-8 pt-6 lg:grid-cols-12">
        <div class="space-y-6 lg:col-span-7">
          <section aria-labelledby="faq-heading" class="space-y-4">
            <h2 id="faq-heading" class="text-xl font-semibold tracking-tight text-balance">
              Before you buy
            </h2>

            <div
              :for={
                {q, a} <- [
                  {"Is this just SEO advice with MCP in the title?",
                   "No. Discovery is one chapter of ten. The rest is manifest metadata, tool design, transports, security scoping, documentation and measurement — engineering decisions that happen to determine whether anyone finds the thing."},
                  {"I have not published a server yet. Too early?",
                   "That is the cheapest time to read it. Most of the damage — an unresolvable name, empty tool metadata, a README doing three jobs — is done at publish and expensive to undo once agents have cached it."},
                  {"Does it only apply to Claude?",
                   "No. It covers the protocol and the hosts that speak it, including Claude Code, Claude Desktop, Cursor, VS Code, Zed and Windsurf — each of which reads configuration differently."},
                  {"Paperback or hardcover?",
                   "Identical text. The paperback is #{@paperback}; the hardcover is #{@hardcover} and lies flat, which matters if you are working through the 30-day playbook at a desk."}
                ]
              }
              class="space-y-1.5 border-b border-rule pb-4 last:border-0"
            >
              <h3 class="text-sm font-medium">{q}</h3>
              <p class="text-sm leading-relaxed text-pretty text-dim">{a}</p>
            </div>
          </section>
        </div>

        <aside class="space-y-6 lg:col-span-5">
          <.panel title="Editions" icon="hero-book-open">
            <div>
              <.spec_row label="Paperback" value={@paperback} tone="brand" />
              <.spec_row label="Hardcover" value={@hardcover} tone="brand" />
            </div>
            <.button
              variant="primary"
              href={@buy_url}
              rel="sponsored noopener noreferrer"
              target="_blank"
              class="w-full"
            >
              Buy on Amazon <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            </.button>
          </.panel>

          <.panel title="Specifications" icon="hero-information-circle">
            <div>
              <.spec_row label="Author" value={@author} />
              <.spec_row label="Pages" value={@pages} />
              <.spec_row label="Published" value={@published} />
              <.spec_row label="Language" value="English" />
              <.spec_row label="ISBN-13" value={@isbn} />
              <.spec_row label="ASIN" value={@asin} />
            </div>
          </.panel>
        </aside>
      </div>

      <%!-- --- Closing CTA ------------------------------------------------ --%>
      <section aria-labelledby="cta-heading" class="pt-6">
        <div class="flex flex-col items-start gap-5 rounded-box border border-rule bg-sunken/70 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-7">
          <div class="space-y-1.5">
            <h2 id="cta-heading" class="text-lg font-semibold tracking-tight text-balance">
              Pick one friction and fix it today
            </h2>
            <p class="max-w-md text-sm text-pretty text-dim">
              {@pages} pages, ten chapters, and a thirty-day order of operations for getting your
              server found, trusted and connected.
            </p>
          </div>
          <.button
            variant="primary"
            href={@buy_url}
            rel="sponsored noopener noreferrer"
            target="_blank"
            class="shrink-0 px-6 py-3 text-base"
          >
            Get the book <.icon name="hero-arrow-right-micro" class="size-4" />
          </.button>
        </div>

        <%!-- Both disclosures belong here: the link earns a commission, and
              the author runs this site. Saying so costs a little trust and
              buys back more. --%>
        <p class="mt-3 text-[11px] text-pretty text-dim">
          Written by {@author}, who also maintains MCP Harbor. Links to Amazon are affiliate links
          and may earn a commission at no extra cost to you.
        </p>
      </section>
    </Layouts.app>
    """
  end

  # schema.org/Book, so the listing can earn a rich result. No aggregateRating:
  # the book has none yet, and marking up a rating that does not exist is both
  # a lie and a manual-action risk.
  defp structured_data do
    # escape: :html_safe writes `<`, `>` and `&` as unicode escapes, so nothing
    # in the data can close the <script> element early.
    Jason.encode!(
      %{
        "@context" => "https://schema.org",
        "@type" => "Book",
        "name" => @title,
        "alternateName" => "#{@title}: #{@subtitle}",
        "author" => %{"@type" => "Person", "name" => @author},
        "isbn" => @isbn,
        "numberOfPages" => @pages,
        "bookFormat" => "https://schema.org/Paperback",
        "inLanguage" => "en",
        "datePublished" => "2026-09-15",
        "publisher" => %{"@type" => "Organization", "name" => "Independently published"},
        "url" => McpRegistryWeb.Endpoint.url() <> "/book",
        "image" => McpRegistryWeb.Endpoint.url() <> "/images/Book.png",
        "description" =>
          "A field guide to making Model Context Protocol servers findable, trusted and easy " <>
            "to connect: registry identity, server.json metadata, tool design, transports, " <>
            "llms.txt and a 30-day optimization playbook.",
        "offers" => [
          %{
            "@type" => "Offer",
            "price" => "29.99",
            "priceCurrency" => "USD",
            "availability" => "https://schema.org/InStock",
            "url" => @buy_url,
            "itemCondition" => "https://schema.org/NewCondition"
          },
          %{
            "@type" => "Offer",
            "price" => "49.99",
            "priceCurrency" => "USD",
            "availability" => "https://schema.org/InStock",
            "url" => @buy_url,
            "itemCondition" => "https://schema.org/NewCondition"
          }
        ]
      },
      escape: :html_safe
    )
  end
end
