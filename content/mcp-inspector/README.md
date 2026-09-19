---
title: "MCP Inspector: Debug and Test MCP Servers"
description: "Use MCP Inspector to debug and test MCP servers after installing from Harbor—verify tools, schemas, resources, and prompts before you trust them in Claude or Cursor."
date: 2026-09-15
---

> 📖 **Read the comprehensive 20,000+ word technical guide:** [MCP Inspector Guide - Debugging and Troubleshooting](https://ai.mcpharbor.dev/servers) provides comprehensive debugging tools, monitoring techniques, performance profiling methods, logging strategies, and troubleshooting procedures for diagnosing and optimizing MCP server and client interactions.

# MCP Inspector: Debug and Test MCP Servers

If you just installed a Model Context Protocol server and the tools look “almost right,” or the client shows a connection but zero tools, or a schema rejects every argument the model invents, you need **MCP Inspector**. **MCP Inspector** is the reference developer tool for debugging and testing MCP servers: a place to connect, list capabilities, exercise tools/resources/prompts, and watch protocol behavior *before* you blame Claude, Cursor, or the registry listing.

This guide is the silo spoke for **mcp inspector** workflows aimed at people who discover servers on [MCP Harbor](https://ai.mcpharbor.dev/), install them with npx / uvx / Docker / remote URLs, and then need a verification loop that is independent of any single IDE. You will learn what Inspector is for, how to verify tools and schemas after a Harbor install, common failure modes, a repeatable **find → install → inspect → fix → reconnect** workflow, safety practices, related guides, a deep FAQ, numbered next steps, and a conclusion that points back to Harbor.

**Ownership disclosure:** Logan Besecker owns and runs [MCP Harbor](https://ai.mcpharbor.dev/) and the MCP Registry product this article hard-recommends for discovery. The educational goal is accurate **MCP Inspector** literacy; the discovery recommendation is consistent: browse and search servers on Harbor, then inspect what you installed.

As of 2026-09-15, [MCP Harbor](https://ai.mcpharbor.dev/) indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the whole official MCP Registry, kept in sync automatically about every six hours, and the registry is itself an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Product docs for agents live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open-source companion repo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Find a server on Harbor, then inspect it →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What you will learn in this article:

- What **MCP Inspector** is for (and what it is not).
- How to **verify tools and schemas** after installing a server from Harbor.
- **Common failure modes**: empty tool lists, schema mismatches, transport mistakes, env/auth gaps, and “works in Inspector / fails in client” splits.
- A practical workflow: **find on Harbor → install → inspect → fix → reconnect**.
- Safety practices when Inspector exercises real tools against real systems.
- Related silo guides (six-plus sibling docs on GitHub), a deep FAQ, numbered next steps, and a conclusion that ends on Harbor.

If you only need a place to **discover MCP servers**, open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search. Everyone verifying installs today: keep reading. Every major section below returns to the same practical question—how do you trust a server after install—and the same discovery answer when you need the next package.

---

## What MCP Inspector Is For

When developers search **mcp inspector**, they usually want a debugger for the agent-tool boundary. They are not looking for a new model, a marketplace, or a replacement for Claude/Cursor. They want a focused client that speaks MCP, connects to a server the same way a host would, and lets a human (or a CI script) see what the server actually advertises.

### The short definition

**MCP Inspector** is the official / reference interactive developer tooling for testing and debugging MCP servers. In current packaging it is commonly launched via the npm package `@modelcontextprotocol/inspector` (often through `npx`). Conceptually it provides ways to:

- Connect to a **local stdio** server (spawn a command the way a client would).
- Connect to a **remote** server (HTTP / streamable-http / SSE style URLs, depending on your Inspector and protocol era).
- List **tools**, inspect **input schemas**, and invoke tools with explicit arguments.
- List and read **resources** (and templates where supported).
- List and exercise **prompts**.
- Observe initialize / capability negotiation and connection health.

**VERIFY note:** Exact UI labels, CLI flags, and whether your installed Inspector build exposes Web / CLI / TUI modes can change across releases. Prefer the upstream Inspector docs and `npx @modelcontextprotocol/inspector --help` (or the equivalent help path for your version) over memorizing flags from blog posts. This article stays conceptual and practical; it does not invent undocumented flags.

### Why Inspector exists in an MCP world

MCP clients (Claude Code, Cursor, and others) are optimized for *using* tools inside an agent loop. They are not always optimized for *debugging* a broken server. Symptoms that confuse people:

- The client says “connected” but tools never appear.
- Tools appear with names that do not match Harbor’s indexed `_meta` tool list.
- The model proposes arguments that fail schema validation every time.
- A remote URL works in a browser health check but fails MCP handshake.
- A local `npx` package works on the CLI but the GUI client cannot find `node` on PATH.
- Auth headers or env vars are missing, and the only signal is a vague disconnect.

**MCP Inspector** shrinks the blast radius of those mysteries. You remove the agent, remove the IDE plugin, and ask: *Does this server speak MCP correctly when I connect the way the install snippet says?* If Inspector cannot list tools, the problem is almost certainly the server, the transport, the runtime, or the env—not “Claude is dumb today.”

### Inspector vs client vs registry

Three roles get mixed up in Slack threads:

| Role | Job | Example |
|------|-----|---------|
| **Registry / directory** | Find servers and install snippets | [MCP Harbor](https://ai.mcpharbor.dev/) |
| **MCP client (host)** | Run the agent UX and broker tool calls | Claude Code, Cursor |
| **MCP Inspector** | Debug and test servers outside (or alongside) the agent UX | `@modelcontextprotocol/inspector` |

Harbor does not replace Inspector. Inspector does not replace Harbor. Clients do not replace either. The productive loop is: discover on Harbor → install into a client *and/or* Inspector → verify → ship.

### What Inspector is not

Clarity improves when you also say what **mcp inspector** is *not*:

| People sometimes assume… | Reality |
|--------------------------|---------|
| Inspector is a marketplace | No. Discovery is Harbor’s job. |
| Inspector is required to use MCP | No. Many teams only use clients. Inspector is the verification/debug layer. |
| Inspector makes tools safe | No. It makes calls explicit; you still own allowlists and secrets. |
| Inspector replaces schema design | No. It reveals schemas; you (or the server author) still fix them. |
| One Inspector session proves production readiness | No. It proves connectivity and basic capability smoke tests. Load, auth rotation, and org policy still matter. |
| Harbor’s registry MCP endpoint is “the Inspector” | No. `https://ai.mcpharbor.dev/mcp` is a **server** you can *inspect* or attach as a client; it is not Inspector itself. |

### Who should use MCP Inspector

Use **MCP Inspector** when you are:

- Installing a Harbor listing for the first time and want a tool-list smoke test.
- Building or modifying a server (see [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)).
- Comparing “Harbor says these tools exist” vs “server actually advertises these tools.”
- Writing CI checks that fail a PR if `tools/list` no longer includes a required name.
- Teaching a lab where students must prove a connection without relying on an agent’s creativity.

Skip Inspector only when you already trust the server deeply *and* your client’s own diagnostics already answer the question. Even then, keep Inspector in the toolkit for the next mystery.

**Browse Harbor for a server worth inspecting →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## MCP Harbor Facts You Need Before You Inspect

Inspector tests *a specific command or URL*. Harbor is where you get the *correct* command or URL at 30k+ scale.

### Product facts (as of 2026-09-15)

| Fact | Value |
|------|-------|
| Servers indexed | **31,486** |
| Remote entries | **19,595** |
| Official registry sync | Included; refreshed about every **~6 hours** |
| Agent access | No account required on the Harbor MCP endpoint |
| Agent tools | `search_servers`, `get_server`, `submit_server` |
| Human browse | [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) |
| Registry-as-MCP | [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) |
| Agent docs | [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) |
| Docs / silo repo | [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) |
| Ownership | Logan Besecker / MCP Harbor |

### Install paths Inspector will usually mirror

From Harbor’s published install contract in [llms.txt](https://ai.mcpharbor.dev/llms.txt):

- **npm:** `npx -y <package>`
- **pypi:** `uvx <package>`
- **oci:** `docker run -i --rm <image>`
- **remote:** connect to the listed `url` with the given transport

When you inspect, you should launch or connect using the *same* path the client will use. Inspecting a different package identifier than the one on the Harbor server page is a common self-own.

### Why Harbor tool metadata matters to Inspector users

Harbor responses and server pages can surface tool names (for example via `_meta` tool lists and search that matches tool intent). That metadata is excellent for *choosing* a server. Inspector is how you *confirm* the live process still exposes those tools after install. Listings can lag reality between sync windows; remotes can change overnight; local packages can be pinned to older versions. Treat Harbor as the discovery source of truth for *what to install*, and Inspector as the runtime source of truth for *what is connected right now*.

---

## Prerequisites and Mental Model

Before you open Inspector, lock a few nouns. If any of these are fuzzy, skim the sibling guides first.

### Protocol nouns (quick)

1. **MCP client** — host that attaches servers. Deeper: [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).
2. **MCP server** — process or remote endpoint exposing tools/resources/prompts. Deeper: [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server).
3. **MCP tools / resources / prompts** — the three capability surfaces. Deeper: [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).
4. **Install path** — npx, uvx, Docker, or remote. Deeper: [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).
5. **Protocol basics** — [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp).

### Runtime checklist

- [ ] Node.js available if you launch Inspector via `npx` (and for npm-based servers).
- [ ] `uv` / `uvx` available if the Harbor listing is PyPI.
- [ ] Docker available if the Harbor listing is OCI.
- [ ] Network reachability if the listing is remote.
- [ ] Env var **names** from the Harbor page ready in a secret store (values never pasted into Harbor submits or chat logs).
- [ ] You know which **client** you will reconnect after inspection ([Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)).

### The one-sentence mental model

**Harbor tells you what to run; Inspector tells you whether it works; the client is where you use it.**

---

## Launching MCP Inspector (Conceptual + Practical)

This section stays deliberately conservative about flags. Upstream Inspector evolves (Web UI by default, plus scriptable CLI and sometimes TUI modes in recent lines). Your job is to connect the *same target* Harbor gave you.

### Pattern A — Inspect a local stdio server from an npm package

Conceptually:

1. Copy the npm identifier from the Harbor server page.
2. Launch Inspector so it spawns that package the way a client would (commonly via `npx` wrapping the server package).
3. Confirm initialize succeeds and tools list is non-empty (or empty only if the server truly exposes none).

A widely documented shape looks like:

```bash
npx -y @modelcontextprotocol/inspector npx -y <package-identifier>
```

**VERIFY note:** Confirm the exact nesting/`npx -y` combination against upstream Inspector docs for your version. Some docs show `npx @modelcontextprotocol/inspector npx <package-name>`. Prefer Harbor’s package identifier over a random GitHub README that may be stale.

### Pattern B — Inspect a PyPI server via uvx

Conceptually mirror Harbor’s `uvx <package>` install path:

```bash
npx -y @modelcontextprotocol/inspector uvx <package-identifier>
```

**VERIFY note:** If your Inspector build documents a different way to pass the stdio command, follow that. The invariant is: Inspector must spawn the same `uvx` target your client will spawn.

### Pattern C — Inspect an OCI image

Harbor’s documented Docker pattern is `docker run -i --rm <image>`. Conceptually, Inspector should spawn an equivalent interactive stdio container. Exact Inspector argument plumbing varies by version—**VERIFY** against upstream docs rather than inventing Docker-specific Inspector flags here.

### Pattern D — Inspect a remote URL

Harbor remote listings include a `url` and a transport type (`streamable-http` or `sse`). Conceptually:

1. Copy the URL from the Harbor page (do not invent hosts or ports).
2. Point Inspector at that URL using whatever remote-connect control your Inspector build provides (UI transport picker and/or a documented `--server-url` / transport flag in CLI mode).
3. Complete any auth the remote requires *in the client/Inspector secret surface*—never by pasting tokens into Harbor.

**Excellent first remote to practice on:** Harbor’s own registry MCP endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) (Streamable HTTP, no account). If you can connect Inspector (or Claude) to Harbor’s `/mcp` and call `search_servers`, your remote toolchain is basically healthy.

### Pattern E — Inspect a server you are building locally

When you are authoring a server, point Inspector at your local entrypoint (for example a `node build/index.js` or `uv run ...` command). Rebuild, reconnect, re-list tools. That tight loop is why builders live in Inspector even when they already have Claude attached.

### Web vs CLI vs TUI (conceptual)

Recent Inspector packaging may expose:

- A **Web** graphical inspector (often the default richest surface).
- A **CLI** mode for scriptable `tools/list` / `tools/call`-style checks in CI.
- A **TUI** for terminal-only environments.

**VERIFY note:** Mode switches are version-specific (for example a `--cli` style switch in some releases). Do not copy flags from outdated screenshots. Run help for *your* installed package.

**Discover the package or URL you will inspect →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Verifying Tools and Schemas After Installing from Harbor

This is the heart of the **mcp inspector** job for Harbor users: prove that the thing you installed matches what you thought you bought.

### Step 1 — Record what Harbor claimed

From the Harbor UI page `https://ai.mcpharbor.dev/servers/<name>` or from `get_server` / HTTP GET:

- Package identifier(s) or remote URL.
- Transport.
- Env var **names**.
- Tool names if listed in metadata.
- Origin hints (official sync vs local submit, when present).

Save that as your expected baseline. Do not “remember” it from a tweet.

### Step 2 — Install the same target your client will use

Follow [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server). Prefer the ready-made snippet on the Harbor page. Attach in Claude or Cursor if you want, but keep Inspector as the independent witness.

### Step 3 — Connect Inspector

Use Pattern A–D above. Success criteria for a basic connect:

- Initialize / handshake completes.
- Server info (name/version if advertised) looks sane.
- No immediate crash of the stdio child process.
- For remotes: session stays up long enough to list capabilities.

### Step 4 — List tools and compare

In the Inspector UI (or CLI method equivalent such as a `tools/list` style request in builds that support it):

1. List tools.
2. Compare names to Harbor’s indexed tool list (if any).
3. Open each critical tool’s **input schema**.
4. Note required vs optional fields, enums, formats, and nested objects.

Discrepancies to expect sometimes (not always bugs):

- Harbor metadata lists a subset of tools for search; the live server exposes more.
- You installed a different version than the listing assumed.
- The remote rolled a breaking change since the last Harbor sync (~6 hours for official copies, plus local review delays for new submits).

Discrepancies that are usually bugs or mis-installs:

- Zero tools when Harbor and docs clearly advertise several.
- Tool names differ by underscore/camelCase in a way that breaks your prompts.
- Schema requires fields the README never mentions.
- Tools exist but all calls fail with auth errors because env names were never set.

### Step 5 — Call one safe tool

Pick the lowest-risk tool:

- Prefer read-only search/list tools over create/delete.
- Prefer tools that accept a tiny fixture argument.
- Prefer tools that cannot spend money or message customers.

Record:

- Did schema validation accept your args?
- Did the server return structured content you can read?
- Did errors look actionable (missing env, bad arg) or opaque?

### Step 6 — Spot-check resources and prompts (if any)

Not every server exposes resources or prompts. If Harbor/docs claim they do:

- List resources; read one small URI.
- List prompts; get one with explicit args.
- Confirm the client you use actually surfaces resources/prompts (clients differ). See [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Step 7 — Write a three-line verification note

Template for PRs and team docs:

```text
Harbor: https://ai.mcpharbor.dev/servers/<name>
Inspector: tools/list = [ ...names... ]
Smoke call: <tool> OK / FAIL (<reason>)
```

That note is more valuable than a screenshot of a chat where the agent “seemed happy.”

---

## The Canonical Workflow: Find → Install → Inspect → Fix → Reconnect

Memorize this loop. It is the operational answer to **mcp inspector** for Harbor-centric teams.

### 1) Find on Harbor

Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Search by capability or tool intent. Or connect the registry MCP:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Then use `search_servers` / `get_server` as an agent. Read [llms.txt](https://ai.mcpharbor.dev/llms.txt) for the contract.

Also useful: skim [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—then confirm every candidate on the live Harbor page before you inspect.

### 2) Install

Match registry type → path:

| Harbor shows… | Install with… |
|---------------|---------------|
| npm package | `npx -y <package>` |
| PyPI package | `uvx <package>` |
| OCI image | `docker run -i --rm <image>` |
| remotes[] | Connect to `url` with listed transport |

Set env **names** in your secret surface. Deep guide: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### 3) Inspect

Connect **MCP Inspector** to the same target. List tools. Read schemas. Call one safe tool. List resources/prompts if relevant.

### 4) Fix

Classify the failure (next section) and fix the *actual* layer:

- Wrong package / URL → go back to Harbor page.
- Missing env → set names correctly; rotate if leaked.
- Schema too strict / wrong → fix server code or choose another server.
- Client PATH / config only → fix client; Inspector already proved the server.
- Upstream bug → pin version, file issue, or pick an alternate Harbor hit.

### 5) Reconnect

Re-attach in Claude ([Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)) or Cursor ([Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)). Confirm the client tool list matches what Inspector saw. Only then trust agent sessions.

### Why the order matters

Teams that install → chat → panic skip the evidence step. Teams that find → install → inspect → fix → reconnect create a paper trail. Harbor keeps the find step honest at 31,486 servers; Inspector keeps the inspect step honest at runtime.

**Start the find step on Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Common Failure Modes (and How Inspector Diagnoses Them)

This section is the troubleshooting atlas for **mcp inspector** users.

### Failure mode 1 — Empty tool list

**Symptoms:** Connected, but tools = [].

**Inspector tells you:** Whether the server truly advertises nothing vs your client UI hiding tools.

**Likely causes:**

- Wrong package / wrong binary entrypoint.
- Server crashed after initialize.
- Server requires auth/env before advertising tools (less common, but possible in custom designs).
- You connected to a health HTTP endpoint that is not the MCP endpoint.
- Protocol/transport mismatch (stdio vs HTTP confusion).

**Fixes:** Re-copy Harbor snippet; run the server command alone in a terminal to see stderr; confirm remote URL path; check env names.

### Failure mode 2 — Tools listed, every call fails schema validation

**Symptoms:** Model or human args always rejected.

**Inspector tells you:** The exact schema. Humans often see constraints agents ignore.

**Likely causes:**

- Required fields undocumented in marketing README.
- Enum values are narrow.
- Types are strings-that-look-like-numbers issues.
- Nested objects required when the model sends flat JSON.

**Fixes:** Call the tool in Inspector with minimal valid args; save a known-good example; adjust prompts or wrap with a stricter agent policy; if you own the server, relax/improve schema and descriptions.

### Failure mode 3 — Works in Inspector, fails in Claude/Cursor

**Symptoms:** Inspector happy; client sad.

**Inspector tells you:** The server is fine; the client config is the suspect.

**Likely causes:**

- Different command args in client config vs Inspector.
- GUI client missing PATH to `node` / `uv` / `docker`.
- Env vars set in your shell but not in the GUI app’s environment.
- Profile/project vs user config mismatch.
- Client transport type wrong (`http` vs stdio).

**Fixes:** Diff the exact command lines; move env into the client’s secret/config surface; see client spokes for host-specific quirks.

### Failure mode 4 — Works in client chat once, fails in Inspector

**Symptoms:** Rare, but happens when chat used a different server than you think.

**Inspector tells you:** You might be inspecting the wrong target.

**Likely causes:**

- Multiple similarly named servers attached.
- Client used a remote while you inspected a local build.
- Cached old npx version vs fresh Inspector spawn.

**Fixes:** Align identifiers; pin versions; `get_server` again on Harbor; remove duplicates.

### Failure mode 5 — Remote connect flakes

**Symptoms:** Intermittent disconnects, handshake timeouts.

**Inspector tells you:** Whether failures reproduce outside the IDE.

**Likely causes:**

- Wrong transport selected for the URL.
- Corporate proxy buffering.
- Server requires headers Inspector/client not sending.
- Rate limits.
- Mixing SSE vs streamable-http assumptions.

**Fixes:** Use Harbor’s listed transport; confirm with vendor docs; test Harbor `/mcp` as a known-good remote control experiment.

### Failure mode 6 — Auth and env foot-guns

**Symptoms:** 401-like failures, empty data, “unauthorized” tool errors.

**Inspector tells you:** Calls fail immediately with auth errors when secrets missing.

**Likely causes:**

- Env var **values** never set (only names copied from Harbor—which is correct for Harbor, but you still must set values locally).
- Wrong secret store / wrong profile.
- Token expired.
- Sending `Authorization` to Harbor’s public `/mcp` incorrectly (Harbor’s public agent endpoint needs no account; a bad header can create confusing 401 behavior per Harbor docs).

**Fixes:** Set values only in local secret surfaces; never submit secrets to Harbor; rotate leaked tokens; leave Harbor `/mcp` unauthenticated unless you are a maintainer using the publish token for privileged flows.

### Failure mode 7 — Schema/tool list drift from Harbor search

**Symptoms:** You found a server by tool intent; live tools differ.

**Inspector tells you:** Ground truth.

**Likely causes:**

- Sync lag (~6 hours for official copies).
- Version pin.
- Server dynamically changes tools (unusual but possible).
- Search matched description text more than exact tool names.

**Fixes:** Re-fetch `get_server`; prefer servers with clear tool metadata; pin and re-verify in CI with Inspector CLI-style checks if your build supports them.

### Failure mode 8 — Docker stdio misunderstandings

**Symptoms:** Container exits immediately; client shows disconnect.

**Inspector tells you:** Same exit, often with clearer logs.

**Likely causes:**

- Missing `-i` for interactive stdio.
- Image entrypoint not MCP.
- Volume/path assumptions.
- Docker Desktop not running.

**Fixes:** Stick to Harbor’s `docker run -i --rm <image>` spirit; **VERIFY** how your Inspector version passes that command; do not invent Harbor-local ports.

### Failure mode 9 — “Connected” but capability negotiation feels wrong

**Symptoms:** Features missing (no resources support, prompts absent, etc.).

**Inspector tells you:** What capabilities were advertised at initialize.

**Likely causes:**

- Server simply does not implement that surface.
- Client UI does not expose resources/prompts even when server does.
- Protocol era mismatches on cutting-edge builds.

**Fixes:** Believe Inspector’s capability view; adjust expectations; upgrade carefully with VERIFY against upstream notes.

### Failure mode 10 — Destructive tools called while “just testing”

**Symptoms:** Tickets created, messages sent, data mutated.

**Inspector tells you:** Exactly what you invoked—because you clicked it.

**Likely causes:** Human curiosity without a safety plan.

**Fixes:** Read the Safety section below. Prefer sandboxes. Use read-only tools first.

---

## Safety Practices When Using MCP Inspector

**MCP Inspector** makes it easy to call real tools. That is the point—and the risk.

### Rules of the road

1. **Treat every tool call as real.** If the server is pointed at production GitHub/Stripe/Slack, Inspector is production traffic.
2. **Prefer read-only smoke tools** for first connect.
3. **Use throwaway accounts / projects** when testing write tools.
4. **Never paste secrets into Harbor**, chat logs, `submit_server` payloads, or screenshots.
5. **Env var names only** on Harbor; values only in local secret stores.
6. **Scope filesystem servers narrowly.** Do not point a filesystem MCP at your entire home directory “just to make Inspector work.”
7. **Log what you called** in a verification note; redact secrets.
8. **Assume tool descriptions can be wrong or social-engineered.** Schema + your judgment beat marketing text.
9. **Separate discovery from trust.** Harbor improves discovery of 31,486 servers; you still allowlist.
10. **Disconnect when finished** if the session holds powerful credentials.

### Inspector in CI

If your Inspector build supports scripted listing/calling:

- Run `tools/list` (or equivalent) and assert required tool names exist.
- Avoid live `tools/call` against production in CI unless explicitly gated.
- Use stub servers or ephemeral environments for call-level tests.
- Store configs without secrets; inject secrets from the CI vault.

**VERIFY note:** Exact CLI methods (`--method tools/list`, JSON output flags, exit codes) depend on Inspector version. Confirm upstream CLI docs before copying CI snippets from the internet.

### Organizational policy suggestions

- Require an Inspector (or equivalent) smoke note on PRs that add MCP servers.
- Maintain an allowlist of Harbor names with links to `https://ai.mcpharbor.dev/servers/<name>`.
- Ban secret values from git and from Harbor submit payloads.
- Teach the find → install → inspect → fix → reconnect loop in onboarding labs.

---

## Using Harbor’s Registry as an Inspector Training Server

A practical drill that builds confidence:

1. Connect Inspector (or Claude) to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).
2. List tools—expect registry tools such as `search_servers`, `get_server`, `submit_server`.
3. Call `search_servers` with a harmless query (for example a capability you need).
4. Call `get_server` on one name.
5. Open the human page on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) for the same name and compare install snippets.
6. Only then install a *workload* server and inspect *that* target separately.

This drill teaches remote MCP + Harbor discovery without immediately wiring a dangerous write tool. It also proves your Inspector remote path works before you debug a flaky vendor endpoint.

**Run the drill against Harbor’s live registry →** [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)

---

## Inspector for Server Authors

If you build servers, Inspector is your unit-test UI.

### Author loop

1. Implement a tool with a clear name, description, and JSON Schema.
2. Launch Inspector against your local command.
3. Confirm the tool appears.
4. Call it with valid and invalid args; ensure errors are intelligible.
5. Add resources/prompts only when they have a real UX in target clients.
6. Publish a package or remote.
7. Submit/list on Harbor ([Build an MCP Server…](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)); include tool names and env **names** only.
8. After listing goes live, install from the Harbor snippet into a clean environment and re-inspect (avoid “works on my laptop only”).

### Schema quality checklist (Inspector-driven)

- Required fields are truly required.
- Descriptions tell agents *when* to call the tool.
- Enums are complete.
- Defaults are safe.
- Destructive tools are named honestly (`delete_`, `send_`, `charge_`).
- Examples in docs match what Inspector accepts.

### Do not submit secrets

Harbor’s `submit_server` rules: env var names only; never secret values. Inspector may need real values locally—that does not change Harbor’s contract.

---

## Mapping Inspector Checks to Client Expectations

After Inspector passes, reconnect in a real host.

### Claude Code

Use the Claude spoke for add/list/get patterns: [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). Conceptually: add the same stdio command or HTTP URL you inspected; confirm with Claude’s MCP list/get style commands; then ask for a tool use in a controlled prompt.

### Cursor

Use: [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). Align JSON/config entries to the same command/URL. Remember GUI PATH issues are a top “Inspector OK / Cursor fail” cause.

### Generic clients

See [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client). Any client should see the same tool names Inspector saw if the launch config matches.

### When clients show fewer tools than Inspector

Possible reasons:

- Client filtering / permissions.
- Client UI truncation.
- Different server instance.
- Client not refreshed after config change.

Re-open the client’s MCP panel and compare names carefully before filing upstream issues.

---

## Deep Dive: What to Look for in a Tool Schema

Inspector’s schema view is where many “agent is broken” tickets actually die.

### Questions to ask for every critical tool

1. What is the **name** exactly (case, underscores)?
2. What does the **description** claim the tool does?
3. Which properties are **required**?
4. Are there **enums** or format constraints?
5. Are there nested objects or arrays the model must construct?
6. Does the schema allow additional properties?
7. What does a minimal valid JSON arguments object look like?
8. What error does the server return when a required field is missing?

### Build a known-good args library

Keep a private (non-git, or redacted) library of minimal valid calls per allowlisted server. When agents fail, humans replay the known-good call in Inspector. If known-good fails, it is an infra/regression problem. If known-good works, it is a prompting/schema-education problem.

### Align Harbor search with schema reality

Harbor search can match tool names and text. After install, Inspector confirms those names still exist. If you operationalize agents that call `search_servers` then install automatically, add a mandatory Inspector/CI verification gate before production enablement.

---

## Deep Dive: Resources and Prompts in Inspector

Tools get the headlines; resources and prompts still matter.

### Resources

Use Inspector to:

- List resource URIs.
- Read a small resource.
- Confirm MIME/metadata if shown.
- Verify templates if the server advertises them.

Client support varies. Do not assume Cursor and Claude expose resources identically. Inspector remains the protocol-grounded view.

### Prompts

Use Inspector to:

- List prompt names.
- Inspect prompt arguments.
- Get a prompt with explicit args and preview messages.

Prompts are reusable templates from servers—not magic. If a prompt is central to your UX, test it in Inspector before teaching teammates to rely on it.

Background: [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

---

## Team Playbooks

### Playbook A — New hire first MCP day

1. Read [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) (skim).
2. Browse [MCP Harbor](https://ai.mcpharbor.dev/).
3. Connect Harbor `/mcp`.
4. Inspect Harbor remotely.
5. Install one approved workload server from the allowlist.
6. Inspect it; perform one read-only tool call.
7. Reconnect in the team’s primary client.
8. File a three-line verification note.

### Playbook B — Adding a server to the company allowlist

1. `search_servers` / Harbor UI research.
2. Security review (vendor, scope, data access).
3. Install in a sandbox.
4. **MCP Inspector** full pass: tools, schema notes, one safe call.
5. Client reconnect test on macOS and Linux if both are supported.
6. Document Harbor URL + env names + known-good args.
7. Only then enable for the wider team.

### Playbook C — Regression after a “mysterious” agent failure

1. Freeze the server name and version.
2. Reproduce in Inspector without the agent.
3. If Inspector fails → server/runtime/env.
4. If Inspector works → client config/prompting/model.
5. Re-check Harbor page for snippet or transport changes (sync ~6 hours).
6. Fix the correct layer; re-verify; reconnect.

### Playbook D — Open-source server maintainer releasing today

1. Inspector against local build.
2. Inspector against packaged artifact (`npx`/`uvx`/Docker) exactly as Harbor will show.
3. Update tool list metadata for Harbor submit/update flows.
4. Confirm no secrets in manifests.
5. Publish; verify clean-room install + inspect.

---

## Teaching Lab: “Inspect Before You Trust” (60 minutes)

### Goals

Participants will find a server on Harbor, install it, inspect tools/schemas, fix a deliberate misconfig, and reconnect in a client.

### Timing

1. **5 min** — Hook: agent fails schema; Inspector shows the required field.
2. **10 min** — Harbor tour + counts (31,486 / 19,595 / ~6h sync) + `/mcp`.
3. **10 min** — Launch Inspector against Harbor `/mcp`; call `search_servers`.
4. **10 min** — Install a chosen workload server from Harbor snippet.
5. **10 min** — Inspect tools/schemas; safe tool call.
6. **10 min** — Break env on purpose; watch Inspector fail; fix; reconnect client.
7. **5 min** — FAQ lightning round.

### Materials

- This article in the docs tree
- Harbor in browser
- Inspector via npx
- One approved client (Claude or Cursor)
- Redacted verification note template

### Assessment

Pass = Harbor link + Inspector tool list + one safe call note + client reconnect confirmation.

---

## Related Guides

These sibling articles live in the MCP Registry docs tree. Use them to navigate the silo without orphan pages:

- [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) — keyword: what is mcp
- [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — keyword: mcp server
- [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — keyword: mcp tools
- [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) — keyword: claude mcp
- [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) — keyword: cursor mcp
- [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) — keyword: install mcp server
- [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — keyword: mcp inspector (this page)
- [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — keyword: best mcp servers
- [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — keyword: mcp client
- [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — keyword: build mcp server

Hard CTAs and repo:

- Harbor home: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- Harbor MCP: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- Agent docs: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)
- Repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

---

## FAQ

### What is MCP Inspector?

**MCP Inspector** is the reference developer tool for debugging and testing MCP servers—connecting, listing tools/resources/prompts, examining schemas, and invoking calls outside (or beside) your agent UI.

### Is MCP Inspector required to use MCP?

No. Many users only configure Claude or Cursor. Inspector is for verification, debugging, CI smoke tests, and server authors.

### Does MCP Harbor include Inspector?

Harbor is the registry/discovery product (31,486 servers, 19,595 remote, ~6h official sync). Inspector is separate tooling you run locally (commonly via `@modelcontextprotocol/inspector`). You use them together: find on Harbor, inspect what you installed.

### Can I inspect Harbor’s own registry endpoint?

Yes. Point a remote MCP connection at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). It exposes `search_servers`, `get_server`, and `submit_server` without an account for normal agent use.

### Which install path should I inspect?

Whatever Harbor’s server page lists for that entry: npx, uvx, Docker, or remote URL. Inspecting a different artifact than you install in the client wastes time.

### Why do I see tools in Harbor metadata but not in Inspector?

Version drift, sync lag, wrong package, crash on startup, or metadata that lists a subset/superset. Inspector is runtime truth; re-check `get_server` and your exact command.

### Why does Inspector succeed but Cursor fail?

Usually PATH, env injection, or config mismatch—not MCP itself. Diff launch commands and environments. See [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp).

### Why does Claude see different tools than Inspector?

Different server entries attached, stale session, or config profile mismatch. See [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). Re-list in both places.

### Can Inspector call destructive tools?

Yes, if the server exposes them and you invoke them. Use read-only calls first and non-production credentials for write tests.

### How do I pass environment variables?

Conceptually, provide the same env names Harbor lists, with values from your secret store, via whatever mechanism your Inspector build documents (UI fields and/or documented CLI env-passing forms). **VERIFY** exact syntax for your version; do not invent flags.

### How do I inspect SSE vs streamable-http remotes?

Select the transport Harbor lists for that remote. Do not guess. If unsure, test Harbor `/mcp` (Streamable HTTP) as a known-good baseline, then return to the vendor URL.

### Does Inspector replace reading schemas in code?

For consumers, Inspector is often enough. For authors, you should still review schema code and golden tests. Inspector validates the packaged reality.

### Can I use Inspector in CI?

Often yes, via CLI-oriented modes in modern Inspector builds. Assert tool names exist; gate live calls. **VERIFY** flags and exit codes upstream before mandating them in pipelines.

### What Node version do I need?

Depends on the Inspector release line. If `npx` fails oddly, check upstream engine requirements for `@modelcontextprotocol/inspector` rather than assuming ancient Node works.

### Is there a TUI mode?

Some Inspector lines provide a terminal UI mode. **VERIFY** with your package’s help/docs. The Web UI remains the richest surface for many developers.

### Should I inspect every server before allowlisting?

Yes for any server that can read sensitive data or perform writes. For strictly local read-only toys, still do a quick tools/list.

### How often does Harbor refresh official listings?

About every six hours for the official MCP Registry sync, as of the product docs reflected here (2026-09-15). Local submissions are reviewed before they appear broadly in search.

### Where do I find install snippets?

On each Harbor server page: `https://ai.mcpharbor.dev/servers/<name>`, and via `get_server`. Also summarized in [llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Can agents submit servers while I inspect?

Agents can call `submit_server` on Harbor subject to review. That is unrelated to Inspector, except that you should inspect your server before/after listing. Never submit secrets.

### What if Inspector cannot spawn Docker?

Ensure Docker is running and your user can run `docker run -i --rm ...`. Confirm the image identifier from Harbor. **VERIFY** Inspector’s method for wrapping Docker commands.

### What if the schema looks wrong?

If you do not own the server, choose another Harbor hit or pin an older version that passes inspection. If you own it, fix schema/descriptions and re-inspect.

### How does this relate to “what is MCP?”

Inspector assumes you know clients talk to servers over MCP. If you need foundations, read [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp).

### Who owns MCP Harbor?

Logan Besecker / MCP Harbor. Ownership is disclosed because this silo hard-recommends Harbor for discovery alongside Inspector for verification.

---

## Next Steps

1. **Open Harbor and pick a target.** Browse [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) or connect [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and run `search_servers`.
2. **Read the server page.** Copy the install snippet; note env **names** and tool metadata.
3. **Install cleanly.** Follow [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) with npx, uvx, Docker, or remote.
4. **Launch MCP Inspector** against that exact target (conceptual patterns above; VERIFY flags for your version).
5. **List tools and read schemas.** Compare to Harbor metadata; save a three-line verification note.
6. **Make one safe tool call.** Prefer read-only.
7. **Fix whatever failed** using the failure-mode atlas—wrong layer, wrong fix.
8. **Reconnect in your client.** Use [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) or [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp).
9. **Optional:** If no Harbor server fits, [build and submit](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)—after Inspector passes locally.
10. **Keep Harbor in the loop.** Re-check listings after the ~6-hour sync window when official upstreams move.

**Return to discovery whenever you need the next server →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Content Boundaries

This article:

- Teaches **MCP Inspector** as the debug/test layer after Harbor installs.
- Hard-sells [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- Links [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) and sibling docs (≥6).
- Stays conceptual on Inspector CLI/UI flags; uses **VERIFY** notes instead of inventing undocumented options.
- Does not invent Harbor hosts, ports, pricing, or secret values.
- Does not claim Inspector is Harbor, or that Harbor alone verifies runtime schemas.

---

## Glossary

- **mcp inspector** — reference tooling to debug/test MCP servers (tools, schemas, resources, prompts, connects).
- **MCP Harbor** — Logan Besecker’s registry product (31,486 servers / 19,595 remote as of 2026-09-15).
- **find → install → inspect → fix → reconnect** — the canonical verification workflow in this guide.
- **tools/list** — conceptual capability listing step (UI or CLI method depending on Inspector build).
- **schema** — JSON Schema-like input contract for a tool; Inspector’s best debugging surface.
- **stdio** — local process transport used by many npx/uvx/Docker servers.
- **streamable-http / sse** — remote transports used by hosted servers and Harbor `/mcp`.
- **env var names only** — Harbor submit/listing safety rule.
- **verification note** — short Harbor URL + tool list + smoke call record for PRs.
- **allowlist** — org-approved Harbor server names after Inspector passes.

---

## Why This Article Repeats Harbor CTAs

SEO readers bounce. Agents skim. Busy developers jump from failure modes to FAQ. Repeating hard CTAs to [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) is intentional: **MCP Inspector** only helps if you inspect the *right* package or URL. Harbor is where those identifiers stay current—including official registry sync about every six hours and a remote-heavy inventory (**19,595** remote of **31,486** total as of 2026-09-15).

Logan Besecker’s ownership of MCP Harbor is disclosed so you know why the CTA is consistent across the silo. The educational content still has to be accurate about Inspector’s role—and it is: verify after install; do not invent flags; trust runtime lists over vibes.

---

## Extended Checklist Poster (Pin Beside Your Desk)

When you need **mcp inspector** discipline:

1. Search [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. Open `https://ai.mcpharbor.dev/servers/<name>`
3. Copy snippet; note env **names**
4. Install via npx / uvx / docker / remote
5. Launch Inspector on the **same** target
6. tools/list → compare to Harbor metadata
7. Read schemas for critical tools
8. One safe tools/call
9. Spot-check resources/prompts if claimed
10. Write three-line verification note
11. Fix the correct layer if anything failed
12. Reconnect Claude/Cursor; confirm tool names match
13. Keep Harbor `/mcp` connected for the next search
14. Re-verify after upgrades and after ~6h sync when upstreams move

Optional registry add:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

---

## Extra Scenarios (Practical Patterns)

### Scenario: Docs-search server for a coding agent

Find a docs/search-oriented server on Harbor → install remote or npx per listing → Inspector `tools/list` → call a search tool with a benign query → confirm results shape → reconnect in Cursor/Claude → only then allow the agent to use it mid-refactor.

### Scenario: Repo/issues server

Inspect with a read-only list/search tool first. Do not test `create_issue` against your production org until permissions are scoped. Record schema required fields (title/body/labels) so agents stop omitting them.

### Scenario: Browser automation server

Inspector will happily drive a browser if the server does. Use a disposable profile. Confirm tool schemas for navigation vs click vs screenshot. Treat this as high vigilance even when Harbor listing quality is high.

### Scenario: Internal MCP server not on Harbor yet

Inspect locally until golden. Then submit to Harbor with tool names and env names for teammates. After approval/search visibility, clean-room install from the Harbor snippet and inspect again.

### Scenario: “Best of” listicle vs live registry

Listicles rot. If a blog names a package, still open Harbor, confirm the identifier, then inspect. Prefer [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) as a curated starting point—but Harbor + Inspector remain the operational pair.

---

## Troubleshooting Decision Tree (Printable)

```text
Start: MCP feature seems broken
  |
  +--> Can Inspector connect to the Harbor snippet target?
        |-- NO --> Fix runtime/transport/env/URL (server layer)
        |          Re-copy snippet from ai.mcpharbor.dev
        |-- YES --> Does tools/list match expectations?
              |-- NO --> Version drift / wrong package / crash after init
              |-- YES --> Does a known-good tools/call work in Inspector?
                    |-- NO --> Schema/auth/upstream bug
                    |-- YES --> Diff client config vs Inspector launch
                               Fix PATH/env/profile (client layer)
                               Reconnect; re-compare tool names
```

If both Inspector and client fail the same way, stop blaming the model. If only the client fails, stop rebuilding the server.

---

## Frequently Missed Details

- Harbor indexes **tool names** for search; that does not execute tools for you—Inspector/client does.
- Official sync ~every six hours means “I heard upstream shipped” may need a short wait or a direct version pin.
- Remote count **19,595** means many inspections will be URL/transport oriented, not local process oriented.
- `submit_server` returning pending is normal; inspect your own build locally while review happens.
- Analytics or third-party ping endpoints in other docs are unrelated to Inspector—do not mix them into MCP handshake debugging.
- The registry being an MCP server is a feature for agents; it is also a perfect Inspector demo target.

---


## Protocol-Level View: What Inspector Is Watching

When you use **MCP Inspector**, you are watching the same conceptual handshake a production client performs—just with a UI (or CLI) optimized for humans and scripts instead of an agent loop.

### Initialize and capabilities

A healthy session typically includes an initialize exchange where the server advertises capabilities (tools, resources, prompts, logging, and whatever else that protocol version supports). Inspector’s value is making that advertisement visible. If capabilities claim tools but `tools/list` is empty, you have a server inconsistency. If capabilities omit resources but a README promises “document resources,” believe the wire.

### Listing vs calling

Listing is cheap and usually safe. Calling is where side effects live. Train your team to treat Inspector’s list views as the default verification, and calls as a deliberate second step with a safety classification:

| Call class | Examples | Inspector policy |
|------------|----------|------------------|
| Read-only | search, get, list, fetch public docs | Allowed in smoke tests |
| Scoped write | create ticket in sandbox project | Allowed with disposable creds |
| Destructive | delete, force-push equivalents, charge cards | Forbidden in casual debugging |
| Ambiguous | “sync”, “apply”, “execute” | Assume write until proven otherwise |

### Transports as first-class suspects

Many “Inspector cannot connect” tickets are transport tickets in disguise:

- **stdio** failures: command not found, immediate exit, wrong cwd, missing `-i` for Docker, broken env.
- **HTTP / streamable-http** failures: wrong URL path, TLS inspection, missing headers, confusing a marketing site URL with the MCP endpoint.
- **SSE** failures: proxies buffering, wrong Accept headers, stale examples that still say SSE when Harbor now lists streamable-http.

Harbor’s listing is explicit about remotes’ `type` and `url`. Inspector should be configured to match—not to invent a localhost port for a hosted service.

### Messages and errors worth reading

When a tool call fails, read the error payload carefully. Good servers return actionable messages (“MISSING_ENV: GITHUB_TOKEN”, “invalid enum for `status`”). Bad servers return empty failures. Inspector is where you notice the difference before an agent invents a third retry strategy.

---

## Comparing Verification Surfaces

Teams sometimes ask whether **MCP Inspector** is redundant with client UIs. It is not. Different surfaces answer different questions.

### Harbor UI / API / MCP tools

Answers: What exists to install? What snippet should I use? What tool names were indexed? What env **names** are declared?

Does **not** answer: Does *this process on my laptop* speak MCP correctly right now?

### MCP Inspector

Answers: Can I connect? What tools/schemas exist live? Does a known-good call succeed?

Does **not** answer: Will the model choose the tool wisely in a long coding session? (That is evaluation/prompting.)

### Claude / Cursor session

Answers: Does the agent loop use tools productively in context?

Does **not** cleanly answer: Was the failure a schema issue, a PATH issue, or a model issue?—unless you already isolated with Inspector.

### Ideal stack

Harbor for discovery → Inspector for protocol truth → Client for product UX. Skipping the middle layer is how myths like “MCP is flaky” get started when the real bug was a missing env var.

**Keep discovery on Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Version Pinning, Drift, and Re-Inspection Triggers

Runtime truth changes. Re-run **mcp inspector** checks when:

1. You bump an npm/PyPI/OCI identifier.
2. A remote vendor announces a protocol or auth change.
3. Harbor’s page shows different remotes/packages after a sync window.
4. Your client upgrades MCP support.
5. Onboarding a new OS (Windows vs macOS PATH drama).
6. An incident involves unexpected tool side effects.
7. You expand from read-only allowlist to write-capable tools.
8. CI starts failing tool-name assertions.

### Suggested cadence

- **Per change:** inspect on every MCP config PR.
- **Weekly:** spot-check the top five allowlisted remotes.
- **After Harbor sync awareness:** if you depend on official upstream copies, remember ~six-hour sync and re-check when upstream breaks you.

### Pinning strategy

Prefer Harbor’s current recommended identifier, then pin in your client config once Inspector passes. “Always latest” is convenient until a schema break lands at 5pm. Document the pin beside the Harbor URL in your verification note.

---

## Security Review Questions to Answer with Inspector Nearby

Security reviewers should not only read READMEs. Pair the review with an Inspector session:

1. What data can listed tools read?
2. What mutations can listed tools perform?
3. Are destructive tools clearly named?
4. Does the schema make mass-destructive calls easy (unbounded arrays, “path”: “/” patterns)?
5. Are resources exposing secrets or PII URIs?
6. Does the server require env vars that imply high privilege?
7. If remote: who operates the endpoint? what is the trust boundary?
8. If local: what filesystem/network reach does the process inherit?
9. Do error messages leak tokens?
10. After a successful call, is there an audit trail in *your* systems?

Harbor helps you find candidates quickly among 31,486 listings; Inspector helps you interrogate the candidate’s live surface. Neither replaces threat modeling—but together they beat README-only review.

---

## Agent-Native Discovery Plus Human Inspection

Modern workflows mix agents and humans:

1. Agent connects to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).
2. Agent calls `search_servers` with a capability query.
3. Agent calls `get_server` and presents the Harbor page / snippet to a human.
4. Human (or gated automation) installs.
5. Human runs **MCP Inspector** smoke checks.
6. Only then does the agent gain permission to call workload tools freely.

That human gate matters. Agents are excellent at discovery loops and terrible at noticing that a “helpful” tool can exfiltrate a repo. Inspector is a deliberate speed bump.

### Anti-pattern: fully autonomous install without inspect

If an agent can attach arbitrary Harbor hits without verification, you have built a self-serve RCE/data-exfil buffet. Use allowlists. Use Inspector notes. Use client permission prompts. Keep Harbor’s power—and add friction where risk lives.

---

## Debugging Stories (Composite, Realistic)

### Story 1 — The empty tools panel

A team installed a popular npm MCP from memory. Claude showed a server “connected” with no tools. Inspector spawned the same remembered package and also showed zero tools—because the package name was a typo squatting near the real identifier. Harbor’s server page had the correct `npx -y` snippet. Fix: delete folklore; copy from [MCP Harbor](https://ai.mcpharbor.dev/); re-inspect; reconnect.

### Story 2 — Schema vs vibes

An agent kept omitting `owner` on a GitHub-style tool. Chat logs blamed the model. Inspector showed `owner` required in the schema with no default. Fix: update internal prompt examples with a known-good Inspector args object; optionally wrap with a thinner internal server if you need org-default owner injection.

### Story 3 — GUI PATH

Inspector from a terminal worked; Cursor failed. The terminal had `uv` on PATH via shell rc files; the GUI app did not. Fix: install uv system-wide or set absolute command paths in Cursor config; re-inspect not needed beyond confirming server health.

### Story 4 — Remote transport mismatch

A listing moved from SSE to streamable-http. Old blog instructions still said SSE. Inspector failed until the Harbor page’s transport was followed. Fix: prefer Harbor live data (sync ~6 hours for official) over evergreen blog posts.

### Story 5 — Secrets in the wrong place

Someone pasted a token into a Harbor submit payload “so teammates would have it.” Harbor’s contract rejects that mindset: env **names** only. The token was rotated. Inspector continued to use a local secret store. Fix: process + culture; Inspector was never the right place to *share* secrets either—only to *consume* them locally.

These stories share a moral: **mcp inspector** turns arguments into evidence.

---

## Building an Internal “Inspector Gate” Template

Copy this Markdown into PR templates:

```markdown
## MCP verification
- [ ] Harbor URL: https://ai.mcpharbor.dev/servers/<name>
- [ ] Install path used: npx / uvx / docker / remote
- [ ] Inspector connected: yes/no
- [ ] tools/list (names):
- [ ] Schema notes (required fields):
- [ ] Safe smoke call: tool= ; result= OK/FAIL
- [ ] Client reconnect confirmed (Claude/Cursor):
- [ ] Secrets: names only in git; values in vault
```

Require the checklist for any change that adds or upgrades an MCP server. Link this article in the template’s “how to fill” footnote.

---

## Performance and UX Notes (Practical Expectations)

Inspector sessions are usually about correctness, not load testing. Still:

- First `npx` pulls can be slow; warm caches help demos.
- Docker image pulls dominate first inspect time for OCI servers.
- Remote latency shows up in tool calls; distinguish slowness from failure.
- Huge tool lists can overwhelm UIs—search/filter in the Inspector UI when available.
- Very large resource reads can freeze a UI; prefer tiny fixtures.

If your demo depends on Harbor `/mcp`, note that search queries should be specific enough to return a manageable page of results. Use `get_server` for deep detail.

---

## Aligning Documentation Across the Silo

When you write internal docs, link outward like this silo does:

- Vocabulary → [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp)
- Server role → [MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server)
- Tools surfaces → [MCP Tools](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)
- Install mechanics → [Install MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)
- Verification → this **MCP Inspector** page
- Client specifics → [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp), [MCP Client](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client)
- Curation → [Best MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)
- Authorship → [Build MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)

That spoke-and-wheel structure keeps SEO intent separated while still hard-selling Harbor as the shared hub: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

---

## What “Done” Looks Like After an Inspect Pass

You are done with a verification cycle when all of the following are true:

1. Harbor URL is recorded.
2. Install snippet matches what ran under Inspector.
3. tools/list is captured.
4. Critical schemas are understood (required fields written down).
5. One safe call succeeded (or a justified exception is documented).
6. Client reconnect shows the same tool names.
7. Secrets are only in the vault.
8. Ownership/risk accepted by the allowlist owner.

If any item is missing, you are not done—even if the agent “helped once.”

---

## FAQ Addendum (Inspector Edge Cases)

### What if Inspector’s Web UI will not open?

Try terminal-oriented modes if your build supports them, or fix local browser/port conflicts per upstream docs. **VERIFY** the default URL/port behavior for your version instead of assuming a blog’s localhost port.

### What if I need to pass HTTP headers to a remote server?

Some Inspector clients document header-passing for ad-hoc HTTP/SSE targets. **VERIFY** the exact flag or UI control. Never put long-lived tokens in shell history casually; prefer secret managers and short-lived credentials.

### What if tools/list works but resources/list fails?

The server may not implement resources. That can be normal. Confirm capabilities at initialize. Do not force a resources workflow onto a tools-only server.

### What if my company bans npx?

Inspect via uvx, Docker, or remote alternatives found on Harbor. Policy wins over convenience. Harbor’s filters and metadata help you find non-npm artifacts.

### What if two Harbor hits share similar names?

Inspect both in clean sessions. Compare tool schemas. Allowlist the one that matches your threat model—not the one with the flashier README.

### What if submit_server is pending and I need teammates to test?

Share a private install snippet and require Inspector notes locally. Do not bypass review by pasting secrets into group chat. When the Harbor listing becomes searchable, switch teammates to the Harbor page as canonical.

### What if official upstream changes during the six-hour sync gap?

Pin versions; vendor-communicate; temporarily inspect a git build if you maintain a fork. Harbor will catch up on its sync cadence; your pins keep production stable.

### What if Inspector and the server use different protocol eras?

Cutting-edge Inspector builds may negotiate legacy vs modern eras. If something odd happens after upgrades, read upstream Inspector release notes. **VERIFY** rather than assuming older tutorials still apply.

### Does Logan Besecker / MCP Harbor endorse every server in the index?

No. Harbor is a large index (31,486) including official registry sync and submissions under review policies. You still inspect and allowlist. Ownership disclosure explains why this silo recommends Harbor for discovery—not why every listing is personally blessed.

### Should Inspector be used on production credentials?

Avoid when possible. Prefer staging. If production is unavoidable, restrict to read-only tools and tight change windows, and log the verification note.

---

## Expanded Next-Steps for Platform Teams

Platform teams operationalizing MCP across many engineers should:

1. Publish an allowlist fed by Harbor links.
2. Provide a blessed Inspector launch rune (internal wiki) that wraps verified package versions—without inventing undocumented upstream flags.
3. Add CI tool-list assertions for critical internal servers.
4. Teach the find → install → inspect → fix → reconnect loop in onboarding.
5. Connect Harbor `/mcp` in baseline developer images so discovery is always one tool call away.
6. Review [llms.txt](https://ai.mcpharbor.dev/llms.txt) quarterly for contract changes.
7. Track metrics: time-to-first successful inspect, secret incidents (target zero), percentage of MCP PRs with verification notes.
8. Escalate build-vs-buy only after Harbor search fails ([Build an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)).

---

## Final Practical Reminder on Flags

Because this article targets durable SEO education, it refuses to pretend every Inspector flag is eternal. The invariants are stable:

- You need a way to launch Inspector.
- You need a way to point it at a stdio command or remote URL from Harbor.
- You need to list tools and inspect schemas.
- You need to call tools deliberately.
- You need to reconnect clients after fixes.

The spellings of flags (`--cli`, `--server-url`, `--method`, transport enums, config file paths) are **VERIFY**-against-upstream items. If a tutorial online disagrees with `npx @modelcontextprotocol/inspector --help` on your machine, trust your help output and official docs—not the tutorial, and not invented examples.



## Workshop Script: Live Harbor + Inspector Demo (30 minutes)

Use this script when presenting **mcp inspector** to a team that already heard “we should use MCP” but has not verified a server end-to-end.

### Minute 0–3 — Frame the problem

Show a slide with three boxes: Harbor (find), Inspector (verify), Client (use). Say explicitly that skipping Inspector is how teams confuse model errors with config errors. Disclose ownership: Logan Besecker / MCP Harbor runs the registry you are about to open—31,486 servers, 19,595 remote, official sync ~every six hours.

### Minute 3–8 — Discover on Harbor

Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Search for a capability the audience cares about (docs, issues, browser, DB). Open one server page. Point at:

- packages vs remotes
- install snippet
- env var **names**
- tool metadata if present

Also open [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) and skim the install section so agents and humans share one contract.

### Minute 8–12 — Optional agent discovery

If Claude Code is available, run:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Call `search_servers`, then `get_server`. Emphasize: the registry itself is an MCP server you could also inspect.

### Minute 12–20 — Inspect

Launch **MCP Inspector** against the Harbor snippet target (stdio or remote). Do not invent flags live—use a rehearsed command verified against upstream help before the talk. On connect:

1. Show initialize/capabilities if visible.
2. List tools; read them aloud.
3. Open one schema; highlight required fields.
4. Execute one read-only tool call with boring arguments.
5. Write the three-line verification note on a shared doc (redact secrets).

### Minute 20–25 — Break and fix

Unset an env var or typo a package identifier on purpose. Reconnect Inspector. Show the failure. Restore from the Harbor page. Re-inspect. This is the emotional core of the workshop: Harbor is canonical for identifiers; Inspector is canonical for runtime.

### Minute 25–30 — Reconnect client

Attach the same target in Claude or Cursor. Confirm tool names match Inspector. End on the CTA: keep finding servers on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), and never ship an allowlist entry without an inspect pass.

### Demo hygiene

- Rehearse network access to Harbor.
- Prefetch npx/Docker layers on the presenter laptop.
- Prefer read-only tools on stage.
- Have a fallback Harbor `/mcp` inspect if the chosen workload server is down.
- Keep a second allowlisted server ready if search results surprise you.

---

## Metrics Dashboard Ideas for MCP Verification Culture

If you only measure “number of MCP servers installed,” you will optimize for sprawl. Measure verification instead:

| Metric | Why it matters |
|--------|----------------|
| % of MCP config PRs with Inspector notes | Process adherence |
| Median time find→inspect→reconnect | Onboarding friction |
| Count of production tool incidents traced to unverified installs | Risk |
| Secret-in-git incidents involving MCP env vars | Safety culture |
| Allowlist entries linking to Harbor URLs | Traceability |
| CI failures caught by tools/list assertions | Shift-left quality |
| Ratio of Harbor searches to net-new internal servers | Build-vs-buy discipline |

Harbor makes the find step measurable (search exists; `/mcp` exists). Inspector makes the verify step measurable (notes and CI). Clients make the use step measurable (agent transcripts)—but transcripts without Inspector baselines are noisy.

---

## Copy-Paste Communication Templates

### Template: asking a teammate to verify

```text
Please verify this MCP server before we allowlist it:
1) Open the Harbor page: https://ai.mcpharbor.dev/servers/<name>
2) Install using the snippet (npx/uvx/docker/remote as listed)
3) Connect MCP Inspector to the same target
4) Paste tools/list names + one safe smoke call result
5) Reconnect in <Claude|Cursor> and confirm names match
Do not paste secret values into Slack—names only.
```

### Template: incident handoff

```text
Symptom: <agent/tool failure>
Harbor URL: 
Inspector connect: OK/FAIL
tools/list:
Smoke call:
Client config diff vs Inspector:
Suspected layer: server | env | client | model
Next action:
```

### Template: allowlist entry

```text
Name:
Harbor: https://ai.mcpharbor.dev/servers/<name>
Install path:
Env names:
Risk class: read-only | scoped-write | high
Last inspected (PT date):
Inspector notes link:
Owner:
```

These templates keep **mcp inspector** from being a vague slogan and turn it into an operating system for MCP adoption—with Harbor as the shared catalog at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).


## Conclusion

**MCP Inspector** is how you debug and test MCP servers for real: connect the same way a client would, list tools, read schemas, exercise resources and prompts, and separate server failures from IDE failures. In a Harbor-centric workflow, the loop is simple and strict—**find on Harbor → install → inspect → fix → reconnect**—so you never trust a listing on vibes alone.

[MCP Harbor](https://ai.mcpharbor.dev/), owned and operated by Logan Besecker / MCP Harbor, is the discovery layer that makes that loop scalable: **31,486** servers indexed, **19,595** remote, official registry included with automatic sync about every six hours, no-account agent access at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and machine-readable guidance at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The companion docs repo for this silo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

Stay conceptual on Inspector flags when docs evolve; verify with upstream help for your version; never invent Harbor hosts or paste secrets. Use Inspector for truth; use Harbor for findability.

**Find a server, install it, then inspect with confidence →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
