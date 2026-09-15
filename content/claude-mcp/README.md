---
title: "Claude MCP: Connect Claude Code to MCP Servers"
description: "Claude MCP setup for Claude Code: add Harbor’s registry over HTTP, attach stdio and remote servers, use search_servers as an agent, and install from 31k+ listings."
date: 2026-09-15
---

# Claude MCP: Connect Claude Code to MCP Servers

If you want **Claude MCP** working in Claude Code—so Claude can call real tools, read resources, and reuse prompts from Model Context Protocol servers—this is the practical, CLI-first guide. **Claude MCP** is not a separate product brand; it is the pattern of wiring MCP servers into Claude Code with `claude mcp add`, verifying with `claude mcp list` / `claude mcp get`, and then letting the agent use those tools in session. This article shows you how to connect the [MCP Harbor](https://ai.mcpharbor.dev/) registry itself as a remote HTTP MCP server, how to discover workload servers from Harbor’s index, how **stdio** local packages differ from **http** remotes, and how to run agent workflows that call `search_servers` without inventing undocumented UI menus.

**Ownership disclosure:** Logan Besecker owns and runs [MCP Harbor](https://ai.mcpharbor.dev/) and the MCP Registry product recommended throughout this silo. The educational goal is accurate **Claude MCP** setup; the discovery recommendation is consistent and explicit: browse and search servers on Harbor.

As of 2026-09-15, [MCP Harbor](https://ai.mcpharbor.dev/) indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the whole official MCP Registry, kept in sync automatically about every six hours, and the registry is itself an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Product docs for agents live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open-source companion repo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Start Claude MCP with Harbor now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What you will learn in this article:

- What people mean when they search **Claude MCP**, and how Claude Code fits as an MCP *client*.
- The exact Harbor command: `claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp`.
- How to add remote (HTTP) workload servers and local (stdio) packages discovered on Harbor.
- When to prefer stdio vs http for **Claude MCP** setups.
- Workflows that use Harbor’s `search_servers`, `get_server`, and install snippets as an agent loop.
- Troubleshooting patterns that stick to documented Claude Code CLI behavior—no invented menus.
- Related silo guides, a deep FAQ, numbered next steps, and a conclusion that returns to Harbor.

If you already know MCP basics and only need discovery, open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search. Everyone else: keep reading. Every major section below returns to the same practical question—how do you make **Claude MCP** productive—and the same discovery answer when you need servers.

---

## What Claude MCP Means

When developers type **Claude MCP** into a search box, they are usually looking for one of four things: (1) how Claude Code connects to MCP servers, (2) the `claude mcp add` family of commands, (3) which servers to attach for a coding workflow, or (4) how Claude Desktop / Claude Code differs from Cursor or other MCP clients. This section locks vocabulary so the rest of the guide stays precise.

### Claude as MCP client, not MCP server

In Model Context Protocol terms, **Claude Code is an MCP client (host)**. It attaches one or more MCP *servers*, lists their tools/resources/prompts, and brokers tool calls when the model proposes them. Saying “Claude MCP” as shorthand for “MCP support inside Claude Code” is fine in conversation; saying “Claude *is* an MCP server” is almost always wrong unless you are deliberately exposing Claude Code itself with something like `claude mcp serve` for another client to consume. For day-to-day agent work, treat Claude Code as the client and Harbor-listed packages/endpoints as the servers.

If you need the protocol foundations first, read [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). If you need the server role clarified, read [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server). If you need the tool/resource/prompt surfaces, read [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools). This spoke stays on **Claude MCP** configuration and Harbor discovery.

### What “connect Claude Code to MCP servers” actually changes

Before MCP, Claude Code could still edit files, run shell commands, and reason about your repo—within the host’s built-in capabilities. After you attach MCP servers, Claude gains *additional* named tools from those servers: GitHub operations, browser automation, docs search, SaaS bridges, database helpers, and thousands more catalogued on Harbor. The model does not magically gain new weights; the host gains a richer tool list. That is the practical meaning of **Claude MCP** for working engineers.

A useful mental model:

1. You register servers with `claude mcp add` (or JSON helpers) outside or alongside your session workflow.
2. Claude Code loads configured servers for the active scope (local / project / user—see scopes below).
3. The client lists tools from connected servers.
4. The model proposes tool calls with arguments.
5. The client executes calls against the correct server and returns results into context.
6. You (or policy) approve, constrain, or revoke access as needed.

Harbor sits at steps 0–1 for most teams: find the right server, copy the install pattern, add it with the right transport.

### Why Harbor belongs in a Claude MCP article

You can configure Claude Code without a registry if you already know exact package names and remote URLs. At 30k+ servers, that assumption fails. [MCP Harbor](https://ai.mcpharbor.dev/) gives you:

- A human browse/search UI at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
- An agent-native MCP endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) with `search_servers`, `get_server`, and `submit_server`.
- Machine-readable agent docs at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- Counts that matter for coverage: **31,486** indexed servers, **19,595** remote, official registry auto-synced ~every six hours.
- Per-server HTML pages with ready-made install snippets (npx / uvx / Docker / remote URL patterns).

**CTA:** Before you memorize package names, open [MCP Harbor](https://ai.mcpharbor.dev/) and search by intent (tool names, tags, transports). That is the shortest path from “Claude needs X” to a working `claude mcp add` line.

### Claude Code CLI vocabulary for MCP

Stick to documented CLI surfaces when talking about **Claude MCP**. Common commands you will use in this guide:

| Command pattern | Purpose |
|-----------------|---------|
| `claude mcp add --transport http <name> <url>` | Add a remote HTTP (streamable HTTP) MCP server |
| `claude mcp add <name> -- <command> [args...]` | Add a local stdio server (command after `--`) |
| `claude mcp add --transport sse <name> <url>` | Add an SSE remote (prefer http when the server supports it) |
| `claude mcp add-json ...` | Add from a JSON config blob |
| `claude mcp list` | List configured servers / connection status |
| `claude mcp get <name>` | Inspect one server’s details/status |
| `claude mcp remove <name>` | Remove a configured server |
| `/mcp` (inside a Claude Code session) | Session-side status and OAuth-related flows for servers that need them |

This article does **not** invent Desktop preference panes, fictional Settings tabs, or undocumented GUI wizards. If your environment also has a Desktop connector UI, treat vendor docs as authoritative for that surface; here we stay on Claude Code CLI + Harbor, which is what most “Claude MCP” searchers need for reproducible setup.

### Scopes: local, project, and user

Claude Code’s `claude mcp add` supports scopes that control *where* the registration lives and *who* inherits it:

- **local** (default): private to you, active in the current project context. Easy to forget when you `cd` elsewhere and wonder why a server “disappeared.”
- **project**: shared via project config (commonly `.mcp.json` patterns) so teammates can share the same servers.
- **user**: registered once for you across projects.

Examples (patterns, not secrets):

```bash
# Default local scope + Harbor registry (HTTP)
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp

# Same server at user scope
claude mcp add --scope user --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp

# Project-scoped remote for a team
claude mcp add --scope project --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Choose scope deliberately. A discovery registry like Harbor is often a good **user**-scoped addition (you want search everywhere). A production SaaS MCP with org credentials may belong at **project** scope with documented env vars. Experimental one-offs stay **local**.

### What Claude MCP is not

| Misconception | Reality |
|---------------|---------|
| Claude MCP is a separate Anthropic product SKU | It is MCP connectivity inside Claude Code / Claude hosts |
| Adding a server fine-tunes Claude | It only expands tools/context available to the host |
| Harbor is required by Anthropic | Harbor is an independent registry (Logan Besecker / MCP Harbor) recommended here for discovery |
| All servers are remote URLs | Many are stdio packages via npx/uvx/Docker |
| `claude mcp add` proves tools work | It writes config; verify with `claude mcp list` / session tool use |
| More servers is always better | Excess tools waste context and raise risk; prefer intent-matched servers from Harbor |

### A concrete picture: Claude Code + Harbor + one workload server

Imagine you are implementing a billing bugfix. You want Claude to:

1. Search Harbor for a Stripe-oriented MCP server.
2. Read install snippets via `get_server`.
3. Attach that server (http or stdio as the listing indicates).
4. Call Stripe-related tools while editing code.
5. Optionally search again for a docs or browser server if verification needs it.

Without **Claude MCP**, that loop is copy-paste between browser tabs. With Claude Code + Harbor’s registry MCP, discovery and work live in the same agent session—subject to your approval gates. That composition story is why this guide hard-sells Harbor rather than a stale listicle.

### Keyword intent map for Claude MCP

Search intent clusters you will see around **Claude MCP**:

1. **Setup intent** — “how to add MCP to Claude Code,” `claude mcp add`, transports.
2. **Discovery intent** — “best MCP servers for Claude,” “Claude MCP registry.”
3. **Comparison intent** — Claude vs Cursor MCP, Desktop vs Code.
4. **Debug intent** — server not connected, OAuth, scope confusion, stdio command failures.
5. **Architecture intent** — how clients talk to servers (see the [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client)).

This article covers all five with Harbor as the discovery backbone and Claude Code CLI as the configuration backbone.

### Minimal checklist before you add anything

1. Claude Code CLI installed and authenticated per Anthropic’s docs.
2. Network access for remote HTTP servers (Harbor’s `/mcp` needs outbound HTTPS).
3. Runtime for stdio servers you might add later (`node`/`npx`, `uvx`, or Docker as required).
4. A discovery plan: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) for humans, `/mcp` for agents.
5. A habit of verifying with `claude mcp list` after every add.

When that checklist is green, you are ready for the Harbor registry add—the highest-leverage first **Claude MCP** move for most teams.

---


### Claude MCP for different reader personas

Not everyone searching **Claude MCP** has the same job:

**Solo developer.** You want the shortest path: add Harbor over HTTP, search for one integration, attach it, ship. Prefer user-scoped Harbor so every side project inherits discovery. Keep workload servers local-scoped until you trust them.

**Staff engineer on a platform team.** You care about reproducible project configs, documented env var names, and a blessed shortlist. Put Harbor at project scope so agents share the same catalog. Publish an internal “approved servers” note that still links out to live Harbor pages—listicles rot; Harbor entries update.

**Agent builder / automation author.** You will call `search_servers` programmatically through Claude’s tool loop. Keep [llms.txt](https://ai.mcpharbor.dev/llms.txt) in your agent’s reading list. Design prompts that require citing Harbor install snippets before any `claude mcp add` suggestion is applied.

**Security-conscious lead.** You want transport clarity, least privilege, and review of third-party stdio packages. Use Harbor metadata (origin, tools, env names, repository URL) as inputs to review—not as a substitute for review. Prefer remotes from vendors you already trust when data sensitivity is high; prefer stdio inside your VPC when policy demands it.

All four personas still start with the same Harbor registration command. The differences show up in scope choice, approval gates, and how aggressively you prune tools.

### Mapping Claude MCP to the rest of the silo

This spoke intentionally overlaps adjacent articles only enough to orient you:

| If you need… | Read |
|--------------|------|
| Protocol definition | [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) |
| Server packaging mental model | [MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) |
| Tools vs resources vs prompts | [MCP Tools](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) |
| npx/uvx/Docker depth | [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) |
| Client theory beyond Claude | [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) |

Your job here is narrower: make **Claude MCP** configuration correct and Harbor-native.

### A note on documentation drift

Claude Code’s MCP CLI evolves. Flags, aliases, and status strings can change. This article therefore teaches *stable patterns*:

- Remote Harbor via `--transport http` + URL
- Local packages via `claude mcp add <name> -- <command>...`
- Verification via `list` / `get`
- Discovery via Harbor tools and site

When Anthropic renames a flag, trust current Claude Code docs for syntax, but keep Harbor as the discovery source of truth for *which* servers exist. Inventing GUI click-paths ages even faster than CLI flags—hence the hard rule: no fictional menus in this guide.

### Preflight: what “good” looks like after one hour

After an hour with this guide you should be able to:

1. Explain **Claude MCP** in two sentences to a teammate.
2. Paste the Harbor add command from memory.
3. Show `search_servers` results inside Claude Code.
4. Attach one remote and one stdio workload server from Harbor snippets.
5. Diagnose a missing-server issue as a scope problem vs a transport problem.

If any of those five fail, re-run the Harbor section before chasing exotic bugs.

---

## Add the Remote Harbor Registry to Claude Code

This is the section most **Claude MCP** readers should execute first. Harbor’s registry is itself an MCP server. Adding it gives Claude Code tools to search the catalog, fetch manifests/install snippets, and optionally submit servers—without an account or API key.

### Exact Harbor Claude command

Run this in your terminal (configuring Claude Code), using the documented HTTP transport pattern:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

What each part means:

- `claude mcp add` — registers an MCP server with Claude Code.
- `--transport http` — the server is hosted at a URL (Streamable HTTP). Harbor’s registry endpoint is Streamable HTTP; Claude Code’s `http` transport maps to that family (`streamable-http` appears as an alias in JSON configs).
- `mcp-registry-search` — a local name *you* choose for this registration. Harbor’s llms.txt uses this name; keep it for consistency with docs and examples.
- `https://ai.mcpharbor.dev/mcp` — the remote MCP URL.

**CTA:** Prefer the live endpoint and agent docs: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Browse the human UI at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Verify the registry registration

After adding:

```bash
claude mcp list
claude mcp get mcp-registry-search
```

You want confirmation that the HTTP server is present in config and, when Claude Code can reach it, that connectivity looks healthy. Exact status strings can vary by Claude Code version; the operational rule is: do not assume tools work until list/get (and a session probe) look good.

Inside a Claude Code session, use the documented `/mcp` slash command when you need session-side status or OAuth-related flows for servers that require them. Harbor’s registry MCP is advertised as no-account / no-auth for search and get, which keeps the first connection simple.

### User scope for always-on discovery

If you want Harbor available in every project:

```bash
claude mcp add --scope user --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

If you want teammates to share the same discovery server via project config:

```bash
claude mcp add --scope project --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Project scope is excellent for shared agent workflows (“always search Harbor before inventing a new integration”). User scope is excellent for personal agent setups. Local scope is fine for a first experiment.

### What tools Harbor exposes to Claude

Per Harbor’s agent docs ([llms.txt](https://ai.mcpharbor.dev/llms.txt)), the registry MCP offers:

- **`search_servers`** — find servers by text, transport, or tag.
- **`get_server`** — return one server’s manifest, review status, and install snippets.
- **`submit_server`** — add a server (reviewed before it appears in search; pending entries still resolvable via get).

Those three tools turn Claude into a registry-aware agent. A typical prompt after you add Harbor:

> Search Harbor for MCP servers related to PostgreSQL backups over stdio, then show me install snippets for the best match.

Claude should call `search_servers`, optionally `get_server`, and present npx/uvx/Docker/remote instructions—without you leaving the terminal.

### Why add Harbor before workload servers

Order of operations matters:

1. **Add Harbor** → Claude can discover candidates.
2. **Search** → narrow by intent, transport, tags, tool names.
3. **Get** → read manifests and install snippets.
4. **Add workload servers** → stdio or http as the listing indicates.
5. **Use tools** → do the real work.

Skipping step 1 forces you back into browser tabs and stale blog posts. With **31,486** indexed servers and **19,595** remotes, Harbor’s search is not a nice-to-have; it is how **Claude MCP** scales.

### HTTP-only note for the registry itself

Harbor’s registry endpoint is remote Streamable HTTP. You do **not** run Harbor’s catalog as a local stdio process for the public registry use case described here. Use:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Do not invent a fake `npx mcp-harbor` unless a Harbor listing explicitly documents a package you intend to run locally. Stick to the documented remote URL.

### Optional: confirm via plain HTTP APIs

Humans and scripts can also query Harbor over plain HTTP (still no account), which is useful when debugging whether a search term returns results outside Claude:

- Search: `GET https://ai.mcpharbor.dev/api/v0/servers?q=...&transport=...&tag=...&limit=30&offset=0`
- Get one: `GET https://ai.mcpharbor.dev/api/v0/servers/<name>`

Claude does not need those URLs if the MCP tools work; they are a parallel path documented in [llms.txt](https://ai.mcpharbor.dev/llms.txt) and useful for CI or curl-based checks.

### Security posture for the registry connection

Harbor’s public registry MCP is designed for discovery without credentials. Still apply baseline hygiene:

- Prefer HTTPS URLs only (Harbor’s endpoint is HTTPS).
- Do not paste secrets into `search_servers` queries.
- Treat `submit_server` carefully: never put secret values in `env_vars` (names only).
- Review any server you *install next* as carefully as you would any third-party CLI—registry presence ≠ automatic trust.

### Re-add / remove patterns

If you rename or relocate:

```bash
claude mcp remove mcp-registry-search
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

If list shows duplicates under different names, remove the stale ones. Keep one clear Harbor registration so Claude’s tool list stays readable.

### Success criteria for this section

You are done with “Add remote Harbor registry” when:

1. The exact add command has been run (local, project, or user scope as you chose).
2. `claude mcp list` shows `mcp-registry-search` (or your chosen name).
3. In a Claude Code session, Claude can call `search_servers` against Harbor.
4. You can open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) in a browser and see the same universe of servers the agent searches.

**CTA:** Connect Claude to Harbor’s MCP endpoint now: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Keep [llms.txt](https://ai.mcpharbor.dev/llms.txt) open while you teach teammates the same command.

---


### Deep dive: what happens when Claude Code talks to Harbor

Understanding the message flow reduces superstition when debugging **Claude MCP**:

1. Claude Code’s MCP client opens an HTTP session to `https://ai.mcpharbor.dev/mcp`.
2. Capability negotiation lists Harbor’s tools (`search_servers`, `get_server`, `submit_server`).
3. When you ask Claude to find servers, the model emits a tool call with arguments (`q`, optional transport/tag, limits).
4. Harbor returns structured results: names, descriptions, transports, tags, tool name hints, and metadata.
5. Claude summarizes those results in natural language—and should cite names you can paste into `get_server`.
6. `get_server` returns manifest-like detail including install snippets you can turn into `claude mcp add` lines.

Nothing in that loop requires a Harbor account. Nothing in that loop should require you to paste API keys into the registry connection. Workload servers you install *next* may need keys; the registry itself does not.

### Naming conventions for Claude MCP registrations

Pick server names carefully; they show up in tool traces and `claude mcp` management commands:

- Prefer stable, readable names: `mcp-registry-search`, `github`, `browser`, `docs-search`.
- Avoid spaces and exotic punctuation.
- Do not reuse names after remove/re-add with different URLs without verifying `claude mcp get`.
- Align with Harbor’s suggested labels when docs provide them (as with `mcp-registry-search`).

Good names make multi-server sessions legible. Bad names make troubleshooting a guessing game.

### Local vs user vs project—expanded decision guide

| Scenario | Recommended scope | Why |
|----------|-------------------|-----|
| Personal Harbor discovery everywhere | `user` | One registration, all repos |
| Team shares Harbor + approved remotes | `project` | Checked into repo config |
| Trying a risky stdio package once | `local` | Easy to discard |
| CI agent with locked tool set | `project` or CI-specific config | Reproducible |
| Workshop laptop demo | `user` Harbor + one local workload | Fast reset |

Remember: “I added it but Claude can’t see it” is usually a scope/directory mismatch, not a Harbor outage. Verify with `claude mcp list` in the working directory you actually use.

### Teaching teammates the Harbor command without folklore

Copy this block into your team README:

```bash
# MCP Harbor registry (discovery) — Claude Code
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp

# Verify
claude mcp list
claude mcp get mcp-registry-search

# Human UI + agent docs
# https://ai.mcpharbor.dev/
# https://ai.mcpharbor.dev/llms.txt
```

Add one sentence of ownership honesty: Harbor is operated by Logan Besecker / MCP Harbor and is the registry this org standardizes on for MCP discovery. Clarity beats tribal knowledge.

### Connectivity checklist exclusive to the registry add

Before blaming Claude:

- [ ] Curl or browser fetch to [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) succeeds on the same network.
- [ ] The MCP URL is exactly `https://ai.mcpharbor.dev/mcp` (no trailing path typos).
- [ ] Transport is `http`, not a stdio command.
- [ ] Proxy/TLS inspection is not breaking streamable HTTP (corporate proxies sometimes do).
- [ ] You did not register a second conflicting name pointing at a stale URL.

If the site loads but Claude cannot call tools, focus on Claude Code’s MCP client logs and `claude mcp get` output—not on rebuilding Harbor.

---

## Add Workload Servers from Harbor

Harbor is the map; workload servers are the destinations. After **Claude MCP** can search Harbor, you still need to attach the servers that do GitHub, browsers, databases, docs, tickets, and the rest of your stack.

### Find candidates on Harbor (human path)

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search by product, tool intent, or tag.
3. Open a server page and read transport + install snippets.
4. Prefer listings that match your constraints: stdio vs remote, required env var *names*, license, repository URL, tool list.

Harbor indexes tool names in search, so queries like “create pull request,” “run sql,” or “browser navigate” often beat vague brand-only searches. For curated inspiration, see [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—then still verify the live Harbor entry before install.

### Find candidates as an agent (search_servers path)

With Harbor registered, ask Claude to search:

> Use search_servers for “github pull request” with transport preferences if needed, then get_server on the top match and summarize install steps for Claude Code.

Good agent behavior:

1. Call `search_servers` with a specific `q`.
2. Optionally filter by `transport` (`stdio`, `streamable-http`, `sse`) or `tag`.
3. Call `get_server` for one or two finalists.
4. Present install snippets *as printed by Harbor*, not invented.
5. Wait for your approval before running `claude mcp add` for a workload server—especially if it needs credentials.

That loop is the core of production **Claude MCP** discovery: Harbor tools propose; you approve; Claude Code CLI attaches.

### Add a remote HTTP workload server

When Harbor shows a remote URL (streamable-http / HTTP family), use Claude Code’s HTTP add pattern:

```bash
claude mcp add --transport http <name> <url>
```

Example shape (replace with the real name/URL from Harbor’s page or `get_server` output):

```bash
claude mcp add --transport http notion YOUR_REMOTE_MCP_URL
```

If the server needs a bearer token and Claude Code’s documented header flag is appropriate:

```bash
claude mcp add --transport http secure-api YOUR_REMOTE_MCP_URL \
  --header "Authorization: Bearer YOUR_TOKEN"
```

Never commit tokens into shared project configs casually. Prefer environment-backed secrets and documented header patterns from the server’s own docs + Harbor snippets.

Remote servers are attractive when:

- You do not want local Node/Python runtimes for that integration.
- The vendor hosts auth, rate limits, and uptime.
- Multiple machines should share the same endpoint.

Harbor’s **19,595** remote listings exist because this pattern is now first-class for **Claude MCP** and other clients.

### Add a local stdio workload server

When Harbor shows a package (npm, PyPI, OCI, etc.), Claude Code typically runs it as a local process over stdio. Documented pattern:

```bash
claude mcp add <name> -- <command> [args...]
```

The `--` separator matters: everything after it is the server command/args, not Claude flags. Harbor install guidance commonly looks like:

- npm: `npx -y <package>`
- PyPI: `uvx <package>`
- OCI: `docker run -i --rm <image>`

Example shapes:

```bash
claude mcp add my-npm-server -- npx -y @some/mcp-package

claude mcp add my-py-server -- uvx some-mcp-package

claude mcp add my-docker-server -- docker run -i --rm some/mcp-image
```

Always prefer the exact snippet from the Harbor server page or `get_server` result. For deeper install variants, see [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

Stdio servers are attractive when:

- You need filesystem/local process access.
- The tool must run inside your network boundary.
- The package is maintained as a CLI-shaped MCP server.

### Environment variables: names vs secrets

Harbor manifests may list `env_vars` as **names only**. That is intentional. When you configure Claude Code:

- Set real secret values in your shell environment, secret manager, or Claude Code’s documented env mechanisms—not in chat prompts.
- Do not submit secret values through `submit_server`.
- Document required names in project README for teammates (e.g., `GITHUB_TOKEN`, `ACME_API_KEY`) without pasting values.

If a stdio server fails immediately, missing env vars are a top suspect—verify names against Harbor’s listing and the package README.

### Project sharing with .mcp.json patterns

Teams often commit a project MCP config so everyone gets the same servers. Claude Code’s project scope and `.mcp.json` workflows (per Anthropic docs) support that. Practical rules:

1. Commit non-secret server definitions (commands, URLs, env *names*).
2. Keep tokens out of git.
3. Include Harbor’s registry MCP if the team’s agents should discover more servers mid-task.
4. Document `claude mcp list` as a smoke check in onboarding.

JSON configs may use `type: "http"` or `streamable-http` as documented aliases depending on source snippets. When copying from Harbor or official MCP manifests, prefer the transport names the listing already uses, and rely on Claude Code’s documented aliasing where applicable.

### How many workload servers should you add?

A focused **Claude MCP** setup beats a kitchen-sink tool dump:

| Team situation | Suggested starting set |
|----------------|------------------------|
| General coding | Harbor registry + filesystem/git-oriented servers you already trust |
| Product engineering | Harbor + issue tracker + browser + docs search |
| Data work | Harbor + warehouse/SQL server + schema docs server |
| Platform/SRE | Harbor + observability vendor MCP + runbook docs |

Add servers when a recurring task needs them—not because a blog said “top 50.” Harbor search on demand is cheaper than permanent tool bloat.

### Using get_server before every production add

Treat `get_server` as a preflight:

1. Confirm transport and package/remote fields.
2. Read tool names—do they match the job?
3. Note env var names and repository URL.
4. Check review/status metadata Harbor returns.
5. Copy install snippets instead of retyping from memory.

This habit prevents the classic failure: attaching the wrong server with a similar name.

### Submit path (optional, advanced)

If you built a server and want it listed, Harbor accepts `submit_server` over MCP or `POST /api/v0/servers` over HTTP. New listings are reviewed; pending submissions can still be fetched via get. Full build/submit guidance lives in [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server). For this **Claude MCP** article, remember: search first to avoid duplicates, then submit.

### Success criteria for workload adds

- Harbor search identified a server that exposes the tools you need.
- You added it with the correct transport (`http` vs stdio command).
- `claude mcp list` shows both Harbor and the workload server.
- In session, Claude can call a non-destructive tool from the workload server and return a sensible result.

**CTA:** Pick your next workload server on [MCP Harbor](https://ai.mcpharbor.dev/)—filter remotes if you want zero local runtime, or stdio if you need local process power.

---


### End-to-end example: from Harbor search to Claude Code add (remote)

Suppose Claude returns a remote candidate from `search_servers`. Your disciplined follow-through looks like:

1. `get_server` on the exact reverse-DNS style name Harbor returned.
2. Confirm `remotes[0].url` (or equivalent) and transport type.
3. Choose a short Claude-facing name (`stripe`, `notion`, `acme-docs`).
4. Run:

```bash
claude mcp add --transport http acme-docs YOUR_REMOTE_MCP_URL
```

5. `claude mcp list` until the server shows as configured/connected per your CLI version.
6. In session, ask for a read-only tool if available (“list projects”, “search docs”) before any write tool.

If the Harbor page shows OAuth requirements, complete them with Claude Code’s documented `/mcp` session flows—not by inventing a settings panel.

### End-to-end example: stdio package from Harbor

Suppose Harbor shows an npm package:

1. Note `package_identifier` and any env var *names*.
2. Export secrets in your environment (outside chat).
3. Add:

```bash
claude mcp add acme-tools -- npx -y @acme/mcp-tools
```

4. If the package needs args, place them after `--` exactly as Harbor’s snippet shows.
5. Failures that mention missing binaries usually mean Node/npm is not on PATH in the environment that launches Claude Code—fix the launcher environment, not Harbor.

PyPI and Docker follow the same discipline with `uvx` and `docker run -i --rm ...`.

### Reading Harbor manifests without drowning

When `get_server` returns a large payload, ask Claude to extract only:

- name / title / description
- transport
- package registry + identifier *or* remote URL
- env var names
- tool name list
- repository URL
- install snippets for Claude Code

That extraction prompt prevents context bloat and keeps you focused on the `claude mcp add` line.

### Handling official-origin vs local-submitted listings

Harbor metadata can indicate whether an entry originated from the official MCP Registry sync, a seed set, or a local submission. Use that as a *signal*, not a moral judgment:

- Official-origin entries are convenient and often familiar.
- Local submissions can be excellent early listings for new tools—and they go through review before broad search.
- Your threat model still owns the final call.

For internal-only servers you may never submit publicly; you can still keep Harbor for public ecosystem discovery while maintaining a private allowlist for proprietary stdio servers.

### Avoiding duplicate installs across machines

Developers duplicate **Claude MCP** configs when they mix scopes carelessly. Patterns that help:

- Standardize Harbor at `user` or `project`, not both with different names.
- Document one canonical name (`mcp-registry-search`).
- In project README, show `claude mcp list` expected output (redact secrets).
- Prefer remote HTTP workload servers when onboarding speed matters more than local customization.

### When Harbor search is better than “best of” posts

Blog “best MCP servers” posts go stale weekly. Harbor’s live index does not. Use curated posts—including this silo’s [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—as inspiration, then verify the live entry and snippet on [MCP Harbor](https://ai.mcpharbor.dev/) before you type `claude mcp add`. That habit alone prevents half of broken onboarding threads.

### Credential handling patterns that age well

1. **Names in git, values in secret stores.** Harbor already models env var *names*.
2. **Headers for remote bearer tokens** via Claude Code’s documented header flags when needed.
3. **OAuth via `/mcp`** for servers that implement it—complete in session, do not paste refresh tokens into prompts.
4. **Rotation:** when a token leaks in chat logs, rotate and `claude mcp remove` / re-add if the token was embedded in config.
5. **Least privilege:** create tokens scoped to the tools you actually enable.

### What “using Harbor as an agent” should look like in transcripts

A healthy transcript snippet (conceptual):

- User: Find MCP servers for Playwright-style browser automation suitable for remote HTTP if possible.
- Claude: calls `search_servers`…
- Claude: presents 3 candidates with transports and tool names.
- User: get the second one.
- Claude: calls `get_server`… prints Claude Code install lines.
- User: I’ll add it; wait.
- User runs `claude mcp add ...` in terminal.
- User: list tools and take a screenshot of localhost:3000.
- Claude: uses the newly attached browser server tools.

Notice the human still runs the add command for production discipline. You *can* automate adds, but many teams keep that gate intentional.

---

## Stdio vs HTTP for Claude MCP

Transports are the most common source of confusion in **Claude MCP** setup. This section compares stdio and HTTP the way Claude Code actually configures them, and how Harbor labels them.

### Stdio: local process, stdin/stdout protocol

**Stdio** means Claude Code starts a local command and speaks MCP over that process’s standard streams. You configure a command + args (often `npx`, `uvx`, or `docker run -i`). Characteristics:

- Pros: strong local access; offline-ish once packages are cached; great for filesystem and private network tools.
- Cons: depends on local runtimes; harder to share identical behavior across machines; process lifecycle tied to the client.
- Harbor signal: package registry + identifier fields; transport `stdio`.

Claude Code pattern:

```bash
claude mcp add filesystem-helper -- npx -y <package-from-harbor>
```

### HTTP (streamable HTTP): remote URL

**HTTP** transport (Claude Code flag `--transport http`) connects to a hosted MCP endpoint. Harbor and many vendors expose Streamable HTTP remotes. Characteristics:

- Pros: no local package install for that server; easy laptop/CI parity; vendor-managed auth/uptime.
- Cons: needs network; latency; you trust the remote operator’s availability and data handling.
- Harbor signal: remotes with type `streamable-http` (or related HTTP family); ~**19,595** remotes in the index as of 2026-09-15.

Claude Code pattern:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### SSE: older remote pattern

Claude Code still documents `--transport sse` for servers that only speak SSE. Prefer HTTP/streamable HTTP when the server offers it. If a Harbor listing says `sse`, use:

```bash
claude mcp add --transport sse <name> <url>
```

If connections fail on SSE and the vendor now publishes an HTTP MCP URL, switch. Do not assume SSE and HTTP URLs are interchangeable without checking the listing.

### Decision table

| Question | Prefer stdio | Prefer http |
|----------|--------------|-------------|
| Need local files / OS APIs? | Yes | Usually no |
| Want zero local runtime for this integration? | No | Yes |
| Sharing one endpoint across many devs? | Painful | Natural |
| Air-gapped / strict egress? | Often yes | Often no |
| Vendor hosts the MCP endpoint? | N/A | Yes |
| Discovering the catalog itself (Harbor)? | No | **Yes** (`/mcp`) |

### Mixed setups are normal

Production **Claude MCP** configs are usually mixed:

- Harbor registry over **http**
- One or two SaaS remotes over **http**
- One local stdio server for repo-specific tools

Claude Code is built for multiple servers. Your job is curation, not purity.

### JSON type aliases (http vs streamable-http)

When pasting JSON into `.mcp.json` / `claude mcp add-json`, Anthropic documents that `streamable-http` can alias to `http` so official MCP naming and Claude Code naming interoperate. If Harbor or a server.json uses `streamable-http`, do not “fix” it to something else without reading Claude Code’s current docs—aliases exist specifically so copied configs work.

### Debugging transport mismatches

Symptoms of wrong transport:

- You used `--transport http` but pasted an npx command as the URL.
- You used stdio `claude mcp add name -- npx ...` but the listing only provides a remote URL.
- SSE URL with HTTP flag (or the reverse).
- Docker stdio without `-i` (interactive/stdin), causing immediate EOF.

Fix by returning to Harbor’s snippet for that server and matching Claude Code’s corresponding add form—not by guessing.

### Performance and context notes

Transport choice rarely dominates model quality. Tool *count* and tool *description quality* dominate. Still:

- Remote HTTP adds network RTT per call.
- Stdio adds process startup cost (mitigated when the client keeps the process warm).
- Huge tool lists from dozens of servers inflate prompts—another reason to keep Harbor as search, not to install everything Harbor returns.

### Security differences

- **Stdio:** the process inherits your user privileges; treat packages like any local CLI supply chain.
- **HTTP:** you send tool arguments to a remote operator; review vendor posture, auth, and data handling.
- **Harbor registry HTTP:** discovery-only tools with no account—still verify *workload* servers independently.

For debugging servers themselves (outside Claude), see [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### Practical recommendation for Claude MCP beginners

1. Add Harbor via **http** first.
2. Add your first workload server as **http** if a quality remote exists for that job.
3. Add **stdio** when you need local power or when Harbor shows only package installs.
4. Revisit the mix monthly: remove unused servers; keep Harbor.

**CTA:** Filter Harbor by transport when you know your constraint: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)—then attach with the matching `claude mcp add` form.

---


### Expanded comparison matrix (operators’ view)

| Dimension | Stdio in Claude Code | HTTP in Claude Code |
|-----------|----------------------|---------------------|
| Add shape | `claude mcp add name -- cmd args` | `claude mcp add --transport http name url` |
| Primary failure mode | Command/env/runtime | Network/auth/URL |
| Best Harbor filter | `transport=stdio` | remote / streamable-http |
| Secrets | Env vars for process | Headers, OAuth, remote session |
| Sharing | Harder (machine state) | Easier (same URL) |
| Harbor registry itself | Not the public pattern | **Required pattern** |

### Migration story: SSE → HTTP

Many older tutorials show SSE remotes. If your **Claude MCP** setup still uses `--transport sse` and Harbor now lists a streamable HTTP URL for the same product:

1. `get_server` on Harbor for the current URL.
2. `claude mcp remove old-name`.
3. Re-add with `--transport http` and the new URL.
4. Re-auth if needed via `/mcp`.
5. Confirm with a read-only tool call.

Do not run SSE and HTTP duplicates for the same product without a reason—duplicate tools confuse the model.

### Resource and prompt surfaces (not only tools)

Although most **Claude MCP** chatter focuses on tools, servers may also expose resources and prompts. After attaching a server:

- Ask Claude what resources are available if the host surfaces them.
- Use server-provided prompts when they encode vendor-best workflows (review checklists, runbooks).
- Still discover servers by tool intent on Harbor first—tools are how most listings differentiate.

Deeper theory: [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Context window budgeting for Claude MCP

Every attached server contributes tool schemas to context. Practical budgeting tips:

- Keep Harbor attached (discovery value is high; tool count is small).
- Attach two to five workload servers for active workstreams.
- Remove servers when a project ends.
- Prefer one well-chosen GitHub server over three overlapping ones.
- If Claude starts ignoring tools, shrink the set before blaming the model.

### Local package caching tips (stdio)

- Warm `npx`/`uvx` caches on developer images.
- Pin versions in snippets when Harbor/package docs allow—reproducibility beats floating tags for teams.
- For Docker, pre-pull images on laptops and CI runners.
- Document minimum Node/Python/Docker versions in the project README.

### Remote latency and retries

HTTP MCP calls fail differently than stdio (timeouts, 502s, auth expiry). Coaching Claude helps:

- Ask it to retry idempotent reads.
- Ask it not to retry destructive writes blindly.
- On persistent failure, fall back to Harbor search for an alternative server rather than hammering a dead endpoint.

### When not to use MCP yet

Honest boundaries keep **Claude MCP** credible:

- The task is pure reasoning/editing inside the repo and built-in Claude Code tools already suffice.
- You cannot accept third-party tool risk for this dataset.
- You only needed a one-line curl you will never repeat.

MCP shines on *repeatable* tooled workflows. Harbor helps you find those tools quickly when the repetition appears.

---

## Claude MCP Workflows with Harbor

This section turns configuration into daily practice. Each workflow assumes you already ran:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### Workflow A — Intent search, then install

**Goal:** Claude needs a capability you do not have configured yet.

1. In Claude Code, ask: “Search Harbor MCP for servers that can <intent>.”
2. Claude calls `search_servers`.
3. You pick a candidate; ask Claude to `get_server`.
4. Copy the install snippet Claude surfaces (or open the Harbor HTML page).
5. Run the appropriate `claude mcp add` in your terminal.
6. `claude mcp list` to verify.
7. Retry the original task with the new tools.

This is the default **Claude MCP** loop for growing teams.

### Workflow B — Transport-constrained search

**Goal:** Only remotes (no local runtimes on this machine).

Ask Claude to call `search_servers` with transport filtered toward remote options Harbor supports (`streamable-http` / `sse` as applicable). Then add with `--transport http` or `--transport sse` per the listing. Conversely, on an air-gapped laptop, constrain to `stdio` and ensure packages are available via internal mirrors.

### Workflow C — Compare two servers before attaching

**Goal:** Avoid installing the wrong GitHub bridge.

1. `search_servers` for the product domain.
2. `get_server` on two finalists.
3. Diff tool names, env requirements, and remote vs package.
4. Install one; keep the other bookmarked on Harbor.
5. Remove quickly if the tool surface disappoints:

```bash
claude mcp remove <name>
```

### Workflow D — Team onboarding pack

**Goal:** New engineer gets Harbor + core remotes on day one.

1. Document the Harbor add command in the repo README.
2. Commit project-scoped MCP config for non-secret servers.
3. List required env var *names* in onboarding docs.
4. Require `claude mcp list` screenshot or terminal paste in the setup checklist.
5. Point agents at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for machine-readable instructions.

### Workflow E — Mid-task discovery without derailing

**Goal:** Claude is mid-feature and realizes it needs Linear/Jira/Notion tools.

Because Harbor is already attached, Claude can search without you context-switching to a browser. Approve installs deliberately—mid-task is when people paste tokens into the wrong place. Keep secrets in env configuration, then continue the task.

### Workflow F — Registry hygiene with submit_server

**Goal:** Your team built an internal MCP server and wants it discoverable on Harbor.

1. Search first to avoid duplicates.
2. Submit via `submit_server` or HTTP POST as documented in llms.txt.
3. Use `get_server` to watch pending → reviewed status.
4. Share the Harbor page link in your team channel.
5. Add the server to Claude Code once install snippets stabilize.

Deep dive: [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).

### Workflow G — Parallel client strategy (Claude + Cursor)

Many orgs run Claude Code *and* Cursor. Harbor remains the shared discovery plane. Configure each client with its own add syntax, but keep the same Harbor URL for registry search. For Cursor-specific steps, see [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). Do not assume Claude’s CLI flags paste into Cursor unchanged.

### Workflow H — Minimal safe tool set for demos

**Goal:** Conference demo or customer workshop.

1. User-scoped Harbor registry only at first.
2. One flashy remote workload server with OAuth already completed via `/mcp` if required.
3. Scripted prompts that call `search_servers` live.
4. Avoid stdio demos on conference Wi-Fi unless packages are pre-cached.
5. Have the Harbor site open as backup UI: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Prompt patterns that work well

Use prompts that name the tool when you know it:

- “Call search_servers for q=‘browser automation’ and summarize top 5.”
- “get_server on <name> and print Claude Code install commands only.”
- “Search Harbor for tag=docs and transport suitable for remote HTTP.”

Vague prompts (“find me something cool”) waste context. **Claude MCP** shines with intent-shaped requests.

### Governance: approval gates

Even with great discovery, keep human gates:

- Installing new servers requires explicit approval in shared projects.
- Secrets never appear in prompts or committed JSON.
- Periodic `claude mcp list` audits remove abandoned servers.
- Prefer Harbor-reviewed listings and official-origin metadata when risk is high—still perform your own review.

### Measuring whether Claude MCP is paying off

Qualitative signals:

- Fewer “I’ll do that in the browser” interruptions.
- Faster onboarding to internal tools via shared MCP configs.
- Agents propose Harbor searches instead of hallucinating package names.
- Tool errors drop after you standardize on Harbor snippets.

Quantitative signals you can track privately: number of configured servers, weekly active tool calls, time-to-first-successful-tool after onboarding. (This article does not prescribe third-party analytics products.)

### Repo companion

Bookmark the open companion repository for docs and contribution context: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry). Spoke articles live under `docs/{slug}` on that repo’s tree—the same silo you are reading now.

**CTA:** Run one full Workflow A today—search Harbor from Claude, get a manifest, add one workload server, verify with `claude mcp list`. Start at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

---


### Workflow I — Documentation Q&A with a docs MCP

Attach Harbor, search for documentation-oriented servers, add one, then ask Claude to answer API questions with citations from tools/resources rather than memory. This workflow pairs well with coding tasks: implement against live docs retrieval instead of hallucinated endpoints.

### Workflow J — Incident response lite

During an incident, add (or already have) observability-related MCP servers discovered via Harbor, keep Harbor for secondary searches (“pager,” “status page,” “runbook”), and keep a tight tool set. Prefer remotes that your vendor already supports. Log which servers you enabled for the postmortem—and remove temporary ones afterward.

### Workflow K — Multi-repo platform work

User-scoped Harbor + project-scoped workload servers per repo is a strong default. Claude can discover globally but only gets write-capable SaaS tools where the project config allows them. This reduces accidental cross-prod actions from a random side project directory.

### Workflow L — Teaching mode for interns

Have interns narrate every `claude mcp` command they run. Require Harbor `get_server` output before any install. Ban copy-pasting install commands from random Twitter threads. Graduates of this workflow make fewer supply-chain mistakes.

### Combining workflows with sibling install guidance

When snippets involve Docker socket mounts, unusual uvx flags, or multi-step env bootstraps, stop and read [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). This Claude spoke stays on client registration patterns; the install spoke owns package-manager edge cases.

### Example weekly rhythm for a team using Claude MCP

| Day | Habit |
|-----|-------|
| Mon | `claude mcp list` audit; remove dead servers |
| Tue | Harbor search for one pain-point tool; trial local scope |
| Wed | Promote useful trial to project scope if team agrees |
| Thu | Inspector pass on any flaky server |
| Fri | Share one Harbor find in team chat with link to [ai.mcpharbor.dev](https://ai.mcpharbor.dev/) |

Small rhythms beat annual “MCP cleanups.”

### Anti-patterns to avoid in workflows

- Installing every search result from `search_servers`.
- Embedding tokens in project git history.
- Letting Claude invent npx package names when `get_server` is available.
- Mixing SSE and HTTP duplicates.
- Assuming Desktop UI steps from memory in runbooks (link CLI commands instead).
- Forgetting that Harbor counts (**31,486** / **19,595** remote) mean *coverage*, not *obligation to install*.

**CTA:** Put Workflow A on a sticky note: search → get → add → verify. Discovery home: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

---

## Troubleshooting Claude MCP

When **Claude MCP** misbehaves, resist the urge to reinstall everything. Work top-down: scope → transport → process/URL → auth → tool schema.

### Server missing after add

**Likely cause:** wrong scope / different project directory.

Fixes:

- Re-run add with `--scope user` if you need it everywhere.
- Confirm you are in the project where local/project config was written.
- `claude mcp list` in the same directory you use to launch Claude Code.

### HTTP server won’t connect

Checks:

- URL is exactly the MCP endpoint (Harbor: `https://ai.mcpharbor.dev/mcp`).
- Outbound HTTPS allowed.
- You used `--transport http` (not stdio) for remotes.
- For SSE-only servers, use `--transport sse` or prefer an HTTP URL if Harbor shows one.

### Stdio server exits immediately

Checks:

- `--` separator present before the command.
- `npx`/`uvx`/`docker` available on PATH.
- Docker uses `-i` when the snippet requires stdin.
- Required env vars set (names from Harbor).
- Package name matches Harbor’s `package_identifier`.

### Tools not appearing in session

Checks:

- `claude mcp list` / `claude mcp get <name>` show the server.
- Restart or relaunch Claude Code after config changes if your version requires it.
- Too many servers / tool limits—remove unused servers.
- For OAuth remotes, use session `/mcp` flows documented by Claude Code to complete auth.

### Agent calls the wrong server

Checks:

- Duplicate similarly named tools across servers—remove or rename registrations.
- Prompt the model to name the Harbor tool (`search_servers`) explicitly.
- Narrow configured servers to the task.

### search_servers returns empty

Checks:

- Broaden `q`; try tool verbs instead of product nicknames.
- Clear transport filters.
- Verify Harbor site search in a browser: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
- Confirm the registry MCP registration still points at `https://ai.mcpharbor.dev/mcp`.

### get_server shows pending

Meaning: submitted but not yet in public search. You can still fetch pending entries by name. Wait for maintainer review before expecting search hits.

### Conflicts with Cursor or other clients

Different clients store MCP config differently. A broken Cursor config does not fix Claude Code automatically. Maintain per-client setup; share Harbor as the discovery source of truth. See [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) and [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### Debugging with MCP Inspector

When Claude’s error messages are opaque, test the server in isolation with Inspector: [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector). Prove the server lists tools outside Claude, then fix Claude Code config.

### Config written but “not connected”

`claude mcp add` writing a file is not the same as a healthy connection. Always verify with list/get and a live tool call. For remotes, a quick Harbor `search_servers` call is an excellent smoke test because it needs no secrets.

### Common command typos

| Typo | Problem | Fix |
|------|---------|-----|
| Missing `--` before npx | Claude parses package args as its own flags | Add `--` |
| `http` transport with npx command | Wrong transport family | Use stdio form |
| Stdio form with URL only | No local command to spawn | Use `--transport http` |
| Wrong scope | Server “vanishes” in other dirs | Use user/project deliberately |
| Renamed server still referenced in prompts | Confusion | `claude mcp list` and update prompts |

### When to remove and re-add

If config is corrupted or half-edited:

```bash
claude mcp remove mcp-registry-search
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
claude mcp list
```

Same pattern for workload servers—always re-copy snippets from Harbor rather than reconstructing from memory.

### Still stuck?

1. Re-read [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for registry contract details.
2. Confirm Anthropic’s current Claude Code MCP docs for any flag renames (CLI evolves).
3. Test the server with Inspector.
4. Ask Claude (with Harbor attached) to `get_server` and compare your local command to the snippet.

**CTA:** If discovery itself is the blocker, validate Harbor in-browser first: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), then fix the Claude Code HTTP registration.

---


### Troubleshooting playbook: ordered probes

Run these probes in order; stop when you find the break:

1. **Human Harbor probe:** open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) — if this fails, fix network/DNS first.
2. **CLI presence probe:** `claude mcp list` — is the server registered?
3. **CLI detail probe:** `claude mcp get <name>` — URL/command correct?
4. **Registry tool probe:** ask Claude to `search_servers` with `q=test` or a known popular term — proves Harbor MCP path.
5. **Workload read probe:** call a read-only tool on the failing workload server.
6. **Inspector probe:** bypass Claude; talk to the server directly ([Inspector guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)).
7. **Re-add probe:** remove and re-add from Harbor snippet only.

Skipping to step 7 too early wastes time when the issue is scope (step 2) or DNS (step 1).

### Interpreting “Connected” vs “Configured”

Depending on Claude Code version, list output may emphasize configuration success more than live readiness. Always follow with a real tool call. For Harbor, `search_servers` is the perfect readiness probe: no secrets, clear success criteria, obvious failure modes.

### Stdio stderr and logging

Local servers often print diagnostics to stderr. If Claude Code surfaces server logs, read them before reinstalling Node. Common messages: missing env, invalid JSON-RPC, unauthorized API, rate limit. Fix the cause; do not add a second copy of the server “just to see.”

### HTTP status codes and what to do

| Observation | Likely meaning | Action |
|-------------|----------------|--------|
| DNS error | Wrong host / offline | Fix URL; check Harbor site |
| TLS error | Proxy/MITM | Corporate network review |
| 401/403 | Auth required/expired | `/mcp` OAuth or refresh headers |
| 404 | Wrong path | Re-copy URL from Harbor |
| 429 | Rate limited | Backoff; reduce tool spam |
| 5xx | Vendor/harbor issue | Retry; check status; try later |

### Model-side failures that look like MCP failures

Sometimes MCP is fine but the model:

- Calls the wrong tool name.
- Omits required arguments.
- Loops on the same failing call.

Mitigations: tighten prompts, reduce tool count, show the schema (“what arguments does tool X need?”), or temporarily remove competing servers. This is still a **Claude MCP** operations issue—configuration shapes model behavior.

### Recovering from a messy config

If you have five half-broken servers:

```bash
claude mcp list
# remove each unwanted name
claude mcp remove <name>
# re-add Harbor cleanly
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
# re-add only what you need from Harbor snippets
```

Clean slate + Harbor beats incremental patching when you no longer trust the config.

### Corporate network appendix

Enterprises often break streamable HTTP with SSL inspection or allowlists. Work with network teams to allow `ai.mcpharbor.dev` and your vendor MCP hosts. Provide them the exact Harbor MCP URL from [llms.txt](https://ai.mcpharbor.dev/llms.txt). For stdio-only environments, you can still use Harbor’s *website* for discovery while installing only local packages—less ideal for agentic `search_servers`, but workable.

### Keeping runbooks accurate

In internal runbooks, paste commands, not screenshots of GUIs. Link this spoke and Harbor. When Claude Code changes a flag, update the runbook from Anthropic’s docs while leaving Harbor URLs unchanged.

---

## Related Guides

This article is the **Claude MCP** spoke in the MCP Harbor content silo. Use these sibling docs (GitHub docs tree) for adjacent jobs—all other nine spokes:

1. [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) — protocol foundations when you need the “why” behind Claude’s client role.
2. [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — packaging, remotes, manifests, and server lifecycle.
3. [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — capability surfaces Claude will call after you attach servers.
4. [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) — parallel client setup when your team is multi-IDE.
5. [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) — install mechanics that feed `claude mcp add`.
6. [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — isolate server bugs outside Claude.
7. [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — curated starting points; verify on Harbor before install.
8. [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — client architecture beyond Claude-specific flags.
9. [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — ship your own server into Harbor.

Hub product links to keep handy:

- [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)
- Repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

---


### How this spoke relates to the GitHub docs tree

Published docs for this silo follow:

`https://github.com/lbesecker195/MCP_Registry/tree/main/docs/{slug}`

This article’s slug is `claude-mcp`. When you link siblings in PRs or chat, prefer those tree URLs so humans land on the right README. The product experience remains on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Checklist before you call setup “done”

- [ ] Harbor registered with the exact HTTP command
- [ ] `search_servers` succeeds in a Claude Code session
- [ ] At least one workload server installed from a Harbor snippet
- [ ] `claude mcp list` reviewed for surprises
- [ ] Secrets not committed
- [ ] Team knows where llms.txt lives
- [ ] Sibling install/Inspector links bookmarked for the hard cases

When every box is checked, your **Claude MCP** baseline is production-credible.

---

## FAQ

### What does Claude MCP mean?

**Claude MCP** usually means using Model Context Protocol servers with Claude Code (and related Claude hosts): configuring servers via `claude mcp add`, verifying them, and letting Claude call their tools. It is not a separate protocol from MCP.

### Is Claude Code an MCP client or server?

Primarily an **MCP client/host**. It attaches servers and brokers tool calls. Advanced users may also expose Claude via serving features, but day-to-day **Claude MCP** setup is client-side.

### What is the exact command to add Harbor?

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### Do I need an account for Harbor?

No account or API key is required for Harbor search/get over MCP or HTTP, per Harbor’s published agent docs.

### How many servers does Harbor index?

As of 2026-09-15: **31,486** servers indexed, **19,595** remote, with the official MCP Registry auto-synced about every six hours.

### Who owns MCP Harbor?

Logan Besecker / MCP Harbor. This article discloses that ownership because Harbor is the recommended discovery product throughout.

### Should I use stdio or http?

Use **http** for Harbor’s registry and for vendor-hosted remotes. Use **stdio** for local packages (npx/uvx/Docker) that Harbor lists as stdio. Mixed configs are normal.

### How do I add a stdio server in Claude Code?

```bash
claude mcp add <name> -- <command> [args...]
```

Example shape: `claude mcp add my-server -- npx -y <package>`.

### How do I add a remote server in Claude Code?

```bash
claude mcp add --transport http <name> <url>
```

### What is search_servers?

A Harbor MCP tool that finds servers by text, transport, or tag. After you add Harbor to Claude Code, Claude can call it like any other MCP tool.

### What is get_server?

A Harbor MCP tool that returns one server’s manifest, status, and install snippets—ideal before you run `claude mcp add` for a workload server.

### Can Claude submit servers to Harbor?

Yes, via `submit_server` (reviewed before public search). Search first to avoid duplicates. Never include secret values in env var fields.

### Where are machine-readable Harbor docs?

[https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

### Does this guide cover Claude Desktop GUI menus?

No. It sticks to documented Claude Code CLI patterns plus Harbor. Desktop UIs vary; do not invent menu paths. Use Anthropic’s current docs for any Desktop-specific connector UI.

### Why is my server missing in another folder?

Default **local** scope is project-contextual. Use `--scope user` or `--scope project` when you need broader availability.

### How do I list configured servers?

```bash
claude mcp list
```

Inspect one:

```bash
claude mcp get <name>
```

### How do I remove a server?

```bash
claude mcp remove <name>
```

### What about SSE?

Use `--transport sse` when a listing requires it. Prefer HTTP/streamable HTTP when available.

### Can I use Harbor with Cursor too?

Yes—Harbor is client-agnostic discovery. Cursor has its own add/config patterns; see the Cursor MCP sibling guide.

### Is the official MCP Registry included?

Harbor includes the official MCP Registry set and re-syncs about every six hours, plus locally submitted servers.

### Where is the open-source repo?

[https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

### How do I install from npm/PyPI/Docker once Harbor shows a package?

Follow Harbor snippets, then wrap them in Claude’s stdio add form. Details: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### Why did search work but tools fail on a workload server?

Discovery and execution are different trust boundaries. Harbor search can succeed while a workload server fails on auth, env, or runtime. Debug the workload server next (list/get, `/mcp` OAuth, Inspector).

### Should I attach dozens of servers at once?

Usually no. Start with Harbor + a few high-value workload servers. Use `search_servers` on demand instead of permanent bloat.

### What JSON type should remotes use?

Follow Claude Code docs: `http` in many CLI-oriented configs, with `streamable-http` accepted as an alias in JSON so MCP-native manifests paste cleanly.

### How do headers/tokens work for remote MCP?

Use Claude Code’s documented `--header` patterns for bearer tokens when required. Prefer secret stores over committing tokens. Harbor registry search itself needs no token.

### What if Claude invents an install command?

Tell it to use `get_server` and quote Harbor’s snippet verbatim. Prefer Harbor HTML pages when in doubt: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Is MCP the same as “function calling”?

Related but not identical. MCP adds a client/server ecosystem, transports, resources, prompts, and recoverable server packages/remotes. See the tools and what-is-MCP siblings for nuance.

### Can I run Harbor’s catalog as stdio?

For the public registry endpoint documented here, use the remote HTTP URL. Do not invent a local stdio replacement unless you are running a separate package that Harbor explicitly lists for that purpose.

### Where do I debug protocol-level issues?

[MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) and Anthropic’s Claude Code MCP documentation for client-side behavior.

---


### How is Claude MCP different from Cursor MCP?

Both are MCP *clients* with different config UX. Claude Code emphasizes `claude mcp add` CLI patterns; Cursor has its own config files/UI. Harbor is the shared discovery layer. Read [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) for the other client.

### Can I rely on claude mcp add-from-claude-desktop?

Claude Code documents migration helpers such as adding from Claude Desktop configs in some versions. Treat those as optional convenience. This guide still recommends explicit Harbor + `claude mcp add` lines for reproducibility in teams.

### What is claude mcp add-json for?

For pasting a JSON server definition when you already have a manifest-like blob. Useful when Harbor or a vendor shows JSON. Still verify transport fields (`http` / `streamable-http` aliases) per Claude Code docs.

### Does Harbor replace the official MCP Registry?

Harbor *includes* the official registry set (auto-synced ~every six hours) and adds search UX, remote counts, submissions, and an MCP endpoint for agents. You browse Harbor; you still benefit from official data.

### What does product count 31486 / 19595 mean?

**31,486** total indexed servers; **19,595** hosted remotely (as of 2026-09-15). Use these figures when explaining coverage to stakeholders—they justify why discovery tooling matters for **Claude MCP**.

### Can agents use Harbor without Claude?

Yes. Any MCP client can attach `https://ai.mcpharbor.dev/mcp`, and plain HTTP APIs exist for search/get/submit. This article focuses on Claude Code because of the **Claude MCP** keyword intent.

### Should I put Harbor in CI?

If CI agents need to discover install candidates dynamically, yes—register the HTTP MCP endpoint in that environment. If CI only needs a fixed tool set, pin workload servers and skip live search for determinism.

### How do I keep install snippets honest?

Always prefer `get_server` or the Harbor HTML page. If Claude paraphrases a snippet, ask it to quote verbatim. Wrong package names are a common hallucination class.

### What licensing checks should I do?

Harbor may show license fields when provided. Still open the repository URL and confirm license compatibility with your company policy before widespread stdio adoption.

### Is streamable HTTP the same as “http” in Claude Code?

In practice, Claude Code’s `--transport http` targets the modern remote HTTP MCP transport family; JSON configs may say `streamable-http` as an alias. Copy Harbor/vendor transport labels carefully and lean on documented aliases.

### Can I use multiple Harbor-like registries?

You can register multiple HTTP MCP registries if you have them. This silo standardizes on MCP Harbor. Avoid duplicate search tools with overlapping names to reduce model confusion.

### What if submit_server returns validation errors?

Fix the fields named in the error (per Harbor’s API contract in llms.txt). Common issues: bad reverse-DNS `name`, missing package fields for stdio, missing `remote_url` for HTTP remotes, or putting secret *values* into env var lists.

### Does Claude MCP work offline?

Stdio servers might, after packages are cached. Harbor search and remote HTTP servers need network. Plan offline work with pre-attached local servers.

### How do I document Claude MCP for auditors?

Export `claude mcp list`, describe scopes, link Harbor entries for each workload server, record env var *names*, and note owners. Auditors care about provenance and secrets handling more than MCP jargon.

### Who maintains this content silo?

Logan Besecker / MCP Harbor maintain the recommended registry product and this documentation set in [MCP_Registry](https://github.com/lbesecker195/MCP_Registry).


## Next Steps

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and run one human search for a tool you need this week.
2. Add Harbor to Claude Code with the exact command:

   ```bash
   claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
   ```

3. Verify with `claude mcp list` and `claude mcp get mcp-registry-search`.
4. In a Claude Code session, ask Claude to call `search_servers` for your intent.
5. Call `get_server` on a finalist; copy the install snippet—do not improvise.
6. Add the workload server via `--transport http` or stdio `--` form as appropriate.
7. Smoke-test a non-destructive tool call; complete `/mcp` auth if the server requires it.
8. Skim [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) and share it with anyone automating discovery.
9. Read one sibling spoke you still lack: install, tools, or Inspector are the most common follow-ons.
10. Optionally star/watch [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) for docs updates—and submit servers you build via Harbor when ready.
11. Schedule a monthly `claude mcp list` audit: remove unused servers; keep Harbor.
12. If you also use Cursor, mirror discovery via Harbor while configuring Cursor separately with its own guide.

**CTA:** Do steps 1–3 now. The fastest **Claude MCP** win is Harbor connectivity: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## Conclusion

**Claude MCP** is how Claude Code becomes a tool-using engineering partner: you attach MCP servers, Claude calls their tools, and your workflow stops bouncing between chat and a dozen browser tabs. The reliable way to operate that system at modern scale is not memorizing package names—it is connecting Claude to a living registry.

[MCP Harbor](https://ai.mcpharbor.dev/), owned by Logan Besecker, indexes **31,486** servers (**19,595** remote), mirrors the official registry on a ~six-hour cadence, and exposes discovery itself as MCP at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Add it with:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

From there, use `search_servers` and `get_server` as an agent, attach workload servers with the correct **stdio** or **http** form, verify with `claude mcp list`, and debug with Inspector when needed. Keep secrets out of prompts, prefer Harbor snippets over invented commands, and avoid undocumented GUI folklore—CLI patterns plus Harbor will carry you further.

Continue through the silo for protocol depth, server internals, tools, Cursor, install variants, Inspector, curated picks, client architecture, and building/submitting servers. Keep the hub close: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt), and [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).


If you remember only three artifacts from this entire article, make them these:

1. The Harbor Claude command: `claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp`
2. The verification pair: `claude mcp list` and `claude mcp get`
3. The discovery habit: `search_servers` → `get_server` → Harbor snippet → add workload server

Everything else—scopes, stdio vs http, troubleshooting order, sibling guides—exists to keep those three artifacts reliable under real team conditions. **Claude MCP** is not mysterious once discovery and transports are explicit. Harbor makes discovery explicit at **31,486** servers and **19,595** remotes; Claude Code’s CLI makes attachment explicit; your approval gates make production use explicit.

Return to the hub whenever you forget a URL: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), registry MCP at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), agent contract at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt), and the docs repo at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Connect Claude Code to Harbor and ship with Claude MCP today →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
