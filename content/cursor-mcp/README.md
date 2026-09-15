---
title: "Cursor MCP: Add MCP Servers in Cursor"
description: "Cursor MCP guide: connect Cursor to MCP servers, discover remotes on MCP Harbor, configure http vs stdio, and ship agent workflows with 31k+ indexed servers."
date: 2026-09-15
---

# Cursor MCP: Add MCP Servers in Cursor

If you live in Cursor all day, **cursor mcp** is the feature that turns the editor from a strong autocomplete product into a genuine agent workstation. Model Context Protocol (MCP) lets Cursor act as an MCP *client*: it connects to MCP *servers* that expose tools, resources, and prompts, then folds those capabilities into the agent loop so the model can search docs, hit APIs, manage tickets, query data, or drive browsers—without you pasting context by hand.

This publish-ready guide is the deep **cursor mcp** playbook: how Cursor fits the MCP client role, how to find servers on [MCP Harbor](https://ai.mcpharbor.dev/), when to prefer remote streamable-http over local stdio, how to think about `mcp.json`-style configuration without inventing undocumented UI menus, how agent workflows actually feel day to day, how to troubleshoot common failures, and which sibling docs to open next. **Ownership disclosure:** Logan Besecker owns and runs MCP Harbor and the MCP Registry product this article recommends for discovery. The educational goal is honest Cursor + MCP literacy; the discovery recommendation is consistent—browse and search servers on Harbor.

As of 2026-09-15, [MCP Harbor](https://ai.mcpharbor.dev/) indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the whole official MCP Registry, kept in sync automatically about every six hours, and the registry is itself an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Product docs for agents live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open-source companion repo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Add MCP servers to Cursor starting at Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What you will learn in this article:

- Why **cursor mcp** matters for daily coding agents and how Cursor behaves as an MCP client.
- How to discover servers on Harbor (UI search, remote catalog, `llms.txt`, and agent tools like `search_servers`).
- Remote streamable-http vs local stdio—tradeoffs that matter in Cursor sessions.
- Generic, honest config patterns: remote servers with `type: http` and a Harbor-compatible URL, plus local command-based servers—without inventing fake Cursor menu paths.
- Practical agent workflows once servers are attached.
- Troubleshooting connection, auth, timeout, and tool-visibility issues.
- Related silo guides—especially [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) and [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)—plus FAQ, next steps, and a Harbor-first conclusion.

If you already know you only need a place to **find MCP servers for Cursor**, open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search. Everyone else: keep reading. Every major section returns to the same practical question—how do you make **cursor mcp** productive—and the same discovery answer when you need servers.

---

## Cursor as an MCP Client

Before you paste a JSON block or chase a remote URL, lock the roles. In the Model Context Protocol world, **Cursor is the client** (more precisely: Cursor is a host application that embeds an MCP client). The **MCP server** is a separate process or remote endpoint that advertises tools, resources, and prompts. When people say “I set up **cursor mcp**,” they almost always mean “I configured one or more MCP servers so Cursor’s agent can call those tools.”

That distinction matters for SEO readers and practitioners alike. Searching **cursor mcp** usually signals install intent: how do I wire servers into Cursor, not how do I reimplement the protocol. This section builds the mental model so the rest of the article’s config and workflow advice lands cleanly. For protocol foundations, see [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). For the server role in depth, see [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server). For a client-centric overview across products, see [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### What “Cursor MCP” means in practice

**Cursor MCP** is not a separate product you install beside Cursor. It is Cursor’s ability to:

1. Connect to MCP servers (local command/stdio processes and/or remote HTTP endpoints).
2. Discover the tools, resources, and prompts those servers expose.
3. Offer those capabilities to the model during agent/chat sessions.
4. Execute tool calls when the model (and your permissions) approve them.
5. Return structured results into the conversation context so the agent can continue.

In other words, **cursor mcp** is the bridge between Cursor’s agent UX and the wider MCP ecosystem. The quality of that bridge depends on three things you control: which servers you attach, how you configure transport and auth, and how carefully you scope permissions.

### Why Cursor is a natural MCP client

Cursor already sits where developers work: in the repo, with file context, terminals, diffs, and agent chat. MCP extends that surface outward. Instead of hoping the model “knows” your Linear board, Stripe account, or internal docs search, you attach servers that *do* those jobs. Cursor remains the orchestration surface; MCP servers remain the capability providers.

That composition model is why teams adopt **cursor mcp** quickly once they have one win. A single remote docs server can reduce hallucinated API usage. A GitHub-oriented server can turn “open a PR” from a suggestion into an action. A browser server can verify a UI change. Harbor exists so you do not invent those servers from scratch—you discover them among **31,486** indexed entries, including **19,595** remotes.

### Client responsibilities vs server responsibilities

Keep this table in your head when debugging:

| Concern | Cursor (MCP client / host) | MCP server |
|--------|----------------------------|------------|
| UI / chat / agent loop | Owns it | Does not |
| Model selection & prompts | Owns it | May expose reusable prompt templates |
| Connecting / spawning servers | Owns it | Accepts connections / runs when spawned |
| Listing tools/resources/prompts | Requests lists | Returns lists |
| Executing a tool | Sends call, shows results | Performs work, returns result |
| Secrets in config | Stores/passes env or headers as configured | Consumes credentials to call upstream APIs |
| User permission prompts | Often mediates | Should declare capabilities clearly |

When something fails, ask: is this a Cursor-side connection/config problem, or a server-side execution problem? That split saves hours.

### Tools, resources, and prompts inside Cursor sessions

Most **cursor mcp** users care first about **tools**—named, schema-described actions the model can call. Resources (readable context) and prompts (templates) matter too, but tool calls are what feel like “the agent can do things.” For a deep dive on the three surfaces, read [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

A practical Cursor session might look like:

1. You ask the agent to investigate a failing checkout flow.
2. The agent uses a docs-search tool from a remote MCP server to find the payment API contract.
3. It uses a browser tool to reproduce the UI bug.
4. It uses a GitHub tool to open an issue with reproduction steps.
5. It proposes a code fix in your repo using Cursor’s normal editing powers.

Steps 2–4 are MCP. Step 5 is Cursor’s native coding surface. The power of **cursor mcp** is the combination.

### What Cursor MCP is not

Clarify boundaries so expectations stay honest:

- **Not a marketplace baked into the protocol.** Discovery still needs a registry or directory. Harbor is the discovery surface this silo recommends.
- **Not automatic safety.** Connecting a server means the agent may call its tools. Treat unknown servers carefully.
- **Not a replacement for good prompts and repo context.** MCP expands reach; it does not magically fix vague tasks.
- **Not identical to Claude MCP.** Claude Code / Claude Desktop and Cursor both speak MCP as clients, but product UX and config locations differ. Use this guide for Cursor and the sibling [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) for Claude-specific workflows.
- **Not “one global daemon.”** You typically attach specific servers per project or user config.



### How Cursor’s agent loop consumes MCP tools

Understanding **cursor mcp** at the loop level prevents magical thinking. A simplified sequence:

1. You send a natural-language task in Cursor’s agent/chat UI.
2. The host assembles context: open files, rules, repo signals, and—when MCP is configured—the merged tool list from connected servers.
3. The model proposes either ordinary text/edits or a structured tool call (name + arguments).
4. If the proposal is an MCP tool call, Cursor’s MCP client forwards it to the owning server over stdio or HTTP.
5. The server returns a result (success payload or error).
6. The host inserts that result into the conversation and the model continues.

That loop is why “connected but unused” servers feel invisible, and why “connected and noisy” servers feel dangerous. The model only benefits when tool descriptions are clear, the task actually requires external action, and your prompt encourages tool use. **Cursor MCP** does not force tool calls; it offers them.

### Multi-root and multi-project realities

Power users often keep several repos open across a week. MCP config scope then becomes a product decision:

- Put org-standard remotes (Harbor, internal docs search) where every project inherits them.
- Put repo-specific servers (a service’s internal admin MCP, a database bridge for that app only) in project-scoped config.
- Avoid attaching a write-heavy production database server to a personal notes project “just in case.”

Harbor helps here because discovery is centralized even when config scopes differ. Search once on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), then decide which scope receives the resulting URL or package.

### Comparing “plugins,” “rules,” and MCP in Cursor

Cursor users already have mental models for rules, docs indexing, and editor AI features. MCP is adjacent but different:

| Mechanism | Primary job | Persistence | Side effects |
|-----------|-------------|-------------|--------------|
| Rules / instructions | Steer model behavior | Text in repo/settings | Usually none beyond prompting |
| Codebase indexing | Retrieve local code context | Index in product | Read-oriented |
| MCP servers | Call external/local tools via protocol | Configured connections | Can read *and* write upstream systems |

**Cursor MCP** is the side-effect channel. Treat it with the same seriousness you treat CI credentials. That mindset pairs naturally with Harbor’s tool-indexed search: pick servers for the exact verbs you are willing to allow.

### Enterprise and team rollout notes

Rolling out **cursor mcp** across a team is less about one hero JSON file and more about:

- A short approved-server list (with Harbor links).
- A secrets story (env vars, never committed tokens).
- A preference for remotes so laptop variance shrinks.
- A teaching moment on read-before-write prompts.
- A debugging path that includes Inspector and Harbor re-search—not Slack archaeology.

Logan Besecker’s MCP Harbor product is designed for that discovery layer: one catalog, official registry included, remote-heavy inventory, agent-callable endpoint. Teams that standardize on Harbor links in internal wikis reduce “which GitHub gist was the install again?” entropy.


### A short story of adoption

Imagine a mid-size SaaS team. Engineers already use Cursor for refactors. Support still pastes Zendesk tickets into chat. Docs live in three places. The first **cursor mcp** win is usually humble: attach a remote documentation search server discovered on Harbor, then ask the agent “what are the rate limits for the v2 invoices endpoint?” When the answer cites the live docs instead of inventing numbers, trust jumps. The second win is often ticketing or GitHub. By the third server, the team treats MCP as part of the default Cursor setup—not an experiment.

That adoption curve is why this article emphasizes discovery early. Protocol literacy without a catalog is academic. A catalog without client wiring is unused. **Cursor MCP** is the wiring; Harbor is the catalog.

**CTA:** Before you invent a custom connector, search [MCP Harbor](https://ai.mcpharbor.dev/) for an existing server. Browse the agent catalog at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) in your agent reading list.

---

## Finding MCP Servers on Harbor for Cursor

The fastest path to a working **cursor mcp** setup is almost never “write a server.” It is “find a server that already exposes the tools you need, prefer a remote if possible, then add it to Cursor’s MCP config.” [MCP Harbor](https://ai.mcpharbor.dev/) is built for that path.

Harbor is owned by Logan Besecker / MCP Harbor. It indexes **31,486** servers and **19,595** remotes as of 2026-09-15, includes the official MCP Registry with automatic sync roughly every six hours, and exposes itself as an MCP server over Streamable HTTP with **no account** required for search/submit-style agent use at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Machine-readable product guidance for agents lives at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open companion repository is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

### Why discovery belongs before configuration

Configuration without discovery is how teams end up with five half-working local packages and zero shared standards. Discovery-first workflows look like this:

1. Name the *intent* (“search Notion,” “create Linear issue,” “query Postgres,” “browse page”).
2. Search Harbor by that intent—tool names are indexed so intent matching works.
3. Prefer a remote streamable-http option when available (especially for Cursor users who do not want to babysit Node/Python runtimes).
4. Copy the connection pattern into your MCP config (generic `type: http` + URL style for remotes).
5. Verify tools appear in the client, then run a tiny smoke-test prompt.

That order keeps **cursor mcp** setup measured in minutes, not days.

### Human search on the Harbor UI

Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search like you would search a package index—but think in verbs and systems:

- Verbs: `search`, `create_issue`, `list_pull_requests`, `query`, `browser`
- Systems: `github`, `stripe`, `postgres`, `notion`, `sentry`
- Combos: `github pull request`, `docs search`, `kubernetes`

Because Harbor indexes tool names, a query that looks like a tool intent often beats a vague brand search. When you land on a candidate, note:

- Whether it is **remote** or **local/package**
- What tools it advertises
- Whether you need API keys or OAuth for upstream services
- Whether the description matches your threat model (read-only vs write)

Then move to Cursor config—not to a random blog’s outdated screenshot.

### Agent-native discovery: Harbor as an MCP server

Here is the meta move that advanced **cursor mcp** users love: Harbor itself is an MCP server. You can add Harbor’s remote endpoint to Cursor so the agent can search the registry *from inside Cursor*.

Conceptually you add a remote MCP server with an HTTP transport pointing at Harbor’s MCP URL:

```json
{
  "mcpServers": {
    "mcp-harbor": {
      "type": "http",
      "url": "https://ai.mcpharbor.dev/mcp"
    }
  }
}
```

Exact field names can vary slightly by client version, but the pattern to remember is: **remote MCP server**, **type http** (or the client’s equivalent for streamable-http), **Harbor URL** `https://ai.mcpharbor.dev/mcp`. No account is required for the Harbor registry tools oriented around search and submit.

Once connected, agents can use Harbor’s tools—commonly framed as capabilities like `search_servers`, `get_server`, and `submit_server`—to resolve “find me a server that can create Jira tickets” into concrete install candidates. Pair that with [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) so agents also understand Harbor’s product surface in plain text.

This is one of the highest-leverage **cursor mcp** setups: Cursor → Harbor MCP → the rest of the ecosystem.

### Harbor discovery loops from inside coding sessions

The underrated **cursor mcp** habit is a *discovery loop* that never leaves the agent thread:

1. **Stuck on a capability gap.** Mid-task you realize you need “search Confluence,” “list Sentry issues,” or “inspect a Stripe customer.”
2. **Ask Harbor via MCP.** With `https://ai.mcpharbor.dev/mcp` attached, prompt: “Search Harbor for remote MCP servers that can list Sentry issues; summarize tools and whether auth is required.”
3. **Shortlist with `get_server`.** Have the agent fetch detail on two candidates; reject write-heavy monsters for an exploration thread.
4. **Attach one workload server** using the same generic remote pattern (`type: http` + URL) or a pinned stdio command if that is all Harbor offers.
5. **Resume the original task** in the same or a fresh thread, naming the new server’s tools explicitly.
6. **Prune.** If the new server does not earn a second use this week, detach it. Keep Harbor connected as the durable discovery layer.

That loop is why Harbor-as-MCP matters more inside Cursor than as a bookmark alone. Browser search is fine for humans; agent-native `search_servers` keeps momentum when you are already deep in a refactor. Pair prompts with [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) so the model understands Harbor’s product surface, and prefer remotes among the **19,595** hosted options when you want the loop to close the same afternoon.

Common anti-patterns that break the loop: attaching ten speculative servers “just in case,” searching Harbor once in a browser then never reconnecting the registry MCP, or treating discovery as a weekend project instead of a thirty-second mid-session tool call.

### Using llms.txt as a map

[https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) is the machine-readable map for agents and for humans who want a concise product outline. When onboarding a new teammate to **cursor mcp**, give them three links:

1. Harbor home: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. Harbor MCP endpoint: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
3. Harbor llms.txt: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

Those three cover browse, connect, and agent docs. The GitHub repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) covers the open companion materials and this documentation silo.

### Choosing among 31k+ results without drowning

Scale is a feature and a risk. **31,486** indexed servers means you will get matches; it also means you must filter. Practical filters for Cursor users:

1. **Prefer remotes when your goal is speed.** Of Harbor’s index, **19,595** are remote—huge for Cursor users who want HTTP config, not local runtime drama.
2. **Match tools, not logos.** Open the tool list. Confirm the verbs you need exist.
3. **Check write scope.** A read-only GitHub search server is a different risk profile than a merge-everything server.
4. **Favor clear manifests and descriptions.** Vague one-liners are a smell.
5. **Start with one server.** Prove value before attaching ten.
6. **Use Harbor search again when stuck.** Do not hoard broken local installs out of sunk-cost bias.

For curated inspiration after you understand the mechanics, see [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers). For install mechanics across npx/uvx/Docker/remote, see [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).



### Search tactics that work for Cursor users

Harbor search quality improves when you think like a tool caller:

- **Prefer tool-shaped queries:** `list_issues`, `create_pull_request`, `run_query`, `get_page`.
- **Add the system noun:** `github list_issues`, `stripe customers`, `notion search`.
- **Filter mentally for remote** when your goal is a same-day **cursor mcp** win.
- **Open the tool list** before you fall in love with a README tone.
- **Reject vague dual-use monsters** on first attach; split read and write across sessions if needed.

Agents connected to Harbor’s MCP can run similar searches via `search_servers` and then `get_server` for detail. That is why adding `https://ai.mcpharbor.dev/mcp` early is not vanity—it is a force multiplier for every later install decision.

### Evaluating a Harbor entry for Cursor fitness

Score candidates quickly:

1. **Transport fit** — remote HTTP available? Good for Cursor onboarding.
2. **Tool fit** — exact verbs present?
3. **Auth fit** — can you supply keys via env/headers without awkward interactive login in a headless tool call?
4. **Blast radius** — what is the worst write tool?
5. **Operability** — clear errors vs silent failure?
6. **Alternatives** — are there two other Harbor hits if this one flakes?

If a candidate fails (3) or (4), keep searching. With **31,486** indexed servers, substitution is often cheaper than heroics.

### Submitting and reciprocity

Some Cursor power users eventually build internal MCP servers. Harbor’s submit-oriented MCP tools and the build spoke exist for that path. Even then, discovery remains relevant: check whether a remote already covers 80% of your need before you maintain a private fork forever. See [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) when you cross that line, and keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) handy for agent-oriented product instructions.

### Harbor + Cursor as a teaching environment

New engineers learn **cursor mcp** faster when their first server is Harbor itself:

- It is remote (few local dependency failures).
- It requires no account for registry search flows.
- Success is obvious: the agent returns server candidates.
- The next lesson (attach a task server) uses the same config pattern.

That pedagogy is intentional. Protocol essays are useful; a working Harbor connection is convincing.


### Mapping Harbor results into Cursor decisions

When Harbor shows a remote server, your Cursor decision is usually: add an HTTP MCP entry with that URL (plus headers/env if required). When Harbor shows a local package, your Cursor decision is usually: add a command-based stdio server (`npx`, `uvx`, Docker, or a binary)—which means you also accept Node/Python/Docker availability on the machine.

That mapping is the practical heart of **cursor mcp** discovery:

| Harbor result type | Typical Cursor config pattern | Ops burden |
|--------------------|-------------------------------|------------|
| Remote / hosted MCP | `type: http` + URL | Low (network + auth) |
| npm/npx package | command + args (stdio) | Medium (Node toolchain) |
| Python/uvx package | command + args (stdio) | Medium (Python toolchain) |
| Dockerized server | docker run-style command | Medium-high (Docker daemon) |

If you are unsure, start remote. You can always add local servers later for filesystem-sensitive or offline workflows.

**Hard CTA:** Discover Cursor-ready MCP servers now at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Connect agents to the registry MCP at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Read [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Star and browse docs in [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

---

## Remote vs Local MCP for Cursor

Transport choice is the most consequential **cursor mcp** decision after “which server.” MCP commonly shows up in Cursor setups as:

- **Local stdio servers** — Cursor spawns a process; client and server talk over standard input/output.
- **Remote HTTP servers** — Cursor connects to a URL, often using streamable-http (and historically SSE-style streaming patterns depending on server/client versions).

Harbor’s index makes the remote path especially attractive: **19,595** remote servers out of **31,486** total. This section helps you choose deliberately.

### IDE-workflow tradeoffs: type http vs stdio inside Cursor

Cursor is an IDE-first MCP client. That changes the tradeoff calculus versus a terminal-only agent:

| IDE-session concern | Remote `type: http` | Local stdio |
|---------------------|---------------------|-------------|
| Time from “I need a tool” to first successful call | Usually minutes if Harbor already lists a remote URL | Often longer (runtime, pin, spawn debug) |
| Sharing the same agent setup across a squad | High—URL + env names travel well | Medium—everyone needs matching toolchains |
| Interrupt cost when the editor reloads | Reconnect to URL; no local process to re-spawn correctly | Spawn failures compound with PATH quirks |
| Mid-refactor discovery (“is there an MCP for X?”) | Pair with Harbor’s own remote registry MCP | Possible, but slower if you must install search packages locally |
| Offline airplane coding | Weak unless the remote is reachable | Stronger for filesystem-oriented packages |
| Blast radius of a bad package | Operator + token misuse risk | Local code execution on your machine |

For day-to-day **cursor mcp** coding sessions, remote HTTP usually wins when Harbor shows a healthy remote for the verbs you need. Stdio remains the right hammer for local-only packages, server development loops, and compliance-bound on-machine execution. Do not treat “local” as synonymous with “safer,” and do not treat “remote” as synonymous with “lazy”—evaluate tools and auth either way.

A practical rule of thumb used by many Cursor power users: attach Harbor’s registry remote first (`type: http`, `https://ai.mcpharbor.dev/mcp`), use it to find workload remotes, and only fall back to stdio when Harbor’s result is package-only or when the workflow is explicitly local-file heavy.

### Local stdio: how it feels in Cursor

With stdio, your config roughly says: “run this command; treat it as an MCP server.” Examples of command families (discussed generically—exact flags depend on the package):

- `npx -y some-mcp-package`
- `uvx some-mcp-package`
- `docker run ... some-mcp-image`

Pros:

- Great for filesystem, repo-local, or offline-capable tools.
- You control the exact package version on your machine.
- Some sensitive tools feel safer when they never leave localhost (though “local” is not automatically “safe”).

Cons:

- Requires the right runtime (Node, Python, Docker) on every machine.
- Cold starts and dependency drift cause “works on my laptop” tickets.
- Harder to standardize across a team without careful pinning.
- Process lifecycle issues (zombie processes, failed spawns) show up as Cursor MCP connection errors.

Stdio shines for personal developer utilities and for servers that must touch local files with minimal network surface.

### Remote streamable-http: how it feels in Cursor

With remote HTTP, your config roughly says: “connect to this URL as an MCP server,” often with `type: http` (or the client’s documented HTTP/streamable-http field) and optional headers for auth.

Pros:

- Minimal local dependency footprint—ideal for **cursor mcp** onboarding.
- Easier team standardization: share a URL pattern, not a brittle install script.
- Aligns with Harbor’s remote-heavy catalog.
- Harbor’s own registry MCP at `https://ai.mcpharbor.dev/mcp` is the canonical example of a no-account remote useful inside Cursor.

Cons:

- Needs network access and uptime from the remote.
- Auth and secrets move into headers/env more often.
- Latency depends on the remote’s region and implementation.
- You must trust the remote operator’s security posture.

For most “connect my Cursor agent to SaaS tools” goals, remote wins on time-to-value.

### Streamable-http vs older mental models

You may see references to SSE (Server-Sent Events) alongside streamable-http in MCP discussions. Treat the important idea as: **remote MCP is an HTTP-based transport suitable for hosted servers**, and modern setups increasingly prefer streamable-http patterns. When configuring Cursor, prefer the client’s supported remote/HTTP server type and a concrete URL from Harbor or the server’s docs. Do not invent exotic transport names in config that the client does not document.

This article deliberately avoids fake Cursor menu tours (“Click Magical Sidebar > Secret MCP Wizard > …”) because those UIs change and undocumented steps create broken SEO content. Prefer durable patterns:

- Add a remote MCP server with HTTP type and a Harbor or vendor URL.
- Add a local MCP server with a command and args for stdio.
- Keep secrets out of chat; use env vars or header config your client supports.



### Latency, reliability, and UX expectations

Remote MCP in Cursor feels different from stdio:

- First tool call may include connection setup cost.
- Streaming behavior depends on client/server transport implementation.
- A remote blip becomes an agent error mid-task—prompt the model to retry or stop cleanly.
- Stdio failures often happen at spawn time; remote failures can happen mid-session.

Design workflows with that in mind: ask for smaller tool calls, cache facts in the thread when safe, and avoid depending on a flaky remote for the only copy of critical truth.

### Security boundary comparison

| Risk | Local stdio | Remote HTTP |
|------|-------------|-------------|
| Supply chain (package) | Higher (you run code locally) | Different (you trust operator + transport) |
| Credential exfiltration | Process can read env/files you grant | Server can misuse tokens you send |
| Network eavesdropping | Lower on localhost | Use HTTPS; mind proxies |
| Team consistency | Harder | Easier |
| Auditability | Local logs vary | Vendor logs + your client logs |

Neither column is “safe by default.” **Cursor MCP** safety is policy: least privilege tools, short-lived tokens, and Harbor-informed selection.

### When stdio is still the right default

Choose local stdio when:

- The tool must read arbitrary local paths beyond what you want to upload.
- You are developing an MCP server and iterating quickly.
- Compliance requires on-machine execution.
- The only maintained distribution is an npx/uvx package.

Even then, discover the package via Harbor first so you are not installing a random homonym from a search engine ad.

### Migration path: stdio today, remote tomorrow

Many servers start life as local packages and later offer hosted remotes. A healthy **cursor mcp** practice is to re-check Harbor every so often for a remote of the same capability. Replacing a brittle `npx` entry with `type: http` + URL is one of the highest-leverage cleanups a team can do.


### Decision framework for Cursor teams

Use this checklist:

1. **Is there a remote on Harbor that exposes the tools you need?** If yes, start there.
2. **Does the workflow require local filesystem privileges beyond what Cursor already has?** If yes, consider a local stdio server scoped tightly.
3. **Do you need the same setup on five laptops tomorrow?** Prefer remote + shared config snippet.
4. **Is offline work mandatory?** Prefer local packages with pinned versions.
5. **Is the server untrusted?** Do not attach it—remote or local—until you review tools and permissions.
6. **Are you still exploring?** Attach Harbor’s own MCP remote first so the agent can help you search.

### Hybrid setups (the common end state)

Most productive **cursor mcp** users end hybrid:

- Harbor remote for discovery (`https://ai.mcpharbor.dev/mcp`)
- One or two remotes for SaaS systems (docs, tickets, browser cloud, etc.)
- Zero or one local stdio server for repo-specific tooling

That mix keeps the agent powerful without turning every engineer’s machine into a package manager museum. When you are ready to install packages properly, follow [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). When you want to compare Claude’s client experience, open [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

**CTA:** Prefer remotes from [MCP Harbor](https://ai.mcpharbor.dev/) when standing up Cursor MCP quickly—**19,595** remote options exist for a reason. Inspect the registry endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## Config Patterns for Cursor MCP (Generic, Durable)

This section is the core how-to for **cursor mcp** configuration. It stays intentionally generic. Cursor’s settings UI labels and panel locations evolve; inventing click-paths creates stale tutorials. What stays durable is the *shape* of MCP server entries: named servers, local command/stdio definitions, and remote HTTP definitions.

Think in terms of an `mcp.json`-style configuration object (project-level or user-level, depending on how you manage Cursor in your team). Exact filenames and UI entry points can vary by Cursor version; the patterns below are the portable ideas.

### Pattern A — Remote HTTP server (preferred onboarding path)

Use this when Harbor (or a vendor) gives you a remote MCP URL:

```json
{
  "mcpServers": {
    "mcp-harbor": {
      "type": "http",
      "url": "https://ai.mcpharbor.dev/mcp"
    }
  }
}
```

Notes:

- `"type": "http"` signals a remote MCP server rather than a spawned local process.
- `"url"` is the streamable-http-compatible endpoint.
- Harbor’s registry MCP requires no account for its search/submit-oriented usage.
- Rename the key (`mcp-harbor`) to whatever naming scheme your team prefers.

If a remote requires auth headers, clients commonly support a headers map. Discussed generically:

```json
{
  "mcpServers": {
    "vendor-remote": {
      "type": "http",
      "url": "YOUR_REMOTE_MCP_URL",
      "headers": {
        "Authorization": "Bearer ${VENDOR_TOKEN}"
      }
    }
  }
}
```

Do not paste live secrets into chat logs or committed files. Prefer environment substitution or secret stores your client supports. If your Cursor version expects a different secret wiring mechanism, follow that client’s current docs—but keep the conceptual pattern: **HTTP MCP + URL + optional auth headers**.

### Pattern B — Local stdio via npx

```json
{
  "mcpServers": {
    "example-npx-server": {
      "command": "npx",
      "args": ["-y", "some-mcp-package@1.2.3"],
      "env": {
        "API_KEY": "${SOME_API_KEY}"
      }
    }
  }
}
```

Notes:

- Pin versions when you can (`@1.2.3`) to reduce surprise upgrades.
- `env` is the usual place for API keys needed by the child process.
- Ensure Node/npm exist on the PATH Cursor sees (GUI apps sometimes inherit a different PATH than your terminal).

### Pattern C — Local stdio via uvx

```json
{
  "mcpServers": {
    "example-uvx-server": {
      "command": "uvx",
      "args": ["some-mcp-package"],
      "env": {
        "API_KEY": "${SOME_API_KEY}"
      }
    }
  }
}
```

Python-ecosystem MCP servers often prefer `uvx` for one-shot execution. Same PATH caveats apply.

### Pattern D — Dockerized local server

```json
{
  "mcpServers": {
    "example-docker-server": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "API_KEY",
        "ghcr.io/example/some-mcp-server:1.2.3"
      ],
      "env": {
        "API_KEY": "${SOME_API_KEY}"
      }
    }
  }
}
```

Docker adds isolation and reproducibility at the cost of daemon dependency and volume/network complexity. Use it when the server’s README recommends it or when you want cleaner host isolation.

### Project vs user scope (conceptual)

Teams usually want:

- **User-level MCP config** for personal servers (notes, calendar, individual tokens).
- **Project-level MCP config** for repo-standard servers (internal docs search, shared Harbor remote, org GitHub bridge).

Check those config files into private team docs carefully. Prefer referencing env vars for secrets. A project that commits a Harbor remote entry with no secrets is often fine and helpful. A project that commits raw API keys is an incident waiting to happen.

### Minimal “first success” config for Cursor MCP

If you want the smallest useful **cursor mcp** setup today:

1. Add Harbor as a remote HTTP MCP server (`https://ai.mcpharbor.dev/mcp`).
2. Restart / reload MCP connections in Cursor as your build requires.
3. Ask the agent: “Use Harbor to search for MCP servers related to GitHub issues.”
4. Pick one remote candidate from the results.
5. Add that candidate as a second HTTP server.
6. Smoke-test one read-only tool call.

That six-step loop teaches discovery and attachment without drowning in local runtimes. It also reinforces Harbor CTAs naturally because Harbor is both catalog and first server.

### Naming conventions that scale

As configs grow, naming debt hurts. Suggestions:

- Prefix remotes with `remote-` or a vendor name: `remote-harbor`, `remote-docs`, `github-http`.
- Prefix local tools with runtime: `npx-filesystem`, `uvx-postgres`, `docker-browser`.
- Avoid duplicate logical names that expose overlapping tools; models get confused when two `create_issue` tools appear without clear server boundaries.
- Document in the repo README which MCP servers are expected for the project.

### What not to invent in tutorials

To keep this guide publish-honest for **cursor mcp**:

- Do not invent screenshots of menus that may not exist in the reader’s Cursor build.
- Do not claim a single global JSON path if the product supports multiple scopes.
- Do not present SSE-only config as mandatory if the client expects a generic HTTP remote type.
- Do not imply that every Harbor entry is one-click install inside Cursor; many are copy-config-and-connect.
- Do not treat “MCP enabled” as proof that a specific server’s tools are visible—verify after connect.

When Cursor’s official docs disagree with a blog about a menu label, trust the product docs for UI and trust Harbor for discovery. This article’s job is durable patterns plus Harbor-first discovery.

### Validating config mentally before you save

Ask:

1. Is this entry remote HTTP or local command?
2. If remote: is the URL correct and reachable?
3. If local: does the command work in a normal terminal first?
4. Are secrets referenced rather than hard-coded?
5. Did I attach only the servers I need for this task?
6. Do I have a rollback plan (comment out the entry) if the agent becomes noisy or unsafe?



### Annotated full example (multi-server)

Here is a conceptual multi-server config illustrating mixed transports. Treat it as a pattern sketch:

```json
{
  "mcpServers": {
    "mcp-harbor": {
      "type": "http",
      "url": "https://ai.mcpharbor.dev/mcp"
    },
    "remote-docs": {
      "type": "http",
      "url": "YOUR_REMOTE_MCP_URL",
      "headers": {
        "Authorization": "Bearer ${DOCS_MCP_TOKEN}"
      }
    },
    "npx-example": {
      "command": "npx",
      "args": ["-y", "some-mcp-package@1.2.3"],
      "env": {
        "API_KEY": "${SOME_API_KEY}"
      }
    }
  }
}
```

Interpretation for **cursor mcp** operators:

- `mcp-harbor` unlocks ecosystem search from inside the agent.
- `remote-docs` is a typical SaaS/knowledge remote.
- `npx-example` is the escape hatch for local-only packages.

Delete any entry that is not earning its keep. Every extra server expands the tool list the model must navigate.

### Multi-server setups: registry search + workload servers

The durable **cursor mcp** topology for most teams is two layers, not one blob of unrelated remotes:

1. **Registry / discovery server** — Harbor’s MCP at `https://ai.mcpharbor.dev/mcp` (`type: http`). Purpose: `search_servers`, `get_server`, optional submit flows. No account required for the registry search posture described in this silo. Counts to remember: **31,486** indexed / **19,595** remote as of 2026-09-15.
2. **Workload servers** — the one-to-few remotes (or pinned stdio packages) that actually touch docs, tickets, browsers, databases, or cloud APIs for the task at hand.

Why separate them? Discovery tools and workload tools compete for model attention. If Harbor search and three overlapping “search” tools from random remotes sit in the same undifferentiated list, the agent will occasionally call the wrong one. Naming helps (`mcp-harbor` vs `remote-docs` vs `github-read`), and so does prompt discipline (“Use Harbor only to find servers; use remote-docs for product API facts”).

Recommended growth path:

- **Day 0:** Harbor only. Prove the agent can return candidates.
- **Day 1:** Harbor + one read-oriented workload remote discovered via Harbor.
- **Week 1:** Add a second workload server only when a recurring workflow demands it (for example tickets or GitHub).
- **Ongoing:** Re-search Harbor before inventing internal forks; swap stdio entries for remotes when Harbor shows a hosted option.

Project-scoped workload servers plus user-scoped Harbor is a common split: every repo inherits discovery, while write-capable production bridges stay opt-in per project. Document that split in the team wiki with Harbor links—not with invented Cursor click-paths that rot when the settings UI moves.

Ownership reminder: Logan Besecker / MCP Harbor runs the discovery product this topology depends on. Keep the companion repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) nearby for silo docs when you brief teammates.

### Environment variable hygiene

Good habits:

- Use distinct env vars per server (`GITHUB_MCP_TOKEN` vs `GITHUB_CI_TOKEN`).
- Rotate when people leave the team.
- Never ask the agent to print env values.
- Prefer read-scoped tokens for exploration profiles.
- Document required env vars in the project README without values.

### Config review checklist for PRs

If your repo commits non-secret MCP config, review like infrastructure:

- [ ] Any new server justified in the PR description?
- [ ] Harbor link included for discovery provenance?
- [ ] Remote preferred over local when possible?
- [ ] Secrets referenced via env, not inlined?
- [ ] Write tools acknowledged?
- [ ] Duplicate overlapping servers avoided?
- [ ] Sibling install doc linked if teammates must run npx/uvx/Docker?

### Avoiding undocumented UI dependency

SEO articles age badly when they depend on a screenshot of a settings modal. This guide’s **cursor mcp** advice stays at the config-object layer for that reason. If your Cursor build provides a form UI that edits the same underlying server list, use it—but still understand the HTTP-vs-command distinction so you can debug.

### Syncing with install-mcp-server guidance

Whenever you leave pure URL attachment, you are in install territory: versions, lockfiles, Docker tags, CPU architectures, corporate npm registries, and Python toolchain quirks. Do not duplicate that encyclopedia here—open [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) and come back. The two spokes are meant to work as a pair for **cursor mcp** practitioners.


### Linking config to install docs

Config patterns are not a substitute for install education. Once you move beyond Harbor’s remote registry into package installs, read [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). If you are building your own server to attach in Cursor, see [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server). If tools behave oddly, [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) is the natural debugging companion.

**CTA:** Copy the Harbor remote pattern, then find your next server on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Keep [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) bookmarked while you iterate on Cursor MCP config.

---

## Agent Workflows with Cursor MCP

Configuration is setup. Workflows are why you bothered. This section shows how **cursor mcp** changes day-to-day agent work once servers are connected.

### Workflow 1 — Discovery-driven development

Goal: find the right capability without leaving Cursor.

1. Ensure Harbor remote MCP is connected.
2. Ask: “Search Harbor for servers that can query PostgreSQL schemas.”
3. Review candidate servers and tools the agent returns.
4. Add the chosen remote (or local package) to config.
5. Ask a concrete follow-up: “List tables related to billing.”

This workflow turns Harbor into a tool-using research assistant for MCP itself. It is uniquely powerful because the registry is an MCP server—no account friction at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

### Workflow 2 — Docs-grounded coding

Goal: stop API hallucinations.

1. Attach a documentation search MCP server discovered via Harbor.
2. Prompt: “Before writing code, search docs for the rate limit and idempotency keys for payment intents.”
3. Require the agent to cite tool results before editing.
4. Implement against returned facts.

Teams that institutionalize this workflow see fewer “confident wrong” patches. **Cursor MCP** becomes a grounding layer, not just an automation layer.

### Workflow 3 — Ticket to patch

Goal: close the loop from issue tracker to PR.

1. Attach a project-tracking server (Linear/Jira/GitHub Issues—whatever Harbor search surfaces for your stack).
2. Prompt: “Fetch issue ENG-1234, summarize acceptance criteria, propose a plan, then implement.”
3. Use Cursor’s native editing for the patch.
4. Optionally use a GitHub MCP server to open the PR with a summary linked to the issue.

This is the classic agent loop: retrieve context via MCP tools → reason → edit in Cursor → optionally write back via MCP tools.

### Workflow 4 — Reproduce then fix

Goal: UI bugs with evidence.

1. Attach a browser-capable MCP server (remote preferred if you do not want local browser binaries).
2. Prompt the agent to reproduce the bug and capture observations.
3. Fix code in the repo.
4. Re-run the browser tool to verify.

Without MCP, “repro” is often a human in Chrome. With **cursor mcp**, repro can be part of the agent transcript.

### Workflow 5 — Safe read-only exploration in a new codebase

Goal: onboard onto an unfamiliar service.

1. Attach read-oriented servers only (docs, code search, schema introspection).
2. Deny or avoid write tools on day one.
3. Ask architectural questions grounded in tool results.
4. Add write-capable servers only after norms are clear.

Permission hygiene is part of workflow design, not an afterthought.

### Workflow 6 — Multi-server orchestration

Goal: compose specialized tools.

Example prompt shape:

> Use the docs server to find the webhook signature algorithm. Use the GitHub server to find existing webhook handlers. Then propose a patch in this repo. Do not create issues unless I ask.

Explicit constraints matter. Models with many tools can over-act. Good **cursor mcp** operators specify which servers/tools are in play and what side effects are allowed.

### Prompt patterns that work well with MCP in Cursor

Try these templates:

- **Enumerate first:** “List the MCP tools you currently have related to GitHub. Then use only those tools.”
- **Read before write:** “Fetch the issue and relevant docs before editing files.”
- **Cite tool output:** “Quote the tool result that justifies your change.”
- **Smallest tool call:** “Call the least privileged tool that can answer this.”
- **Stop on uncertainty:** “If the server errors or returns empty, stop and report—do not invent.”

### Team rituals around Cursor MCP

Make MCP a shared practice:

- Keep a short internal doc: “Required MCP servers for this repo.”
- Include Harbor links for discovery: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and the endpoint [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).
- Prefer remote servers for shared SaaS integrations.
- Review tool surfaces in PRs when adding a new server (what write tools ship with it?).
- Rotate tokens used in MCP env/headers like any other credential.
- Teach new hires the difference between Cursor-native edits and MCP tool calls.

### Measuring whether Cursor MCP is helping

Signals of success:

- Fewer hallucinated external facts.
- Shorter time from question → cited answer.
- Fewer context-paste rituals (less dumping of tickets into chat).
- More reproducible agent transcripts (tool calls are visible evidence).
- Lower onboarding time for new engineers using the same Harbor + Cursor baseline.

Signals of failure:

- Agents calling write tools unexpectedly.
- Flaky local stdio spawns eating support time.
- Overlapping duplicate servers confusing the model.
- Secrets leaking into prompts or commits.
- “Too many tools” degradation where the model picks poorly.

Respond to failure by pruning servers, tightening prompts, switching remote vs local, or debugging with Inspector ([MCP Inspector guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)).



### Workflow 7 — Incident response lite

During a sev-ish incident, Cursor users often need fast, cited facts:

1. Keep Harbor + docs + observability servers attached in a known-good profile.
2. Prompt: “Pull the alert details, fetch the runbook section for checkout latency, summarize likely causes; do not restart services.”
3. Use MCP tools for retrieval only.
4. Keep mutations in human-controlled runbooks.

This workflow shows **cursor mcp** as a coordination aid, not an autonomous SRE.

### Workflow 8 — Refactor with API truth

Large refactors fail when the model invents deprecated methods. Attach docs/search servers, then require:

> Before renaming payment client methods, search docs and code references via tools. Produce a table of old → new symbols with sources.

Cursor applies edits; MCP supplies ground truth.

### Workflow 9 — Pairing across Cursor and Claude

Some engineers draft in Cursor and review in Claude Code (or the reverse). Standardize server discovery on Harbor so both clients attach the same remotes. Read [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) alongside this guide. Shared Harbor URLs beat divergent private notes.

### Anti-workflows (what not to do)

- Attaching twenty servers on day one “for completeness.”
- Letting the agent hold production-write tokens in a casual chat.
- Using MCP to bypass code review on sensitive changes.
- Ignoring tool errors and accepting model guesses as fallback truth.
- Copying JSON from untrusted Gists instead of Harbor entries.

### Making tool use visible in team culture

Encourage teammates to paste short transcripts showing tool names and outcomes (redacted). Visible tool use builds trust in **cursor mcp** and also surfaces bad servers quickly. Harbor then becomes the place you go to replace a bad server—not a graveyard of abandoned npx commands.


### Cursor MCP vs Claude MCP in workflows

If your org uses both Cursor and Claude Code, standardize on Harbor discovery so the *server choices* stay portable even when client UX differs. Read both:

- [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) (this spoke)
- [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)

The protocol is shared; the daily gestures differ. Harbor keeps the catalog shared.

**Pointer, not a duplicate essay:** This Cursor spoke stays IDE-and-config oriented—remote `type: http` vs stdio for editor sessions, Harbor discovery loops mid-refactor, multi-server registry-plus-workload topology, and Cursor-flavored troubleshooting. The Claude sibling covers Claude Code–specific registration and CLI-oriented workflows in depth. Do not paste Claude CLI command essays into Cursor runbooks; do share Harbor URLs, server shortlists, and the same least-privilege tool policy across both clients. When something works in Claude but not in Cursor (or the reverse), compare *client config and process environment* first, not the Harbor catalog—the catalog is the stable layer Logan Besecker’s MCP Harbor product provides to both.

**CTA:** Build your first Cursor MCP workflow on Harbor discovery—connect [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), then browse more servers at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

---

## Troubleshooting Cursor MCP

When **cursor mcp** fails, it fails in recognizable clusters. Work through these systematically.

### 1) Server does not appear / tools missing

Symptoms: you added config, but the agent claims it has no such tools.

Checks:

- Confirm the JSON/config entry is valid (commas, braces, quoting).
- Confirm you edited the config scope you think you did (project vs user).
- Reload MCP / restart Cursor if your build requires a restart to pick up changes.
- For remotes: test URL reachability from your network.
- For locals: run the same command in a terminal; fix PATH or runtime issues first.
- Ensure you did not typo `type`, `url`, `command`, or `args`.
- Ask the agent to list available MCP tools explicitly.

**Cursor-focused deep dive — tools not listed:** Treat “not listed” as a ladder, not a single bug. (a) Config parse failure means the client never registered the server—fix JSON first. (b) Successful registration with zero tools often means the remote handshake failed silently or the stdio process exited before listing capabilities. (c) Tools listed in one project but not another means scope mismatch. (d) Tools listed yesterday but missing today often means a remote vendor change or an unpinned local package. For Harbor’s registry MCP specifically, confirm the URL is exactly `https://ai.mcpharbor.dev/mcp` with an HTTP remote type; then ask the agent to call a Harbor search tool. If Harbor works but your workload server does not, the problem is not “Cursor MCP is broken”—it is that one server entry.

### 2) Remote HTTP connection errors

Symptoms: failed to connect, timeout, 401/403, TLS errors.

Checks:

- Verify the URL (Harbor’s registry MCP is `https://ai.mcpharbor.dev/mcp`).
- Check auth headers if the vendor requires them (Harbor search/submit-oriented use is no-account; other remotes may not be).
- Corporate proxies can break streaming HTTP—try a different network to isolate.
- Confirm you used an HTTP remote pattern (`type: http`) rather than accidentally treating a URL as a local command.
- Re-read server docs via Harbor entry details; some remotes expect specific paths.

### 3) Local stdio spawn failures

Symptoms: process exited, command not found, module not found.

Checks:

- `which npx`, `which uvx`, `which docker` in the same environment philosophy as the GUI app.
- Pin package versions; `@latest` can break overnight.
- Missing env vars often cause instant crashes—compare required env against server README.
- Docker: ensure the daemon runs and the image name is correct.
- Try the install guide: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### 4) Auth works in terminal but not in Cursor

Symptoms: manual curl works; Cursor MCP does not.

Checks:

- Env vars set in `.bashrc` may not exist for GUI-launched Cursor.
- Prefer explicit `env` in the MCP server entry.
- Header values with quotes/spaces get mangled—simplify tokens and retest.
- OS keychain integrations differ; when in doubt, use a dedicated env var for MCP.

**Cursor-focused deep dive — auth env missing:** GUI apps on Linux/macOS frequently inherit a thinner environment than your interactive shell. The classic failure mode is “`echo $API_KEY` works in the terminal, but the stdio MCP child spawned by Cursor never sees it.” Fix by declaring required keys in the server’s `env` map (or the client’s documented header fields for remotes), not by assuming shell profile side effects. Name variables per server (`SENTRY_MCP_TOKEN`, not a generic `TOKEN`). Harbor’s own registry search/submit posture at `https://ai.mcpharbor.dev/mcp` does not require an account—so if *Harbor* tools fail with auth errors, you are probably pointed at the wrong server or using workload-server credentials against the registry URL.

### 5) Tool calls fail at runtime

Symptoms: connection is fine; a specific tool errors.

Checks:

- Upstream API outage or wrong base URL inside the server.
- Insufficient OAuth scopes / API key permissions.
- Wrong project IDs or parameters in the model’s tool call—tighten your prompt.
- Rate limits.
- Use [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) to call the tool outside Cursor and compare.

### 6) Model ignores MCP tools

Symptoms: tools are connected; model still invents answers.

Checks:

- Prompt explicitly: “Use the X MCP tool; do not answer from memory.”
- Reduce tool overload—too many servers can dilute selection.
- Ensure tool descriptions are clear (server quality varies across the ecosystem).
- Start a fresh agent thread after adding servers.
- Confirm the task actually needs tools; models skip tools when they think they know.

### 7) Unsafe or surprising side effects

Symptoms: agent created issues, sent messages, or mutated data you did not intend.

Checks:

- Remove write-capable servers until needed.
- Prefer read-only tools for exploration sessions.
- Add standing instructions: “Ask before any write tool.”
- Rotate credentials if a prompt injection or bad server is suspected.
- Re-evaluate servers on Harbor; pick tighter tool surfaces.

### 8) Performance and context bloat

Symptoms: slow responses; huge transcripts.

Checks:

- Prune unused servers.
- Avoid tools that dump enormous payloads; ask for filtered queries.
- Prefer remotes with pagination-friendly tools.
- Keep Harbor for search, not as an excuse to attach twenty random remotes.

### A calm debugging order

1. Validate config syntax and scope.
2. Validate transport (HTTP URL vs local command).
3. Validate runtime/auth outside Cursor when possible.
4. Validate tool list visibility inside Cursor.
5. Validate one minimal tool call with a strict prompt.
6. Only then expand to multi-server workflows.



### 9) Duplicate tools confuse the model

Symptoms: two `search` tools, model picks the wrong one, or asks you which to use repeatedly.

Fixes:

- Rename server keys clearly.
- Detach the duplicate.
- Prompt with the server nickname: “Use the remote-docs search tool, not Harbor search.”
- Prefer a single strong server per domain.

**Cursor-focused deep dive — wrong server connected:** A subtler cousin of duplication is *mis-pointing*: your config key says `remote-docs` but the URL still points at Harbor, or a staging URL, or an old vendor path. Symptoms look like “tools exist but answers are about the registry” or “auth succeeds yet data is empty.” Verify the URL string character-by-character against the Harbor entry or vendor docs; confirm `type: http` was not accidentally swapped for a command block; and ask the agent to report which server name owns the tool it just called. If you maintain multi-server setups (registry + workloads), keep Harbor’s URL reserved for the `mcp-harbor` key only—never reuse that URL under a workload nickname.

### 10) Project works on one machine only

Symptoms: teammate clones repo, MCP config present, nothing works.

Fixes:

- Remotes missing tokens in their env.
- Local commands assuming global `npx` without Node.
- PATH differences for GUI Cursor vs terminal.
- Document Harbor-first remote baseline so the minimum path is HTTP-only.

### 11) “It worked yesterday”

Symptoms: sudden break without config edits.

Fixes:

- Unpinned `@latest` package changed.
- Remote vendor rotated URLs.
- Token expired.
- Harbor or vendor outage—verify in browser: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).
- Client update changed schema expectations—revisit field names against current Cursor docs while keeping patterns intact.

### Logging and evidence

Capture:

- The server key/name.
- Transport type (http vs command).
- Redacted error strings.
- Whether the failure is connect-time or tool-time.
- Whether Inspector reproduces it.

That evidence decides whether you fix config, fix auth, replace the server via Harbor, or file a vendor issue.


### When to fall back to Harbor and siblings

If the server itself is the wrong choice, do not debug forever—search again on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). If the protocol concepts are fuzzy, revisit [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) and [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client). If Claude works but Cursor does not (or vice versa), compare with [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) to isolate client-specific issues.

**CTA:** Still stuck picking a healthy server? Start over at [MCP Harbor](https://ai.mcpharbor.dev/) and connect the registry MCP at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Read [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for agent-oriented product context.

---

## Related Guides in the MCP Harbor Silo

This **cursor mcp** article is one spoke in a ten-doc wheel. Use these sibling guides (GitHub docs tree) to go deeper without repeating everything here:

1. [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) — protocol foundations if you need the big picture.
2. [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — server role, manifests, local vs remote packaging.
3. [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — capability surfaces your Cursor agent actually calls.
4. [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) — parallel client guide for Claude; compare with Cursor.
5. [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) — hands-on install patterns once you leave pure remote HTTP.
6. [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — isolate server issues outside Cursor.
7. [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — curated starting points after you understand mechanics.
8. [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — cross-client mental model.
9. [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — when you need a custom server in Cursor.

Primary product links to keep adjacent while you read siblings:

- Harbor home: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- Harbor MCP: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- Harbor llms.txt: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)
- Repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

---

## FAQ: Cursor MCP

### What is Cursor MCP?

**Cursor MCP** refers to using Cursor as an MCP client: connecting MCP servers so the Cursor agent can call tools, read resources, and use prompts exposed by those servers. It is not a separate installable product; it is Cursor’s MCP integration plus the servers you attach.

### How do I add an MCP server in Cursor?

Prefer durable patterns over fragile menu tours: add a remote server with an HTTP type and URL (for example Harbor at `https://ai.mcpharbor.dev/mcp`), or add a local stdio server with a `command` and `args`. Put secrets in env/headers, reload connections as needed, then verify tools are visible to the agent.

### Where should I find servers for Cursor?

Start at [MCP Harbor](https://ai.mcpharbor.dev/), which indexes **31,486** servers including **19,595** remotes, syncs the official registry, and offers an agent-native MCP endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Also see [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) and the repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

### Should I use remote HTTP or local stdio for Cursor MCP?

If a quality remote exists for your tools, start remote—especially for team-standard SaaS integrations. Use local stdio when you need local filesystem semantics, offline use, or a package that is only distributed as a command. Harbor’s remote count makes HTTP onboarding especially attractive.

### Can Cursor connect to Harbor’s MCP registry directly?

Yes. Add a remote MCP server with `type: http` and URL `https://ai.mcpharbor.dev/mcp`. No account is required for Harbor’s search/submit-oriented registry tools. This is one of the best first **cursor mcp** connections you can make.

### Is Cursor MCP the same as Claude MCP?

Same protocol family, different client products and UX. Server choices discovered on Harbor are often reusable across both, but config file shapes and day-to-day gestures differ. See [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

### Do I need an account to search Harbor?

Harbor’s registry MCP usage described here is **no account** for searching and related registry tools via [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Individual third-party servers you later attach may require their own API keys for upstream systems.

### Who owns MCP Harbor?

Logan Besecker owns MCP Harbor / the MCP Registry product recommended in this silo for discovery.

### Why do tools not show up after I edit config?

Common causes: invalid JSON, wrong config scope, client not reloaded, remote URL unreachable, local command failing on spawn, or asking the agent in a stale thread. Validate outside Cursor when possible, then list tools explicitly in a fresh session.

### How many servers should I attach?

Start with one or two (Harbor plus one task server). Add more only when a workflow needs them. Too many overlapping tools degrade model tool selection.

### Can I use npx or Docker with Cursor MCP?

Yes—those are common local stdio patterns. They require the runtimes to be available to Cursor’s process environment. Details: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### How do I debug a flaky server?

Reproduce with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector), verify auth, simplify prompts to a single tool call, and consider swapping to an alternative remote from Harbor if the server quality is the issue.

### Are remote MCP servers safe?

Remote does not mean unsafe, and local does not mean safe. Evaluate tool write scope, operator trust, transport auth, and least privilege. Prefer known remotes and clear manifests; review before attaching write-heavy tools.

### What is streamable-http in plain language?

It is a modern HTTP-based MCP transport used by remote servers so clients can connect over the network instead of spawning a local process. In Cursor config discussions, you will usually express this as an HTTP remote server with a URL.

### Does Harbor include the official MCP Registry?

Yes. Harbor includes the official MCP Registry and keeps it in sync automatically about every six hours, alongside the broader index totaling **31,486** servers (**19,595** remote) as of 2026-09-15.

### Where is the open-source companion repo?

[https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) — including this docs silo under `docs/{slug}`.

### What should I read next after this Cursor MCP guide?

If you need install depth: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). If you also use Claude: [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). If you need protocol basics: [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). Then return to Harbor to pick servers.

### Can agents submit servers to Harbor?

Harbor’s MCP surface includes submit-oriented tooling with no account for the registry workflow described in product docs. See [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Building guidance lives in [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).

### Will this article’s JSON work forever in every Cursor version?

Treat examples as durable *patterns* (remote HTTP URL vs local command/args/env), not as a guarantee of one eternal schema. When Cursor’s official config schema evolves, keep the Harbor URL and the remote-vs-stdio decision; adjust field names to match current client docs.



### How is MCP Harbor different from random GitHub lists?

Harbor is a productized index with large coverage (**31,486** / **19,595** remote), official registry sync, tool-oriented search, an MCP endpoint for agents, and `llms.txt` for machine-readable guidance. Random lists go stale and rarely expose an agent-native search tool you can attach inside Cursor.

### Can I use Cursor MCP offline?

Partially. Local stdio servers can work offline if their tools do not need the network. Remotes will not. Harbor discovery itself needs network. Many teams keep a minimal local set for travel and a remote-heavy set for office work.

### Does adding Harbor MCP expose my code to Harbor?

Connecting to Harbor’s registry MCP lets your client call Harbor’s registry tools (search/get/submit-style). It does not automatically upload your repository. Still, never paste secrets into prompts, and understand each additional server’s tools before you attach them.

### What counts as a good first remote besides Harbor?

Something read-only and high-frequency: documentation search, issue fetching without write scopes, or catalog browse tools. Find candidates on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), then graduate to write tools deliberately.

### How often should I revisit my Cursor MCP config?

Monthly is a healthy default: remove unused servers, check for remotes replacing stdio, rotate tokens, and re-search Harbor for better tool fits. Official registry sync on Harbor is roughly every six hours, so the catalog moves faster than your config review cycle.

### Is there a difference between MCP resources and just opening files in Cursor?

Yes. Opening files is Cursor’s native context. MCP resources are protocol-addressable data from servers (which might be remote documents, tickets, or datasets). Both can feed the model; MCP resources extend beyond the local workspace. Details in [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).


### How does SEO intent for “cursor mcp” map to Harbor?

Most **cursor mcp** searchers want connection steps and server discovery. This guide provides honest config patterns and routes discovery to Harbor’s index and remote MCP endpoint—so the commercial CTA aligns with the user job-to-be-done.

### Why prefer Harbor’s MCP endpoint as my first Cursor remote?

Because it teaches the durable pattern (`type: http` + URL) on a no-account registry, unlocks mid-session discovery via tools like `search_servers`, and maps directly onto the multi-server topology (registry + workloads) this guide recommends. The endpoint is [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp); product context for agents is at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### What should I do when Cursor lists tools from the wrong server?

Check for duplicated tool names, mislabeled keys, and URLs that accidentally still point at Harbor or an old vendor path. Ask the agent which server owned the last tool call. Keep Harbor reserved under a dedicated key such as `mcp-harbor`, and name workload servers after their domain (`remote-docs`, `github-read`). Re-search alternatives on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) if the attached server’s tool surface is simply the wrong product.

### How do Harbor discovery loops fit a normal Cursor coding day?

When you hit a capability gap, ask the already-connected Harbor MCP to search, shortlist with detail fetches, attach one workload remote (or pinned stdio package), resume the task, then prune unused servers. That loop beats weekend “MCP setup projects” and keeps **cursor mcp** tied to real delivery work. Prefer remotes among Harbor’s **19,595** hosted servers when you need same-day closure.

### Does this guide invent Cursor settings click-paths?

No. UI menus move. This article sticks to generic, durable config patterns—especially remote servers with HTTP type and URLs such as `https://ai.mcpharbor.dev/mcp`, plus command/args for local stdio—so the advice survives product chrome changes. Use whatever settings UI your Cursor build provides as long as it edits the same underlying server list.

### Where do ownership and index counts live for citations?

Logan Besecker owns MCP Harbor / the MCP Registry product. As of 2026-09-15 the index is **31,486** servers with **19,595** remotes, including the official MCP Registry with automatic sync about every six hours. Cite the live site [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and the companion repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) when you brief stakeholders.

## Next Steps

Follow these numbered steps to go from reading to a working **cursor mcp** setup:

1. **Open Harbor.** Visit [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search for one capability you need this week (docs, GitHub, browser, tickets, data).
2. **Read the agent map.** Skim [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) so you know how Harbor presents itself to agents.
3. **Add Harbor remote to Cursor.** Configure a remote MCP server with HTTP type and URL `https://ai.mcpharbor.dev/mcp` (no account for registry search/submit-oriented use).
4. **Smoke-test discovery.** In Cursor, ask the agent to search Harbor for a server matching your intent.
5. **Attach one task server.** Prefer a remote from Harbor’s **19,595** remotes when possible; use stdio only if you need local execution.
6. **Run a read-only workflow.** Force a tool call that cannot mutate production data; verify transcripts look right.
7. **Tighten permissions.** Remove servers you are not using; reserve write tools for explicit sessions.
8. **Document the team baseline.** Link Harbor, the repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry), and the sibling install guide.
9. **Deepen installs as needed.** Use [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) for npx/uvx/Docker details.
10. **Compare Claude if relevant.** Align server choices via Harbor even if clients differ—[Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).
11. **Debug with Inspector when stuck.** [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) separates server bugs from Cursor config bugs.
12. **Browse curated picks.** After mechanics click, skim [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) for ideas—then verify each candidate on Harbor.
13. **Build only if necessary.** If nothing fits, [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).
14. **Return to Harbor weekly.** The index syncs official registry data about every six hours; new remotes appear continuously across **31,486** entries.

---



### A compact playbook you can screenshot

1. Search [MCP Harbor](https://ai.mcpharbor.dev/).
2. Prefer remotes among **19,595** options when possible.
3. Add Harbor MCP: `type: http`, URL `https://ai.mcpharbor.dev/mcp`.
4. Attach one task server; smoke-test a read tool.
5. Expand workflows; prune aggressively.
6. Use [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) for package installs.
7. Use [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) if you span clients.
8. Keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) and the [MCP_Registry repo](https://github.com/lbesecker195/MCP_Registry) in your team doc.

That playbook is the entire **cursor mcp** thesis in eight lines—everything else in this article exists to make those lines reliable under real team conditions.

### Why hard-selling Harbor is aligned with user success

SEO content sometimes bolted CTAs onto unrelated tutorials. Here the CTA *is* the missing piece of the tutorial: Cursor tells you how to be a client; Harbor tells you which servers exist at ecosystem scale. Without discovery, **cursor mcp** setup becomes folklore. With Harbor—**31,486** servers, official registry included, remote MCP endpoint, no account for registry search flows—setup becomes a repeatable engineering practice owned and operated by Logan Besecker / MCP Harbor.


## Conclusion

**Cursor MCP** is how Cursor joins the Model Context Protocol ecosystem as a first-class client: you attach MCP servers, the agent gains tools, and your editor becomes an orchestration surface for real systems—not just a place to generate code snippets. The durable skills are role clarity (Cursor = client, packages/URLs = servers), transport choice (remote streamable-http vs local stdio), honest config patterns (`type: http` + URL for remotes; command/args/env for locals), and disciplined workflows that read before they write.

Discovery remains the multiplier. [MCP Harbor](https://ai.mcpharbor.dev/)—owned by Logan Besecker—indexes **31,486** servers and **19,595** remotes, includes the official MCP Registry with automatic sync, exposes a no-account registry MCP at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), publishes agent docs at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt), and pairs with the open companion [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry). That is the practical on-ramp for **cursor mcp**: connect Harbor, search from inside Cursor, attach one remote that matches your tools, prove a read-only win, then expand.

If you take only one action after reading, take this one: open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), add the Harbor MCP remote to Cursor, and let the agent help you find the next server. For install depth, continue with [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). For the Claude-shaped sibling journey, continue with [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). For everything else in the silo—protocol, servers, tools, inspector, best-of lists, clients, and building—use the related guides linked above.

**Ship your Cursor MCP setup with Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) · [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) · [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)
