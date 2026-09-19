# AGENT.md — MCP Registry Agent Guide

How to work on this project with Claude agents and Claude Code.

The site is branded **MCP Harbor** in the wordmark only. Page titles, meta
descriptions, `llms.txt` and body copy say **MCP Registry**, because that is the
term people search for. Do not rename those to Harbor.

Production: <https://ai.mcpharbor.dev> (`PHX_HOST=ai.mcpharbor.dev`).

---

## Working in this repository

### Before you touch anything

1. The canonical clone is `~/Documents/businesses/MCP_Registry`. An older copy
   exists at `~/Documents/businesses/HoneyTrap/mcp_registery` — it is behind and
   should not be worked in.
2. **Several Claude sessions may share this clone at once.** Never run
   `git checkout`, `git switch`, `git reset`, `git stash`, `git restore` or
   `git clean`. A concurrent session doing `git reset --hard origin/main` has
   already destroyed another session's uncommitted work once. Read-only git
   (`diff`, `log`, `show`, `status`) is always fine.
3. Commit early. A commit survives another session's reset; a dirty working tree
   does not. If work is lost, recover it with
   `git fsck --lost-found` and `git cat-file -p <blob>` — blobs usually survive.
4. Prefer a separate `git worktree` when you know another session is active.

### Conventions

- File a GitHub issue before work that will become its own commit.
- One new branch per commit. Never commit straight to `main`.
- Author as `Logan Besecker <me@LoganBesecker.com>`.
- Commit bodies: ~75 words, 3–5 bullets, then a `Pages affected:` list of 1–5
  **absolute** `https://ai.mcpharbor.dev/...` links with varied anchor text.
- Everything is Apache 2.0 licensed.
- Run `mix format` on every file you change. Run `mix compile` before you claim
  a change works — but not while other agents are building, since the build lock
  serialises them.

---

## Routing map

| Path | Module | Purpose |
|---|---|---|
| `/` | `ServerLive.Home` | Marketing landing page |
| `/servers` | `ServerLive.Index` | The catalogue: search, filters, pagination |
| `/servers/*name` | `ServerLive.Show` | One server's detail page |
| `/submit` | `ServerLive.New` | Submission form |
| `/llms.txt` | `LlmsController` | Plain-text guide for agents |
| `/mcp` | `MCPController` | The registry as an MCP server |
| `/api/v0/*` | `API.ServerController` | JSON API |

Two things to keep true:

- The exact `/servers` route **must** be declared before the `/servers/*name`
  glob, or the catalogue falls through to the detail view and 404s.
- `/` used to be the catalogue. `Home.handle_params/3` redirects `/?q=`, `/?tag=`,
  `/?transport=` and `/?page=` to the same query on `/servers`, so old inbound
  links and rankings survive. Do not remove that.

---

## Front end

The front end is **plain Tailwind CSS loaded from the CDN**. There is no
component framework and no build-time Tailwind compilation.

### How it is wired

- `lib/mcp_registry_web/components/layouts/root.html.heex` loads
  `@tailwindcss/browser@4` from jsDelivr and declares the theme in a
  `<style type="text/tailwindcss">` block. The build watches the DOM, so classes
  arriving in a LiveView patch are generated too.
- `assets/css/app.css` is **plain CSS with no Tailwind directives**. It defines
  the design tokens as CSS variables and paints the canvas before the CDN script
  parses, so a dark-mode visitor never sees a white flash. It still passes
  through `mix tailwind`, which simply minifies it.
- The layout re-exports those variables to Tailwind with `@theme inline`. The
  `inline` keyword is load-bearing: it makes each utility emit `var(--canvas)`
  rather than baking one theme's value, so the palette re-resolves the instant
  `data-theme` flips.

### Rules

**daisyUI has been removed.** Never emit `btn`, `card`, `badge`, `input`,
`select`, `textarea`, `alert`, `toast`, `tabs`, `tab`, `tab-content`, `list`,
`list-row`, `table`, `link`, `join`, `fieldset`, `kbd`, `steps`, `navbar`,
`menu`, `divider`, `modal`, `dropdown`, `collapse`, `stat`, `loading` or
`skeleton` as classes. (`<label>` and `<fieldset>` as HTML *elements* are fine;
the same-named daisyUI *classes* are not.)

