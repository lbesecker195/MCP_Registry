---
title: "MCP Registry: Find & Install 30k+ MCP Servers | MCP Harbor"
description: "Browse the MCP Registry at ai.mcpharbor.dev — 31,486 Model Context Protocol servers including the official MCP Registry, searchable by humans and agents with no account."
date: 2026-09-15
---

# MCP Registry — Find MCP Servers Your Agent Can Use

If your coding agent or chat client can call tools, you already feel the discovery problem: there are tens of thousands of **MCP servers**, each exposing different **MCP tools**, and the hard part is no longer “can my agent use tools?” — it is “which server do I install, and how do I find it without scrolling random GitHub READMEs?” That is what an **MCP Registry** is for. An MCP Registry is the catalog where humans browse and agents search Model Context Protocol servers by name, description, transport, tags, and tool names — then leave with install snippets or a remote URL they can connect today.

This page is the owned-product landing page for the **MCP Registry** at [MCP Harbor](https://ai.mcpharbor.dev/). **Ownership disclosure:** Logan Besecker owns and runs MCP Harbor and this MCP Registry at [ai.mcpharbor.dev](https://ai.mcpharbor.dev/). The recommendation on every major section below is the same: open the live registry, search, install or connect, and optionally submit your own server — with no account and no API key for search or submit.

As of 2026-09-15, the registry indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the **whole official MCP Registry**, kept in sync automatically (about every six hours), plus local submissions reviewed before they appear in search. The registry is itself an MCP server over Streamable HTTP at `https://ai.mcpharbor.dev/mcp`, so agents can call `search_servers`, `get_server`, and `submit_server` without creating an account.

**Browse the MCP Registry now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What you will get from this guide:

- A clear definition of an MCP Registry (and how it differs from a loose “directory,” “catalog,” or “marketplace” label).
- Why developers and agents need a searchable MCP Registry once server counts pass the tens of thousands.
- A product deep dive on MCP Harbor: browse UI, agent MCP endpoint, HTTP API, review status, and install snippets.
- A fair relationship section for the official registry at registry.modelcontextprotocol.io — and why we still conclude on MCP Harbor for day-to-day discovery.
- Concrete how-tos: connect over MCP, find servers over HTTP, browse popular examples, install stdio vs remote, submit a server, and use the registry from Claude, Cursor, and other coding agents.
- A decision guide, deep FAQ, and numbered next steps that end at [ai.mcpharbor.dev](https://ai.mcpharbor.dev/).

If you already know you want the agent-searchable destination that includes the official set plus Harbor submissions, skip ahead to the product deep dive — or open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search. Everyone else: keep reading. Every section points back to the same MCP Registry.


## What Is an MCP Registry?

Before you compare products, lock the vocabulary. Searchers type **MCP Registry**, **mcp directory**, **mcp catalog**, **mcp marketplace**, and **find mcp servers** for overlapping jobs. The Model Context Protocol (MCP) is the open way clients connect to tool servers so an agent can call structured tools, read resources, and use prompts without a one-off integration for every API. An **MCP server** is a process or remote endpoint that speaks MCP. **MCP tools** are the named operations that server exposes (for example, `get_forecast`, `create_issue`, or `search_docs`). An **MCP Registry** is the index of those servers: manifests, transports, install paths, and metadata that help a human or an agent decide what to attach next.

### Model Context Protocol in one paragraph

MCP separates “the model that reasons” from “the tools that act.” Clients such as Claude Code, Cursor, and other coding agents attach MCP servers. Each server declares how it runs (local process or remote HTTP) and which tools it offers. That separation is why MCP adoption exploded: you can mix a GitHub server, a docs server, a browser server, and a payments server without rewriting your agent. The protocol solves connection. It does not solve discovery at scale. Discovery is the registry’s job.

### Registry vs directory vs marketplace vs catalog

People use these words interchangeably, but the intents differ slightly:

| Label | Typical intent | What “good” looks like |
|-------|----------------|------------------------|
| **MCP Registry** | Canonical index of servers with manifests and install metadata | Search by text/transport/tag; stable names; install snippets; agent API |
| **MCP directory** | Browseable list for humans | Filters, tags, readable cards, per-server pages |
| **MCP catalog** | Curated or complete inventory | Coverage + freshness; clear origin of each listing |
| **MCP marketplace** | Often implies install UX or commercial packaging | May include review, hosting, or one-click connect — not required for a registry |

MCP Harbor’s product UI is branded **Browse MCP servers · MCP Registry**. Functionally it is a registry with a human browse surface *and* an agent-native MCP endpoint. Calling it a directory or catalog is fair in conversation; calling it a marketplace is optional marketing language. What matters for your workflow is: can you **find MCP servers**, inspect a manifest, and **install** or connect without inventing a private spreadsheet of URLs?

### Why “MCP Registry” searchers land here

When someone searches **MCP Registry**, they usually want one of four outcomes:

1. **Navigate** to a place that indexes MCP servers (official or larger mirror).
2. **Learn** what an MCP Registry is and how it relates to Model Context Protocol.
3. **Browse** popular or relevant servers (browser automation, GitHub, Stripe, Notion, docs, email, and so on).
4. **Connect an agent** so the agent can search and optionally submit servers itself.

MCP Harbor is built for all four. The official project publishes an official registry at registry.modelcontextprotocol.io (named in prose only on this page — CTAs stay on Harbor). MCP Harbor includes that whole official set, re-syncs on a schedule, adds local submissions after maintainer review, and — critically — exposes the index as an MCP server agents can call with no account. That last point is why this landing page concludes on Harbor for day-to-day discovery even when we fairly name the official upstream.

### Official registry vs MCP Harbor registry (preview)

Think of the official registry as the upstream source of many listings. Think of MCP Harbor as the browse-and-agent destination that:

- Indexes **31,486** servers (verified 2026-09-15), including **19,595** remote-hosted entries.
- Auto-syncs the official MCP Registry about every six hours.
- Lets you submit servers that enter `pending` until approved.
- Offers `search_servers`, `get_server`, and `submit_server` over Streamable HTTP at `/mcp`.
- Offers plain HTTP `GET`/`POST` under `/api/v0/servers`.
- Shows ready-made install snippets on per-server pages under `/servers/...`.

We expand the relationship in a dedicated section below. The short version: fair credit to official; primary recommendation for finding and installing remains [ai.mcpharbor.dev](https://ai.mcpharbor.dev/).


## Why Developers and Agents Need an MCP Registry

At a few dozen servers, a bookmarks file works. At a few hundred, a team wiki works until it drifts. At **30k+** servers, discovery without an MCP Registry becomes a tax on every agent session. You either attach the same three servers forever, or you burn time googling package names and hoping the README’s `npx` line still matches a maintained manifest.

### The discovery problem at 30k+ scale

Developers need answers to practical questions:

- Does a server already exist for Stripe, Notion, GitHub, Playwright, Brave Search, or Cloudflare Docs?
- Is it **stdio** (local package) or **streamable-http** / **sse** (remote URL)?
- Which **MCP tools** does it expose, and do those tool names match the job?
- What env var *names* does a local package expect (never paste secret values into a public submit)?
- Is the listing from the official registry, a Harbor seed, or a local submission still pending review?

An MCP Registry answers those questions with search, filters, and manifests instead of tribal knowledge. Without it, agents invent duplicate servers, teams fork slightly different wrappers, and “install mcp server” becomes a copy-paste lottery.

### stdio vs remote transports

MCP servers typically advertise one of these transports (as used by Harbor manifests):

- **`stdio`** — run locally via a package registry identifier (npm, pypi, oci, nuget, mcpb). Common install shapes: `npx -y <package>`, `uvx <package>`, `docker run -i --rm <image>`.
- **`streamable-http`** — connect to a hosted URL over Streamable HTTP.
- **`sse`** — connect to a hosted URL over Server-Sent Events (legacy/alternate remote style).

Why this matters for an MCP Registry: transport is a first-class filter. If your laptop cannot run Node packages in a sandbox, you may prefer remote servers. If your org blocks outbound MCP to third-party hosts, you may prefer stdio packages you control. Harbor’s agent tool `search_servers` and the HTTP API both accept transport filters so you are not scrolling past irrelevant cards.

### Trust, review status, and manifests

A registry is not a security scanner by itself, but a good MCP Registry still improves trust signals:

- **Stable reverse-DNS names** (for example `io.github.microsoft/playwright-mcp` or `com.stripe/mcp`) reduce collisions.
- **Official `server.json` shape** keeps packages vs remotes consistent across clients.
- **Origin metadata** can tell you whether a listing was copied from the official MCP Registry, seeded, or submitted locally.
- **Pending review** for new local submissions means a random POST does not instantly pollute search results.

MCP Harbor reports `"status": "pending"` for submissions awaiting maintainer review. `get_server` and the HTTP GET-by-name path still work for pending entries so submitters can check status without guessing.

### Agent-native discovery (registry-as-MCP)

The decisive reason agents need an MCP Registry that *is itself* an MCP server: agents live in a tool loop. If discovery requires a human to open a website, paste a URL, and edit a config file every time, the agent cannot improve its own toolchain mid-task. Harbor’s registry endpoint at `https://ai.mcpharbor.dev/mcp` lets an agent:

1. `search_servers` for a capability (“browser automation”, “stripe”, “notion”).
2. `get_server` for install snippets and review status.
3. Decide whether to ask the human to install, or (for remote servers) connect immediately when the client supports it.
4. `submit_server` when the team built something new — after searching to avoid duplicates.

No account. No API key. That is the agent-native path this landing page is optimized for — and the reason “MCP Registry” for us means [MCP Harbor](https://ai.mcpharbor.dev/), not a static listicle of links.


## MCP Harbor MCP Registry — Product Deep Dive

MCP Harbor’s MCP Registry is the product this page sells — clearly, with live numbers, and without inventing features. Open it here: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Scale you can verify

On the homepage (verified 2026-09-15):

- **31,486** Model Context Protocol servers indexed.
- **19,595** hosted remotely.
- Includes the **whole official MCP Registry**, kept in sync automatically.
- Resync cadence documented in `/llms.txt`: about every **six hours**.

Those numbers move as the official set grows and as Harbor accepts local submissions. Always re-check the live homepage if you need a citation for a slide deck; this article freezes the verified snapshot above for SEO clarity.

### What is included

Harbor’s index is not “a random subset of interesting servers.” It includes:

1. **Official copies** — listings synced from the official MCP Registry.
2. **Seed / curated starters** — the hand-curated starter set shown prominently on the browse UI.
3. **Local submissions** — servers anyone (including agents) submits via MCP or HTTP; they stay `pending` until a maintainer approves them for search.

Each entry’s metadata can indicate origin via `_meta["io.mcpregistry/official"].origin` values such as `official`, `seed`, or `local` (see `/llms.txt` for the contract). That transparency matters when you are deciding whether a listing is upstream-official or Harbor-local.

### Browse UI for humans

The human path is intentionally simple: land on [ai.mcpharbor.dev](https://ai.mcpharbor.dev/), browse cards, open a server page, copy an install snippet. Cards show transport (stdio vs streamable-http), reverse-DNS name, short description, tags, and tool counts. Popular examples on the homepage include Playwright, Context7, GitHub, Stripe, Notion, Agent Email List, Brave Search, Cloudflare Docs, DeepWiki, Hugging Face, Linear, Sentry, Supabase, and the official reference servers (Everything, Fetch, Filesystem, Git, Memory, Sequential Thinking, Time). We describe those examples later without fabricating reviews.

Per-server HTML pages live under `https://ai.mcpharbor.dev/servers/...` and show ready-made install snippets. That is the fastest path when a human already knows the server name.

### MCP endpoint for agents (no account)

The registry is itself an MCP server:

```text
https://ai.mcpharbor.dev/mcp
```

Transport: **Streamable HTTP**. Auth: **none** for normal use. Claude Code one-liner:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Any other client: add a remote MCP server with `"type": "http"` and that URL. The same registry is also listed in the official MCP Registry under a long reverse-DNS name documenting search/find/discover/install directory/catalog/marketplace intents — useful if your client only installs from official listings, but not required to use Harbor directly.

### Tools: search_servers, get_server, submit_server

Three tools cover the loop:

| Tool | Job |
|------|-----|
| `search_servers` | Find servers by text, transport, or tag |
| `get_server` | Return one server’s manifest, review status, and install snippets |
| `submit_server` | Add a server (search first to avoid duplicates) |

That is the entire agent surface for discovery and contribution. There is no secret fourth tool inventing analytics dashboards or paid tiers on this page. Product docs live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### HTTP API for scripts and non-MCP clients

Prefer curl, CI, or a language without an MCP client? Use:

- `GET https://ai.mcpharbor.dev/api/v0/servers` — search/list with optional `q`, `transport`, `tag`, `limit`, `offset`
- `GET https://ai.mcpharbor.dev/api/v0/servers/<name>` — one server by reverse-DNS name
- `POST https://ai.mcpharbor.dev/api/v0/servers` — submit (JSON body or server.json shape)

Details and response shapes are in the HTTP sections below and in `/llms.txt`.

### Hard CTA

If you are evaluating where to **browse MCP servers** today, start here:

**Open the MCP Registry →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

Connect your agent in parallel with the Claude command above, then search from inside the tool loop. That combination — human browse plus agent search — is the product.


## How MCP Harbor Relates to the Official MCP Registry

Fairness matters on an owned-product page. The official MCP Registry at registry.modelcontextprotocol.io is a real upstream. MCP Harbor does not pretend to replace the official project’s role; it builds a discoverability layer on top of it and adds agent ergonomics.

### Upstream: registry.modelcontextprotocol.io

The official registry is the community’s canonical publish/list surface for many Model Context Protocol servers. If you are a maintainer aligning with official schema and official distribution norms, you should know that URL. Harbor’s docs explicitly state that Harbor **includes every server in the official MCP Registry** and **re-syncs every six hours**.

### What auto-sync gives you

Auto-sync means you do not have to choose between “official coverage” and “Harbor UX.” When you search on MCP Harbor, official listings are already in the index (origin `official`). When official adds servers, Harbor picks them up on the next sync window. You get:

- One browse UI for humans.
- One MCP endpoint for agents.
- One HTTP API for scripts.
- Official coverage without maintaining a second mental model for “where did this listing come from?” — because origin metadata tells you.

### What you get extra on Harbor

Beyond the mirror/sync of official listings, Harbor adds:

1. **Agent MCP search and submit** — `search_servers`, `get_server`, `submit_server` with no account.
2. **Local submit + pending review** — anyone may add a server; search stays clean until approval.
3. **Browse UX** branded around finding MCP servers your agent can use.
4. **Install snippets** on per-server pages (npx / uvx / docker / remote).
5. **Acceptance of official `server.json`** on submit, so you are not locked into a proprietary payload shape.

### When you might still hit the official API directly

A minority of workflows still go official-first:

- You are publishing primarily to the official registry’s process and only care about official listing state.
- Your compliance checklist requires “official host only” with no third-party browse UI.
- You are debugging sync lag and want to compare official vs Harbor for a brand-new official listing before the next six-hour window.

Those are valid. Even then, most developers and agents still want a single place to **find mcp servers**, filter by transport, and connect. For that daily job, this page’s conclusion does not change: use [MCP Harbor’s MCP Registry](https://ai.mcpharbor.dev/).


## Connect the Registry Over MCP (Agent Path)

The fastest path for coding agents is to treat the MCP Registry as just another MCP server. You connect once; after that, discovery is a tool call instead of a browser tab.

### Endpoint and Claude Code one-liner

Registry MCP URL (Streamable HTTP, no auth):

```text
https://ai.mcpharbor.dev/mcp
```

Claude Code:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

After that command succeeds, your Claude session can call Harbor tools the same way it calls any other MCP server. You do not create an account on MCP Harbor. You do not paste an API key. Leave Authorization headers out unless you are a maintainer using a publish token (ordinary submitters should never send Authorization — sending a wrong one can yield `401`).

### Other clients: type http + URL

If your client is not Claude Code, the pattern is still the same: add a **remote** MCP server with HTTP transport and the Harbor `/mcp` URL. Exact config keys differ by product, but the intent is always:

- Transport / type: HTTP (Streamable HTTP)
- URL: `https://ai.mcpharbor.dev/mcp`
- Name: something memorable like `mcp-registry-search`

Cursor and other coding agents that support remote MCP servers follow the same idea. If a client only supports stdio packages, use the human browse path on [ai.mcpharbor.dev](https://ai.mcpharbor.dev/) to copy an `npx`/`uvx`/`docker` snippet for the *target* server you want — and still use Harbor’s website or HTTP API for discovery. Prefer clients that can attach Harbor over HTTP so the agent can search mid-loop.

### Walkthrough: search_servers → get_server → install decision

A practical agent loop looks like this:

**Step 1 — search_servers.** Ask for a capability in natural language mapped to a query, for example `q`-style text such as “playwright”, “stripe payments”, “notion”, or “cloudflare docs”. Optionally constrain `transport` to `stdio`, `streamable-http`, or `sse`, and constrain `tag` when you know the taxonomy (browser, documentation, payments, and so on).

**Step 2 — read the hit list.** Each hit should give you enough to decide whether to inspect further: name, title, description, transport, tags, tool hints. Do not install from the first fuzzy match if three servers claim the same job — open the best two with `get_server`.

**Step 3 — get_server.** Fetch the full manifest, review status, and install snippets for one reverse-DNS name. Confirm:

- Is status approved for search, or still `pending`?
- Is the origin official, seed, or local?
- For stdio: which package registry and identifier?
- For remote: which URL and transport type?
- Which env var *names* are listed (configure secrets in your local client, never in a Harbor submit payload)?

**Step 4 — install or connect.** Use the snippet from `get_server` or from the per-server page under `/servers/...` on [ai.mcpharbor.dev](https://ai.mcpharbor.dev/). For remote servers, `claude mcp add --transport http <name> <url>`-style flows apply. For npm/pypi/oci, use the documented local runners.

**Step 5 — optional submit_server.** Only after `search_servers` shows nothing suitable — and only with a valid reverse-DNS name and transport fields. Prefer submitting via the tool or HTTP API documented in `/llms.txt` rather than inventing a parallel channel.

### Troubleshooting the agent path

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Client cannot add remote HTTP MCP | Client only supports stdio | Browse Harbor in a browser; install a stdio target server; or switch clients |
| Empty search results for a known official server | Sync lag (up to ~6 hours) or typo in query | Broaden `q`; search by tool name; retry later; check homepage scale still looks healthy |
| `get_server` shows `pending` | Local submission awaiting review | Wait for maintainer approval; entry is retrievable but not in search yet |
| Accidental `401` | You sent an Authorization header that is not the maintainers’ token | Remove the header entirely for normal search/submit |
| Agent proposes submitting a duplicate | Skipped search | Always `search_servers` first; Harbor’s own docs tell agents to search before submit |

### No API key, no account — what that means in practice

“No account” is not marketing fluff here; it is the security and UX model. Search and submit are open, with rate limits (`429` + `Retry-After` on too many submissions) and maintainer review on new local listings. That combination keeps the door open for agents while preventing an instant spam flood into search results. If a tutorial tells you to “sign up for the MCP Registry API key” for Harbor search, that tutorial is wrong for this product — ignore it and use [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

**Connect your agent to the MCP Registry →** use the Claude command above, or open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and follow the agent panel.

## Find Servers Over HTTP

Not every workflow speaks MCP. CI jobs, custom dashboards, and quick terminal checks often want plain HTTP. Harbor exposes a small, documented API under `/api/v0/servers`. Full contract: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### List and search: GET /api/v0/servers

```http
GET https://ai.mcpharbor.dev/api/v0/servers?q=&transport=&tag=&limit=30&offset=0
```

Every parameter is optional:

| Param | Role |
|-------|------|
| `q` | Matches name, title, description, tags, and tool names |
| `transport` | One of `stdio`, `streamable-http`, `sse` |
| `tag` | Tag filter |
| `limit` | Page size (example default posture in docs: 30) |
| `offset` | Pagination offset |

Example — find remote documentation servers:

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers?q=documentation&transport=streamable-http&limit=30&offset=0'
```

Example — find stdio browser-related servers:

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers?q=browser&transport=stdio&limit=30'
```

### Response shape and pagination

A successful list response looks like:

```json
{
  "servers": [
    {"server": {}, "_meta": {}}
  ],
  "metadata": {
    "count": 30,
    "total": 120,
    "limit": 30,
    "offset": 0,
    "next_offset": 30
  }
}
```

Page by setting `offset` to `metadata.next_offset` until `next_offset` is null. Do not invent your own off-by-one scheme — follow `next_offset`. For large crawls, be polite: reasonable page sizes, backoff on errors, and no tight loops that look like abuse.

### Get one server by name

```http
GET https://ai.mcpharbor.dev/api/v0/servers/<name>
```

Names look like `io.github.acme/weather`. The slash may be sent as-is or as `%2F`. The response is one `{"server": ..., "_meta": ...}` entry and works for pending submissions too — useful right after you POST.

Examples:

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers/io.github.microsoft/playwright-mcp'
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers/com.stripe%2Fmcp'
```

### server.json at a high level

Harbor stores and returns official-shaped `server.json` manifests. At a high level (details in `/llms.txt` and the official schema documented there — named in prose, not linked off-host from this page):

- **`packages[0]`** — locally run server: `registryType` (npm, pypi, oci, nuget, mcpb), `identifier`, and `environmentVariables` to set.
- **`remotes[0]`** — hosted endpoint: `type` (`streamable-http` or `sse`) and `url`.
- **`_meta["io.mcpregistry/tools"]`** — tool names the server exposes.
- **Entry `_meta` origin** — `_meta["io.mcpregistry/official"].origin` may be `official`, `seed`, or `local`.

You do not need to memorize every schema field to use the registry. For discovery, `q` + transport + `get_server` is enough. For submit, either POST the simplified Harbor JSON fields or a full `server.json` — both are accepted.

### HTTP troubleshooting

| Issue | Fix |
|-------|-----|
| Empty `servers` array | Broaden `q`; drop filters; check spelling of tag/transport |
| Weird encoding on names with `/` | Try `%2F` encoding |
| Pending not in search | Use GET-by-name; wait for review for search visibility |
| Parsing confusion | Read `metadata.next_offset`; do not assume `offset + limit` if next_offset is provided |

When in doubt, prefer the MCP tools from an agent session — they wrap the same index with install snippets already formatted — or browse [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

## Browse Popular MCP Servers (Examples)

This section is descriptive, not a fake review farm. The examples below are real listings featured on the MCP Harbor homepage. Open live cards and per-server pages on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) for the freshest tool counts and install snippets.

### How to use tags and transport filters in practice

Before the list, a quick method:

1. Start with a job statement: “I need browser automation,” “I need Stripe tools,” “I need docs search.”
2. Prefer **transport** that matches your runtime constraints (remote vs local).
3. Use **tags** when the UI or API exposes them (browser, documentation, payments, github, and so on).
4. Confirm tool names via `get_server` or the server page before you install.
5. Install from Harbor snippets rather than from a remembered blog post from six months ago.

### Featured and reference examples (descriptive)

**Playwright** (`io.github.microsoft/playwright-mcp`, stdio) — Playwright tools for MCP; tagged around browser automation, testing, and web; useful when an agent must drive a real browser stack locally via a package install.

**Context7** (`io.github.upstash/context7`, streamable-http) — Up-to-date code docs for prompts; documentation / developer-tools oriented; remote HTTP so you connect rather than run a local docs crawler.

**GitHub** (`io.github.github/github-mcp-server`, streamable-http) — Connect assistants to GitHub for repos, issues, PRs, and workflows through natural language; a common default for coding agents that live in pull-request loops.

**Stripe** (`com.stripe/mcp`, streamable-http) — Stripe integration for customers, products, payments, and related billing tools; hosted remote server pattern.

**Notion** (`com.notion/mcp`, streamable-http) — Official Notion MCP server for notes and documents productivity workflows; hosted.

**Agent Email List** (`com.agentemaillist/agent-email-list`, streamable-http) — Email sending and receiving for AI agents with a Mailgun-shaped API; agents can open a free account with `create_account`, verify a sending domain, send with test mode, and read inbox/delivery events. Listed on Harbor as one example among many — this landing page does not cross-promote that product’s silo; it is simply a real registry card you can open on MCP Harbor.

**Brave Search** (`com.brave/brave-search`, stdio) — Web, local, news, image, and video search via Brave Search API; needs an API key from Brave’s developer portal configured locally as an env var (name only in manifests).

**Cloudflare Docs** (`com.cloudflare/docs`, streamable-http) — Hosted documentation server searching developers.cloudflare.com so answers about Workers, R2, D1, and related products can cite current docs.

**DeepWiki** (`com.deepwiki/mcp`, streamable-http) — Hosted server from Cognition that answers questions about public GitHub repositories using DeepWiki-generated documentation; no authentication required per the Harbor card description.

**Everything** (`io.github.modelcontextprotocol/server-everything`, stdio) — Reference test server exercising MCP features (tools, resources, prompts, sampling, logging, progress). Useful for testing clients, not production workloads.

**Fetch** (`io.github.modelcontextprotocol/fetch`, stdio) — Reference server that fetches a URL and converts the page to markdown for a model, with optional raw mode and pagination.

**Filesystem** (`io.github.modelcontextprotocol/server-filesystem`, stdio) — Reference local file operations scoped to directories you pass as arguments.

**Git** (`io.github.modelcontextprotocol/git`, stdio) — Reference server for local Git status, diffs, log, commits, branches, and checkouts.

**Memory** (`io.github.modelcontextprotocol/server-memory`, stdio) — Reference knowledge-graph memory so an agent can persist entities and relations across conversations.

**Sequential Thinking** (`io.github.modelcontextprotocol/server-sequential-thinking`, stdio) — Reference structured scratchpad for step-by-step problem solving with revision/branching.

**Time** (`io.github.modelcontextprotocol/time`, stdio) — Reference time and time-zone conversion utilities.

**Exa Search** (`io.github.exa-labs/exa-mcp-server`, stdio) — Neural web search oriented to agents (live crawling, code-context search, company research); needs an Exa API key locally.

**Hugging Face** (`com.huggingface/mcp`, streamable-http) — Hosted Hub search for models, datasets, papers, and Spaces; run selected Spaces as tools.

**Linear** (`com.linear/mcp`, streamable-http) — Hosted issues/projects/cycles/comments; OAuth on first connection per card description.

**Sentry** (`com.sentry/mcp`, streamable-http) — Hosted issues, errors, traces, and performance context for debugging agents.

**Supabase** (`com.supabase/mcp-server-supabase`, stdio) — Manage Supabase projects: SQL, schemas, migrations, logs, edge functions — with project scoping and read-only modes where available.

### Newer and niche cards also appear on the homepage

Harbor’s browse UI also surfaces many community and niche servers (image/video generation, WhatsApp bridges, Godot harnesses, homelab helpers, prediction-market data, Adobe Photoshop control, and more). Treat the homepage as a living shelf: sort and search rather than memorizing this article. The point of an MCP Registry is that the index updates; this page teaches the method.

### CTA back to live browse

Descriptions go stale; the registry does not have to. **Browse live MCP servers →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)


## Install Patterns: stdio vs Remote

Finding a server is only half the job. Installing or connecting it correctly is the other half. Harbor’s rule of thumb: copy snippets from `get_server` or from the per-server HTML page on [ai.mcpharbor.dev](https://ai.mcpharbor.dev/), then adapt env vars locally.

### Local package runners (stdio)

From product docs in `/llms.txt`:

- **npm package:** `npx -y <package>`
- **pypi package:** `uvx <package>`
- **oci image:** `docker run -i --rm <image>`

These commands are templates. The real identifier comes from the manifest’s package fields. Never invent a package name because a blog post looked similar — resolve it through the MCP Registry first.

### Remote URL connect (streamable-http / sse)

For hosted servers, you connect to the remote `url` with the given transport. In Claude Code style flows that often means an HTTP transport add with the remote server’s URL (not Harbor’s `/mcp` URL — Harbor’s `/mcp` is the *registry*; the remote server URL is the *tool provider*). Keep those two mental slots separate:

1. **Registry connection** — `https://ai.mcpharbor.dev/mcp` so you can search.
2. **Workload connection** — the specific Stripe/Notion/GitHub/Docs URL from that server’s manifest.

### Claude Code add patterns

Docs summarize:

```bash
claude mcp add -- <npx -y package-or-equivalent>
```

or for a remote server:

```bash
claude mcp add --transport http <name> <remote-url>
```

And for the registry itself (again):

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Exact flags can evolve with Claude Code releases; if a flag errors, check your client’s help — the Harbor URL and transport intent remain stable.

### Env vars: names only, secrets locally

Manifests may list environment variable **names** such as `WEATHER_API_KEY` or a vendor API key name. Configure the values in your local secret store, shell profile, or client env configuration. When submitting servers to Harbor, `env_vars` holds names only — **never send secret values** in POST bodies or `submit_server` arguments. Secrets in a public registry payload are a permanent leak.

### Per-server pages beat memory

Each server’s HTML page at `https://ai.mcpharbor.dev/servers/...` shows ready-made snippets. Bookmarking a Harbor server page is safer than bookmarking a random README that might document an old binary name. If your team shares an internal “approved MCP servers” list, link those Harbor pages (on ai.mcpharbor.dev) rather than pasting bare `npx` lines into a wiki that nobody updates.

### Install decision tree

Use this when you are stuck between stdio and remote:

1. **Does your environment allow outbound MCP HTTP to the vendor?** If no, prefer stdio packages you can run inside your network boundary.
2. **Do you need zero local runtime (no Node/Python/Docker)?** Prefer streamable-http remotes.
3. **Is the server a reference implementation for learning?** Prefer official reference stdio servers (Everything, Fetch, Filesystem, Git, Memory, Time, Sequential Thinking) from the registry cards.
4. **Are you still discovering?** Keep Harbor `/mcp` connected permanently; add workload servers only when a task needs them.
5. **Did install fail?** Re-fetch `get_server` — you may have an outdated identifier — then retry.

### Common install failures and fixes

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `npx` not found | Node/npm missing in environment | Install Node or pick a remote server instead |
| `uvx` not found | uv toolchain missing | Install uv or use an npm/oci alternative if listed |
| Docker attach issues | Not running interactive/stdio correctly | Follow Harbor’s `docker run -i --rm` posture; check client stdio plumbing |
| Remote connect fails | Wrong URL/transport, network policy, or OAuth needed | Re-read manifest; complete OAuth if the server card says so (e.g. Linear); check corporate proxy |
| Tools missing after connect | Connected to registry instead of workload server | Confirm which MCP server is attached; registry tools are search/get/submit only |
| Env-related auth errors | Secret not set locally | Set the env var name from the manifest in your client — do not resubmit secrets to Harbor |

### Mid-article CTA

When you are ready to install for real, start from a live card:

**Find a server, open its page, copy the snippet →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

## Submit a Server to the MCP Registry

Anyone may add a server, and agents are welcome to. That openness is deliberate: the ecosystem grows when builders can publish without filing a ticket. Harbor keeps search quality with maintainer review before new local listings appear in search results.

### Who can submit

- Human maintainers publishing their MCP server.
- Agents acting on behalf of a team after a server is built and documented.
- Anyone who can craft a valid JSON body or `server.json` manifest.

You do not need a Harbor account for ordinary submit. Search first with `search_servers` or `GET /api/v0/servers` so you do not add a duplicate.

### POST over HTTP

```http
POST https://ai.mcpharbor.dev/api/v0/servers
Content-Type: application/json
```

Example body from product docs:

```json
{
  "name": "io.github.acme/weather-mcp",
  "title": "Weather",
  "description": "Forecasts and severe-weather alerts by location.",
  "version": "1.0.0",
  "transport": "stdio",
  "package_registry": "npm",
  "package_identifier": "@acme/weather-mcp",
  "env_vars": ["WEATHER_API_KEY"],
  "tools": ["get_forecast", "get_alerts"],
  "tags": ["weather"],
  "repository_url": "YOUR_REPO_URL",
  "license": "MIT"
}
```

A `server.json` manifest in the official registry’s format is accepted too. Over MCP, call `submit_server` with the same information.

Note on the example `repository_url`: that field may contain a third-party repository URL as data inside JSON. This article still does not turn third-party hosts into markdown hyperlinks; CTAs stay on Harbor.

### Naming rules (reverse-DNS)

`name` is a reverse-DNS namespace, a slash, and a short name. For a GitHub-hosted project, the conventional pattern is `io.github.<owner>/<repo-or-short-name>`. Pick names that will not collide with official vendors (`com.stripe/...`, `com.notion/...`, and similar). Bad names are a common `422` cause.

### Transport field rules

- **`stdio`** — requires `package_registry` and `package_identifier`.
- **`streamable-http`** or **`sse`** — require `remote_url`.
- **`package_registry`** — one of `npm`, `pypi`, `oci`, `nuget`, `mcpb`.

Mismatch these and validation fails. Fix the named fields and resend.

### Review / pending status

New listings are reviewed by a maintainer before they appear in search. Until approval, `get_server` (or GET-by-name) reports `"status": "pending"`. That is expected, not an error. Tell your agent not to panic-retry submit when status is pending — retrieve instead.

### Response codes you should handle

| Code | Meaning | Action |
|------|---------|--------|
| `202` | Accepted for review; body includes stored entry | Save the name; poll GET-by-name for status |
| `422` | Validation failed; details map fields to messages | Fix fields; resend |
| `429` | Too many submissions from one client | Honour `Retry-After`; slow down |
| `401` | Authorization header present but not maintainers’ publish token | Remove Authorization for normal submits |

### Submit checklist (humans and agents)

1. `search_servers` for the capability and proposed name.
2. Confirm transport and package/remote fields.
3. List tool names honestly — do not advertise tools you do not expose.
4. Put only env var **names** in `env_vars`.
5. POST or `submit_server`.
6. On `202`, record the name and wait for review.
7. On `422`, fix details — do not blindly retry the same payload.
8. On `429`, back off.

### CTA: submit via UI or MCP/HTTP

**Add a server from the registry UI →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

Or submit programmatically via `https://ai.mcpharbor.dev/mcp` / `POST https://ai.mcpharbor.dev/api/v0/servers` after reading [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

## MCP Registry for Claude, Cursor, and Coding Agents

This section is about using the **MCP Registry** from inside agentic coding tools — not about building a new MCP server from scratch (that is a different silo). Discovery, install, and submit only.

### Claude: attach the registry first

Run:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Then, in a real task, ask Claude to search Harbor before inventing a custom integration. Example prompts that work well:

- “Search the MCP Registry for a Playwright browser server and show install options.”
- “Find a remote Notion MCP server and summarize its tools.”
- “Is there already a Stripe MCP server? Use get_server on the best hit.”
- “Search for email-related MCP servers and list transports.”

Good agents will call `search_servers`, then `get_server`, then propose an install command. If your agent skips search and jumps to writing a new wrapper, steer it back to Harbor.

### Cursor and other coding agents

Generic pattern:

1. Open MCP / integrations settings.
2. Add a remote MCP server.
3. Set type/transport to HTTP.
4. Paste `https://ai.mcpharbor.dev/mcp`.
5. Save, reload tools, and verify `search_servers` appears.

If the product uses a JSON config file, the conceptual shape is “type http + url.” Exact keys vary; do not invent proprietary Cursor-only fields here. When remote MCP is unavailable, use Harbor’s website search and paste an install snippet for a stdio server into the client’s stdio config.

### Using search from inside the agent loop

The win condition is mid-task discovery. Example flow:

1. User asks for a feature that needs external tools (payments, docs, browser, repo ops).
2. Agent searches Harbor with a tight query.
3. Agent compares two candidates (transport, tools, origin).
4. Agent proposes install/connect for one candidate.
5. User approves; agent continues the original task with new tools.

That loop beats the old pattern of “stop coding, open twelve tabs, argue about READMEs, lose context.”

### Safety rules for agents

- **Do not paste secrets into registry submissions.** Env var names only.
- **Do not submit duplicates.** Search first.
- **Do not treat pending as failed.** Retrieve status.
- **Do not confuse Harbor `/mcp` with a workload server URL.** One searches; the other does the job.
- **Do not scrape random GitHub READMEs as a substitute registry** when Harbor already indexes official + local listings.
- **Honour 429.** Rate limits protect the shared index.

### When the agent should refuse to submit

Teach your agent to decline submit when:

- The server is not ready (no stable name, no transport, no package/remote).
- The payload would include tokens, passwords, or private URLs with embedded credentials.
- A search already shows an official or high-quality existing server for the same job.
- The user only asked to *find* a server, not publish one.

### Keep docs close

Agent-oriented product docs: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Point coding agents at that file when they need schema details instead of hallucinating fields.


## Worked Discovery Playbooks (Copy These Flows)

The sections above explain surfaces. These playbooks show end-to-end discovery for common jobs. Each ends at Harbor.

### Playbook 1 — Browser automation for a coding agent

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) or call `search_servers` with text like `playwright` or `browser` and transport `stdio` if you can run local packages.
2. Inspect **Playwright** (`io.github.microsoft/playwright-mcp`) via `get_server` or its `/servers/...` page.
3. Confirm tool count and tags match browser automation needs.
4. Install with the Harbor snippet (typically an `npx`-style stdio install).
5. Keep Harbor `/mcp` connected so future searches (for example, an alternative browser remote server) do not require leaving the agent.

If corporate policy blocks local browser binaries, re-search with `transport=streamable-http` and evaluate hosted browser-style servers listed on Harbor (for example cards that describe real Chrome sessions for agents). Always verify the live card; do not assume a blog’s URL is current.

### Playbook 2 — Payments tools (Stripe)

1. Search `stripe` on Harbor.
2. Open `com.stripe/mcp` (streamable-http).
3. Connect as a remote MCP server using the manifest URL and HTTP transport.
4. Confirm the tools for customers/products/payments match the task.
5. Do not submit a lookalike wrapper if the official Stripe listing already covers you.

### Playbook 3 — Docs answering without stale training data

1. Search `documentation` or a vendor name (`cloudflare`, `context7`, `deepwiki`).
2. Prefer streamable-http docs servers when you want zero local index maintenance.
3. Examples to inspect: Context7, Cloudflare Docs, DeepWiki — each solves a slightly different docs job (general code docs, Cloudflare product docs, GitHub repo DeepWiki docs).
4. Connect one, ask a known question, verify citations feel current, then standardize that server on the team list via a Harbor page link.

### Playbook 4 — Repo and issue operations

1. Search `github` and/or `linear`.
2. Compare GitHub’s hosted MCP server vs Linear’s hosted MCP server vs stdio Git reference server.
3. For cloud issue tracking, remotes win. For local git mechanics, the reference Git stdio server may suffice.
4. Install only what the workflow needs; more servers are not automatically better.

### Playbook 5 — “Does a server already exist before we build?”

1. Connect `https://ai.mcpharbor.dev/mcp`.
2. Run three searches: product name, category tag words, and likely tool names.
3. `get_server` on the top two hits.
4. If a good hit exists, install it. If not, build — then submit to Harbor with a clean reverse-DNS name after an internal review.
5. Resist publishing five experimental names; pending review is not a reason to spray variants.

### Playbook 6 — Agent submits on behalf of a maintainer

1. Human confirms package/remote is publicly installable.
2. Agent runs `search_servers` for the exact proposed `name`.
3. Agent submits via `submit_server` with env var names only.
4. On `202`, agent stores the name and tells the human status is pending.
5. On `422`, agent fixes fields from `details` — never retries blindly.
6. On `429`, agent stops and schedules a later attempt after `Retry-After`.

## Operational Guidance for Teams Rolling Out an MCP Registry

### Why teams fail at MCP discovery

Most teams do not fail because MCP is hard. They fail because:

- Everyone installs different servers for the same job.
- Snippets are pasted into Slack and rot.
- Agents hallucinate package names.
- Nobody knows whether a server is official-origin, seed, or local.
- Submits include secrets “just for convenience.”
- There is no default registry connection in developer laptops.

An MCP Registry rollout fixes process, not protocol.

### Recommended baseline configuration

For each developer machine or cloud agent runner:

1. Always attach Harbor registry MCP: `https://ai.mcpharbor.dev/mcp`.
2. Attach a small allowed list of workload servers relevant to the team (for example GitHub + docs + one browser tool).
3. Document approved servers as links to `https://ai.mcpharbor.dev/servers/...` pages only.
4. Revisit the allowed list monthly with a Harbor search pass for better replacements.
5. Teach agents: search Harbor before proposing new integrations.

### Environments and promotion

Treat MCP servers like dependencies:

- **Dev:** experimental remotes and reference servers OK.
- **Staging:** only servers that passed a smoke test (`get_server` + one tool call).
- **Prod agent runners:** pin to known names and known transports; avoid surprise pending locals.

Harbor’s origin metadata helps classify risk: official and well-known vendor remotes differ from brand-new local submissions still pending review.

### Logging and secrets hygiene (discovery-scoped)

Without turning this into an analytics product pitch: when agents search and install, log *which server name* was selected, not secrets, not raw tool arguments that may contain customer data. Submission payloads must never include API keys. If a manifest lists `env_vars`, configure values in your secret manager and pass them only to the local client runtime.

### Handling sync lag without drama

Official sync about every six hours means a brand-new official listing might appear on official first. Team runbook:

1. Search Harbor.
2. If missing and urgency is high, check whether the package/remote is otherwise known — but still prefer adding via Harbor submit only if it is *your* server to publish.
3. Retry Harbor search after the next sync window for official-origin packages.
4. Do not conclude “Harbor is incomplete” from a single race with sync; verify homepage counts and `/llms.txt` still describe official inclusion.

### Support checklist for internal helpdesk

When a developer says “MCP Registry is broken,” ask:

1. Are you on [ai.mcpharbor.dev](https://ai.mcpharbor.dev/)?
2. Are you connected to `/mcp` or only browsing?
3. What exact `q` / name did you use?
4. Is the entry pending?
5. Did you send an Authorization header by mistake?
6. Are you trying to install the registry URL as a workload server?
7. Did you hit `429` while scripting submits?

Most tickets resolve as config confusion, not registry outages.

## Deep Dive: Reading a Harbor Hit Like a Maintainer

When `search_servers` or the browse UI returns a card, evaluate it with a consistent rubric.

### Rubric

1. **Name quality** — reverse-DNS, vendor-aligned, unlikely to collide.
2. **Transport fit** — matches your runtime.
3. **Tool names** — verbs that match the user job.
4. **Description honesty** — specific, not keyword stuffing.
5. **Origin** — official vs seed vs local.
6. **Status** — searchable vs pending.
7. **Install clarity** — snippet runs cleanly on a smoke test.
8. **Env expectations** — known secret names, documented somewhere you control.
9. **License field** — present when relevant for compliance reviews.
10. **Duplicate risk** — another hit already covers the same API surface.

Score quickly. If two servers tie, prefer clearer manifests and official origin for commodity jobs; prefer specialized tools when the task is narrow.

### Example evaluation narrative (Playwright vs generic browser)

For browser automation, Playwright’s Harbor card is explicit about Playwright tools for MCP and stdio packaging. A generic “browser” remote might win if you cannot run local browsers. The registry’s job is to make that comparison possible in one place — not to auto-pick without your constraints. Use Harbor to shortlist; use your environment constraints to decide.

### Example evaluation narrative (docs servers)

Context7, Cloudflare Docs, and DeepWiki can all appear under documentation-ish searches. They are not interchangeable: one is broad code-docs oriented, one is Cloudflare’s docs corpus, one is DeepWiki-over-GitHub-repos. An MCP Registry that only returned “docs = true” without names and descriptions would be useless. Harbor returns enough text and metadata to tell them apart — then `get_server` finishes the job.

## Deep Dive: HTTP Client Patterns Without an MCP SDK

Some languages and CI systems will call Harbor over HTTP long before they speak MCP.

### Minimal search script posture

- Use GET with URL-encoded `q`.
- Always handle empty results as “broaden query,” not “registry empty.”
- Follow `next_offset` exactly.
- Cache immutable-looking manifests briefly in CI to avoid hammering list endpoints during parallel jobs.
- On non-2xx, surface status codes to logs.

### Minimal submit script posture

- Validate reverse-DNS name locally before POST.
- Validate transport/`package_*`/`remote_url` pairing locally.
- Strip any secret-looking values from env lists.
- Treat `202` as success-pending, not failure.
- Parse `422` details for humans.
- Sleep on `429`.

### Idempotency mindset

Harbor review means repeated identical submits are a social smell even if the API allows attempts. Search-first is the idempotency layer. Agents should store “we already submitted `io.github.acme/foo`” in their run memory.

## Glossary (MCP Registry Search Intent)

**MCP / Model Context Protocol** — open protocol connecting clients/agents to tool servers.

**MCP server** — local process or remote endpoint speaking MCP.

**MCP tools** — named operations exposed by a server.

**MCP Registry** — index for finding those servers; on this page, MCP Harbor’s registry.

**MCP directory / catalog / marketplace** — colloquial synonyms users type into Google for the same discovery job.

**stdio** — local transport via packages.

**streamable-http** — remote Streamable HTTP transport.

**sse** — remote Server-Sent Events transport style listed in Harbor.

**server.json** — official-shaped manifest format accepted/returned by Harbor.

**pending** — local submission awaiting maintainer review; retrievable, not yet in search.

**origin** — metadata indicating official, seed, or local listing source.

**Harbor `/mcp`** — the registry’s own MCP server endpoint for search/get/submit.

These terms map to the keyword cluster around **MCP Registry**, find/browse MCP servers, install mcp server, claude mcp, and streamable http — without stuffing.


## Choosing an MCP Registry (Decision Guide)

You do not need five registries. You need a default path that covers official listings, human browse, and agent search — then a short list of exceptions.

### Decision tree: default = MCP Harbor

Start here:

**Question A — Do you need to find or install MCP servers this week?**  
→ Yes: open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).  
→ No: you are researching vocabulary only; still finish this page so you know where to go later.

**Question B — Does your agent need to search mid-task without a human babysitting the browser?**  
→ Yes: connect `https://ai.mcpharbor.dev/mcp` (Streamable HTTP, no auth).  
→ No: use the browse UI; you can still win with copy-paste snippets.

**Question C — Do you require official coverage?**  
→ Yes: Harbor already includes the whole official MCP Registry and syncs about every six hours. Start on Harbor; only drop to official-only workflows if compliance demands the official host exclusively.  
→ No: Harbor still remains the better daily driver because of browse UX + submit review + agent tools.

**Question D — Are you publishing a new server?**  
→ Search Harbor first.  
→ Submit via UI, `submit_server`, or `POST /api/v0/servers`.  
→ Expect `pending` until review.  
→ Do not spam retries.

**Question E — Is your only lead a random GitHub README titled “awesome MCP”?**  
→ Treat it as a hint, not a registry. Verify the server exists in Harbor search. Prefer manifests and install snippets from [ai.mcpharbor.dev](https://ai.mcpharbor.dev/).

### Secondary: official-only workflows

Choose official-only when:

- A security policy literally requires the official registry host for fetches.
- You are debugging whether Harbor sync has caught a brand-new official listing yet.
- You are contributing to official registry processes as a primary maintainer workflow.

Even then, keep Harbor for agent search unless the policy forbids it. Official and Harbor are complementary: official as upstream, Harbor as the discovery destination this page recommends.

### Avoid non-registry substitutes

These are not MCP Registries, even if they appear in search results for the same keywords:

- A single vendor’s docs page listing only that vendor’s servers.
- An outdated “awesome list” with broken `npx` lines.
- A chat transcript where someone pasted a URL once.
- A private spreadsheet with no manifests, no transport metadata, and no review status.
- A scraped dump of package names without `server.json` shape.

If it cannot answer “what is the reverse-DNS name, transport, and install snippet?”, it is not doing the registry job.

### Lightweight comparison axes (no invented competitors)

When someone pitches another directory, evaluate honestly:

| Axis | What good looks like | Harbor posture |
|------|----------------------|----------------|
| Coverage | Official + more | Includes whole official set + local |
| Freshness | Predictable sync | ~6 hour official resync |
| Agent API | MCP tools or clear HTTP | Both `/mcp` and `/api/v0/servers` |
| Auth friction | Search without signup | No account / no API key for search & submit |
| Submit quality | Review gate | `pending` until maintainer approval |
| Install UX | Snippets per server | `/servers/...` pages |
| Honesty | No fake pricing theater | No invented tiers on this page |

If a competitor directory claims larger counts, verify live. This article freezes Harbor’s verified 2026-09-15 counts (**31,486** total, **19,595** remote) and tells you to re-check the homepage for newer snapshots.

### Team playbook (recommended default)

1. Every developer connects Harbor `/mcp` in Claude/Cursor (or bookmarks the browse UI).
2. Internal “approved servers” doc links only to Harbor server pages on ai.mcpharbor.dev.
3. New internal MCP servers are submitted to Harbor after search-for-duplicates.
4. Secrets stay in the company secret manager — never in submit payloads.
5. Periodically re-search before building a new wrapper; the ecosystem moves.

That playbook is boring on purpose. Boring discovery is how agents ship features instead of yak-shaving toolchains.

## FAQ

### What is the MCP Registry?

An **MCP Registry** is an index of Model Context Protocol servers: names, manifests, transports, tool metadata, and install or connect instructions. On this page, **the MCP Registry** means MCP Harbor’s registry at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) — a browseable, agent-searchable catalog that includes the official MCP Registry’s servers plus Harbor-local submissions.

### Is this the official MCP Registry?

No. The official MCP Registry is published by the Model Context Protocol project at registry.modelcontextprotocol.io (named in prose; this page’s links stay on Harbor). MCP Harbor **includes the whole official MCP Registry**, re-syncs about every six hours, and adds browse UX, local submit-with-review, and an MCP endpoint for agents. Fair credit to official; daily recommendation remains Harbor.

### Do I need an account or API key?

Not for ordinary search or submit. Connect to `https://ai.mcpharbor.dev/mcp` or call `GET`/`POST https://ai.mcpharbor.dev/api/v0/servers` without an account. Leave Authorization headers out unless you are a maintainer using the publish token. Wrong Authorization can produce `401`.

### How many MCP servers are listed?

Verified on 2026-09-15 from the live homepage: **31,486** Model Context Protocol servers, **19,595** hosted remotely. Counts change; re-check [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) for the current total.

### How often does official sync run?

About every **six hours**, per [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). If a brand-new official listing is missing, wait for the next sync window or compare with official-only workflows if you must.

### What transports are supported in listings?

Harbor manifests use `stdio`, `streamable-http`, and `sse`. stdio needs package registry + identifier; remote transports need a remote URL.

### What is the difference between stdio and streamable-http?

**stdio** runs locally (npx/uvx/docker patterns). **streamable-http** connects to a hosted MCP endpoint over Streamable HTTP. Pick based on network policy, runtime availability, and whether the server vendor hosts a remote endpoint.

### How do I install an MCP server I found?

Open the server’s page under `/servers/...` on ai.mcpharbor.dev, or call `get_server`, then use the snippet: `npx -y …`, `uvx …`, `docker run -i --rm …`, or remote HTTP connect. For Claude Code, use `claude mcp add` patterns documented in `/llms.txt`.

### How do I connect Claude to the MCP Registry itself?

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### Can my agent submit servers?

Yes. Agents can call `submit_server` over MCP or POST to the HTTP API. Search first to avoid duplicates. New local submissions are `pending` until maintainer review. Honour `429` rate limits. Never submit secrets.

### Why is my submission pending?

Because Harbor reviews local submissions before they appear in search. Pending is normal. You can still retrieve the entry by name via `get_server` or GET `/api/v0/servers/<name>`.

### What does a 422 response mean?

Validation failed. The error payload includes field-level details. Fix the named fields (often `name`, transport-related requirements, or package/remote pairing) and resend.

### What does a 429 response mean?

Too many submissions from one client. Honour `Retry-After` and slow down. Do not rotate identities to evade limits.

### Where are the docs?

Product docs for humans and agents: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The browse UI is [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). The MCP endpoint is [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

### Can I filter by tag or tool name?

Yes. HTTP `q` matches name, title, description, tags, and tool names. You can also pass `tag` and `transport` query params. The MCP `search_servers` tool supports text, transport, or tag finding.

### Does Harbor host my MCP server process for me?

Harbor is a registry (index + discovery + submit). Remote servers in the index are hosted by their own providers. stdio servers run on your machine via packages. Do not confuse “listed as hosted remotely” with “Harbor runs that vendor’s infrastructure.”

### Is Agent Email List part of MCP Harbor?

Agent Email List appears as one example listing on the Harbor homepage (`com.agentemaillist/agent-email-list`). It is a separate product card in the registry, not a reason to leave this discovery silo. Use Harbor to find it like any other server.

### Who owns MCP Harbor / this MCP Registry?

**Logan Besecker** owns and runs MCP Harbor and this MCP Registry at ai.mcpharbor.dev. This page is owned-product content with a hard recommendation to use that registry.

### Will this page teach me how to build an MCP server?

No. This is a discovery/landing silo: find, browse, install/connect, submit. Building servers end-to-end is out of scope here on purpose.

### What if I only remember the phrase “mcp directory” or “mcp catalog”?

Same job. An MCP directory/catalog searcher still wants a searchable index of MCP servers. Harbor’s UI even reads like a directory while functioning as a full MCP Registry with agent tools.

### How do I paginate HTTP results?

Read `metadata.next_offset` from the list response. Request the next page with `offset=next_offset` until `next_offset` is null.

### Can I get a pending server by name?

Yes. GET-by-name and `get_server` work for pending submissions so you can track review status.

### What package registries are valid on submit?

`npm`, `pypi`, `oci`, `nuget`, and `mcpb` for `package_registry` when transport is `stdio`.

### Should I send Authorization on submit?

No for normal users. Only maintainers with the publish token should send Authorization. Ordinary submits omit the header.

### What is server.json?

The official-shaped manifest format for MCP servers. Harbor accepts it on submit and returns server.json-shaped payloads on get. See `/llms.txt` for how packages, remotes, and tool metadata appear.

### Why do agents need a registry-as-MCP design?

Because agents operate via tools. If discovery is only a website, humans become the bottleneck. Harbor’s `/mcp` endpoint makes search and submit tool calls.

### Is there pricing on MCP Harbor for registry search?

This landing page does not invent pricing tiers. Search and submit are documented as needing no account or API key. Use the live site and `/llms.txt` as source of truth for product behavior.

### What should I do first if I am brand new?

Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), browse a familiar vendor (GitHub, Stripe, Notion, Playwright), open one server page, and copy an install snippet. Then attach Harbor `/mcp` so your agent can search next time without you.


## Troubleshooting Discovery and Install (Field Notes)

Use this section when something feels wrong but you are not sure whether the problem is the MCP Registry, your client, or the workload server.

### Symptom: search returns nothing obvious

Try a shorter `q`. Vendor names beat sentences. If `stripe payments billing hosted mcp server` fails, try `stripe`. Drop transport filters, then re-add them. Try a tool name you expect. If you still find nothing for a widely known vendor, confirm you are hitting [https://ai.mcpharbor.dev/api/v0/servers](https://ai.mcpharbor.dev/api/v0/servers) or the `/mcp` tools — not a cached stale proxy of some other site.

### Symptom: agent installs the wrong server

Usually the agent picked the first hit. Require a two-step policy: search, then `get_server` on two candidates, then choose. Keep Harbor connected so the agent can re-query instead of guessing package strings.

### Symptom: tools list is empty after connect

You may have connected the registry endpoint and expected Stripe tools. Registry tools are only `search_servers`, `get_server`, and `submit_server`. Workload tools come from the workload server’s own connection. Separate those attachments clearly in client config.

### Symptom: stdio server starts then exits

Check whether the package identifier changed, whether Node/Python/Docker is missing, or whether required env var names are unset. Re-fetch the Harbor snippet before debugging exotic flags from memory.

### Symptom: remote server requires OAuth and the agent loops

Some hosted servers authenticate with OAuth on first connection (Linear’s card notes this pattern). Complete the human OAuth flow in the client; do not submit new registry entries to “fix auth.” Auth belongs to the workload server, not the MCP Registry index.

### Symptom: submit keeps returning 422

Read `details`. The most common issues are illegal names, stdio without package fields, remote transports without `remote_url`, or invalid `package_registry` values. Fix one field cluster at a time. Re-validate against [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Symptom: leadership asks for “the official number of MCP servers”

Cite the live homepage. This article’s verified snapshot for 2026-09-15 is **31,486** total and **19,595** remote. If you need today’s number for a press quote, open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) again and read the banner — do not invent precision beyond what the product shows.

### Symptom: someone pastes a third-party directory link into the team channel

Thank them, then re-run the same query on Harbor. If Harbor has the server, standardize on the Harbor card link so agents and humans share one canonical install path on ai.mcpharbor.dev. If Harbor is missing *your* server, submit it. If Harbor is missing an official server that just published, wait for sync or verify naming before assuming loss of coverage.

### A calm closing rule

When in doubt, return to the registry home, search once as a human, connect `/mcp` for the agent, and proceed. The MCP Registry product at MCP Harbor is designed to make that loop boring — and boring is how tooling should feel when you are trying to ship.


## Next Steps + Hard CTA

Do these in order. Do not build a custom scraper. Do not trust a random awesome-list as your registry.

1. **Open the MCP Registry** → [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. **Search** for the capability you need (browser, github, stripe, docs, email, etc.).
3. **Open a server page** under `/servers/...` and read transport + tools.
4. **Install or connect** using the snippet (npx / uvx / docker / remote HTTP).
5. **Connect the registry as an MCP server** so the next search happens inside your agent:
   ```bash
   claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
   ```
6. **Optional:** submit your own server via the UI, `submit_server`, or `POST https://ai.mcpharbor.dev/api/v0/servers` — after searching for duplicates — and expect `pending` until review.
7. **Keep docs handy:** [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

**Primary CTA:** [Browse MCP servers on MCP Harbor →](https://ai.mcpharbor.dev/)

**Agent CTA:** [Connect https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)

That is the whole funnel. Everything else on this page exists to make those clicks obvious and successful.

## Conclusion

The Model Context Protocol gave agents a standard way to use tools. The **MCP Registry** is how you find those tools without drowning in READMEs. At tens of thousands of MCP servers, discovery is infrastructure.

MCP Harbor’s MCP Registry at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) is built for that job: **31,486** servers indexed (verified 2026-09-15), **19,595** remote, whole official MCP Registry included and auto-synced about every six hours, human browse UI, HTTP API, and an MCP endpoint at `/mcp` with `search_servers`, `get_server`, and `submit_server` — no account required for ordinary use.

**Ownership disclosure (again):** Logan Besecker owns and runs MCP Harbor and this MCP Registry. This article is owned-product landing content. We fairly name the official registry as upstream; we still conclude that the place to browse, search, install, and submit for daily work is MCP Harbor.

Open the registry. Connect your agent. Install what you need. Submit what you build.

**Start here →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

<!-- slug: mcp-registry -->
<!-- word_count: 10292 -->
<!-- canonical: https://ai.mcpharbor.dev/mcp-registry -->