**These colour names no longer exist** and silently render unstyled if used:
`base-100`, `base-200`, `base-300`, `base-content`, `primary`,
`primary-content`, `secondary`, `neutral`, `info`, `error`, `well`.

Use only the semantic tokens:

| Purpose | Utilities |
|---|---|
| Surfaces | `bg-canvas` `bg-surface` `bg-sunken` |
| Text | `text-ink` `text-dim` |
| Borders | `border-rule` `border-rule-strong` `bg-rule` |
| Brand | `bg-brand` `text-brand` `text-brand-ink` `border-brand` |
| Accent | `bg-accent` `text-accent` `text-accent-ink` |
| Status | `text-success` `text-warning` `text-danger` |
| Washes | `bg-glow` `bg-beam` |

Opacity modifiers work (`bg-surface/60`, `border-brand/40`). Radii are
`rounded-box` for surfaces, `rounded-field` for controls, `rounded-full` for
pills. `font-mono` is the site's voice for identifiers, commands, counts and
eyebrow labels; the eyebrow pattern is
`font-mono text-[11px] tracking-wide text-dim uppercase`.

Dark mode is automatic through the tokens — **never write `dark:` variants for
colour**, and never hardcode a Tailwind palette colour or a hex value.

### The console template

The site's pages are built from one shared vocabulary, defined in
`core_components.ex`. `/servers/*` (`ServerLive.Show`) is the reference
implementation — read it before designing a new page, and reach for these
rather than hand-rolling the same shapes again.

| Component | What it is |
|---|---|
| `<.monogram name={server.name} />` | Identity tile. Hue is `phash2` of the name, so a listing draws the same colour everywhere. |
| `<.badge tone="success" dot>` | Status pill. Tones: neutral, brand, success, warning, danger, accent. |
| `<.meta_chip key="transport" value="stdio" />` | A `key:value` fact in mono, for the row under a title. |
| `<.code_block id=… code=… copy_label=… />` | Multi-line config with a copy button. `<SCREAMING_SNAKE>` runs are highlighted as placeholders. |
| `<.copy_command id=… command=… />` | Single shell command with a `$` gutter. |
| `<.panel title=… icon=…>` | Bordered group with an uppercase mono label — the sidebar unit. |
| `<.spec_row label=… value=… />` | One hairline-separated key/value line inside a panel. |
| `<.segmented options=… selected=… event=… />` | Pill switcher; the caller owns the state. |
| `<.tab_button tab=… current=… event=… />` | Underlined tab; the caller owns the state. |
| `<Layouts.app><:rail>` | Full-width bar pinned under the header, for breadcrumbs and status. |

Page skeleton: rail → identity block (monogram, title, version chip, meta
chips) → a primary action card → a `lg:grid-cols-12` split of `lg:col-span-8`
content and a `lg:col-span-4` sticky rail of panels.

**Tabs and switchers are LiveView state**, driven by `phx-click` and an
assign. The exception is the package-manager switcher, which stays CSS-only
so it costs no round trip. In that pattern the radios, labels and panels must
be **direct siblings in one container** — Tailwind's `peer-checked/<id>:`
compiles to a sibling combinator, so a label nested one div deeper silently
never reacts and every tab looks inert.

Long-form content (generated articles, upstream READMEs) is **never** put
behind a tab. It stays rendered in the page, because that is what the page
ranks on.

### Icons

Heroicons are **inlined as SVG at compile time** by `icon_data/1` in
`core_components.ex`, because the Tailwind plugin that generated `hero-*` mask
classes cannot run in the browser build.

```heex
<.icon name="hero-magnifying-glass" class="size-4" />
```

An unknown name **raises at render time**, which takes the page down. To add
one, copy the `<svg>` body from
`deps/heroicons/optimized/{16/solid|24/outline}/NAME.svg` into a new
`icon_data/1` clause. Names ending `-micro` come from the 16px solid set;
everything else from 24px outline.

### Components

`core_components.ex` provides `<.icon>`, `<.button>`, `<.input>`, `<.header>`,
`<.list>`, `<.copy_command>` and `<.flash>`. `layouts.ex` provides
`<Layouts.app>` (attrs: `flash`, `active`, `wide`), `harbor_mark/1` and
`transport_tone/1`. Use them rather than rebuilding the same markup.

Raw HTML from READMEs and generated articles cannot carry utility classes — wrap
it in `<div class="richtext">{raw(...)}</div>`. The `prose` classes are **not**
available; the typography plugin is not loaded.

Motion lives in `app.css`: `rise` for one-shot entrances (stagger with
`style="--d: 120ms"`) and `shimmer` for loading placeholders.
`prefers-reduced-motion` is handled globally — do not re-implement it.

---

## Article generation pipeline

### Setup

```bash
cd ~/Documents/businesses/MCP_Registry
export REGISTRY_PUBLISH_TOKEN="your-token-here"
```

### Single article

1. Research the MCP server (GitHub repo, documentation, features).
2. Generate a technical article in markdown.
3. Save it:

```bash
./scripts/save_article.sh io.github.microsoft/playwright-mcp article.md --prod
```

### Batch generation

Spawn agents in parallel — one content-generation task per server. Validate each
article before saving and log failed saves for retry. `ContentGenerator.save_articles_batch/1`
handles bulk writes.

### Article requirements

**Top 500 servers — 20,000+ words.** Deep technical dive, architecture and
design patterns, use cases and examples, integration guide for Claude and
Cursor, and a link to `https://ai.mcpharbor.dev/servers/:name`.

**Remaining ~31k servers — 500 words.** Overview and key features, primary use
case, quick setup, and the same registry link.

Structure for the long form: Introduction (500) · Architecture (2,000) ·
Features (5,000) · Integration (5,000) · Use cases (3,000) · Troubleshooting
(1,500) · Comparison (1,500) · Advanced topics (1,500).

Short form: Overview (200) · Quick start (200) · Key features (100) · Links.

### Storage

Articles live on the `servers` table as `article_content` (markdown) and
`article_generated_at` (timestamp). `ServerLive.Show` renders them with Earmark
into a `.richtext` container. Large articles (50KB+) are fine; there is no hard
limit.

---

## API reference

### Save an article

**POST** `/api/v0/articles/:name` — requires `Authorization: Bearer $REGISTRY_PUBLISH_TOKEN`.

```bash
curl -X POST "https://ai.mcpharbor.dev/api/v0/articles/io.github.microsoft%2Fplaywright-mcp" \
  -H "Authorization: Bearer $REGISTRY_PUBLISH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "# Article markdown here..."}'
```

Returns the updated server object with an `article_generated_at` timestamp.

### Retrieve a server

```bash
curl "https://ai.mcpharbor.dev/api/v0/servers/io.github.microsoft%2Fplaywright-mcp"
```

Note the server name is URL-encoded — the `/` becomes `%2F`.

---

## Troubleshooting

**`✗ REGISTRY_PUBLISH_TOKEN not set`** — export the token before running the script.

**`✗ Server not found`** — names are stored lowercase; match the registry exactly,
including the full reverse-DNS path.

**404 on an endpoint** — check DNS and that the deploy completed.

**A page renders unstyled** — almost always a dead colour token (`bg-base-200`,
`text-primary`) left over from daisyUI. Grep for the names listed above.

**`ArgumentError: unknown icon`** — an `<.icon name="...">` with no `icon_data/1`
clause. Add the clause or correct the name.

**Colours look right in light mode and wrong in dark** — a hardcoded colour, or a
token exported with `@theme` instead of `@theme inline`.

---

## Production checklist

- [ ] Token is valid
- [ ] Migrations applied
- [ ] `mix compile` is clean, with no new warnings
- [ ] Both light and dark themes checked
- [ ] Checked at 375px width with no horizontal scroll
- [ ] Article content is markdown and the server name matches exactly
- [ ] Verified the page renders on production

---

## Links

- **Registry**: <https://ai.mcpharbor.dev>
- **Catalogue**: <https://ai.mcpharbor.dev/servers>
- **Agent instructions**: <https://ai.mcpharbor.dev/llms.txt>
- **API**: <https://ai.mcpharbor.dev/api/v0/servers>
- **GitHub**: <https://github.com/lbesecker195/MCP_Registry>
- **Official MCP Registry**: <https://registry.modelcontextprotocol.io/v0.1/servers>
