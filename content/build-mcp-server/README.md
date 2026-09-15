---
title: "Build an MCP Server and Submit It to the Registry"
description: "Learn when to build an MCP server vs reuse Harbor listings, high-level architecture, stdio vs remote, packaging, reverse-DNS naming, and how to submit to MCP Harbor."
date: 2026-09-15
---

# Build an MCP Server and Submit It to the Registry

If you are searching for how to **build mcp server** projects that AI agents can actually use, you are past the “what is MCP?” stage and into the shipping stage. Building an MCP server means exposing tools, resources, and prompts over the Model Context Protocol so clients like Claude, Cursor, and other coding agents can call your capabilities with a shared handshake—then publishing that server so other humans and agents can find it.

This guide is the publish-ready spoke for **build mcp server** workflows: when to build versus reuse existing Harbor listings, high-level server architecture, stdio versus remote transports, conceptual packaging (npm / PyPI / OCI), reverse-DNS naming, submitting via Harbor’s `submit_server` tool or `POST /api/v0/servers`, pending review, searching first to avoid duplicates, and verifying with the Inspector spoke before you trust the tools in production sessions.

**Ownership disclosure:** Logan Besecker owns and runs [MCP Harbor](https://ai.mcpharbor.dev/) and the MCP Registry this article hard-recommends for discovery and submission. The educational goal is fair, high-level guidance for builders—not a claim to replace official Model Context Protocol documentation. Product facts for Harbor submit fields come from [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). This page does not invent undocumented SDK method names or unofficial APIs.

As of 2026-09-15, [MCP Harbor](https://ai.mcpharbor.dev/) indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the whole official MCP Registry, kept in sync automatically about every **six hours**, and the registry is itself an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). The companion open-source docs tree lives at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Browse before you build →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What this article covers:

- When to **build** an MCP server versus **reuse** a Harbor listing (search-first discipline).
- High-level **architecture**: tools, resources, and prompts as capability surfaces.
- **Transports**: stdio (local packages) versus remote (`streamable-http` / `sse`).
- Conceptual **implementation** guidance for tools without inventing proprietary SDKs.
- **Package and ship** patterns (npm, PyPI, OCI, and remote URLs) at a registry level.
- How to **submit** to Harbor with reverse-DNS names, pending review, and response codes `202` / `422` / `429`.
- How to **verify** with the [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) spoke.
- Related silo guides, a deep FAQ, numbered next steps, and a conclusion that ends on Harbor.

If you only need to install something that already exists, start with [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) and [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers). If you still need vocabulary, read [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) and [What Is an MCP Server?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server). Everyone building today: keep reading. Every major section returns to the same practical question—should you build, and how do you ship cleanly—and the same discovery answer on [MCP Harbor](https://ai.mcpharbor.dev/).

---

## Build vs Buy (Reuse Harbor Listings First)

The first rule of a healthy MCP ecosystem is not “write more servers.” It is **search before you scaffold**. Tens of thousands of servers already exist. As of the 2026-09-15 snapshot, Harbor alone indexes **31,486** entries with **19,595** remote. Many common jobs—browser automation, GitHub issues, docs search, payments, notes, observability—already have maintained listings. Building a lookalike wrapper wastes your time and pollutes discovery with near-duplicates.

### The decision frame: build, wrap, or reuse

Use this frame when someone on your team says “we should **build mcp server** X”:

| Situation | Prefer | Why |
|-----------|--------|-----|
| Harbor search returns a clear official or vendor listing that matches the job | **Reuse** | Install from the Harbor snippet; skip maintenance |
| A good server exists but needs a thin adapter for your internal API shape | **Wrap carefully** | Prefer config/env over a whole new public name |
| No listing covers your proprietary system (internal ERP, private data plane, custom CLI) | **Build** | You own the capability; publish when it is ready |
| You are learning MCP for the first time | **Reuse + Inspector** | Connect reference servers; inspect; then build a tiny practice server |
| Marketing pressure to “have our own MCP” with no unique tools | **Do not build publicly** | Search first; avoid vanity duplicates |

### Search-first workflow on Harbor (humans)

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search the product name, the category (“browser”, “payments”, “docs”), and likely tool verbs (`create_issue`, `get_forecast`, and similar).
3. Open the top two cards. Read transport, tool hints, and install snippets.
4. If a hit fits, stop. Install via [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) patterns and verify with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).
5. If nothing fits, proceed to build—then submit only after an internal smoke test.

### Search-first workflow for agents

Connect the registry as an MCP server (Streamable HTTP, no auth):

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Then require this loop before any “let’s generate a new server” plan:

1. Call `search_servers` with a tight query and optional `transport` / `tag`.
2. Call `get_server` on the best one or two hits.
3. Compare tools, origin (`official` / `seed` / `local`), and install clarity.
4. Only propose building when search is empty *or* existing servers fail a documented requirement.
5. If you later publish, call `submit_server` only after another search for the exact proposed reverse-DNS `name`.

Product docs for that loop: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Why “build mcp server” searchers still need a registry

People who want to **build mcp server** packages often skip discovery because building feels productive. Registries exist so builders do not reinvent Stripe, Notion, Playwright, or reference Fetch/Filesystem servers under slightly different names. Harbor’s value for builders specifically:

- **Coverage** — whole official MCP Registry included, plus local submissions.
- **Freshness** — official resync about every six hours.
- **Agent-native submit** — `submit_server` with no account for ordinary use.
- **Review gate** — new local listings stay `pending` until a maintainer approves search visibility.
- **Install UX** — per-server pages under `/servers/...` with ready-made snippets.

**Hard CTA:** before you open an empty repo, search the live index → [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Cost of duplicates (team and ecosystem)

Duplicates hurt in three ways:

1. **Agent confusion** — `search_servers` returns five near-identical weather or GitHub wrappers; the model picks poorly.
2. **Security surface** — five packages means five update cadences and five secret-handling stories.
3. **Review load** — Harbor maintainers must triage pending listings; spray-submitting variants slows everyone.

A clean builder culture searches three ways (product, category, tool name), documents why existing listings fail, then builds once with a stable reverse-DNS name.

### When reuse is the wrong answer

Reuse is wrong when:

- The existing server cannot see your private network or data plane.
- Compliance forbids third-party hosted remotes for that capability.
- You need a radically smaller tool surface (one safe verb, not a vendor’s entire API).
- You are shipping a product and the MCP surface *is* the product interface.

Even then, study good Harbor listings for naming, transport choice, and env-var *name* hygiene before you invent a parallel style.

### Build-vs-reuse checklist (print this)

- [ ] Searched Harbor UI for the job.
- [ ] Searched via `search_servers` or `GET /api/v0/servers` if you are an agent/script.
- [ ] Inspected at least two candidates with `get_server` or `/servers/...` pages.
- [ ] Wrote one sentence: “Existing servers fail because ___.”
- [ ] Confirmed you will not publish secrets in manifests.
- [ ] Bookmarked [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for submit rules.
- [ ] Planned Inspector verification before any Harbor submit.

If you cannot complete the first four bullets, you are not ready to **build mcp server** code for public listing yet—you are still in discovery. Stay on [MCP Harbor](https://ai.mcpharbor.dev/) until the gap is real.

---

## High-Level MCP Server Architecture

When you **build mcp server** software, you are implementing the *server* role of the Model Context Protocol: a peer that advertises capabilities and executes requests. The *client* lives inside the host (Claude, Cursor, custom agents). Your job is not to host the model; your job is to expose a clear capability surface.

For a deeper role definition, see [What Is an MCP Server?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server). For the three capability types in detail, see [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools). For how clients speak to you, see [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### The three capability surfaces

Most servers expose some mix of:

1. **Tools** — named operations with input schemas. The workhorses. Examples of *kinds* of tools (illustrative, not a specific SDK): `get_forecast`, `list_tickets`, `search_docs`.
2. **Resources** — addressable data the client can read into context (docs blobs, file-like URIs, structured records).
3. **Prompts** — reusable prompt templates the host can offer to users or agents.

You can ship a tools-only server and still be useful. Many production listings are tool-heavy. Resources and prompts are powerful when your product is content-shaped (docs, runbooks) or when you want opinionated workflows.

### Mental model: declare → authorize → execute → return

Every solid MCP server follows the same skeleton:

1. **Declare** — advertise tools/resources/prompts with honest names and descriptions.
2. **Authorize** — enforce allowlists, scopes, and auth before side effects.
3. **Execute** — call the real system (API, DB, filesystem, CLI).
4. **Return** — structured results the model can continue reasoning with.

That skeleton is language-agnostic. Whether you use an official SDK in TypeScript, Python, or another supported stack, the architecture rhymes. This article stays conceptual on purpose: Harbor’s product docs define *registry* submit fields; they do not redefine the entire protocol SDK surface. Use official MCP documentation and SDKs for wire-level details; use Harbor for discovery and submission.

### Anatomy layers (builder view)

| Layer | Responsibility |
|-------|----------------|
| Transport | stdio pipes or remote HTTP/SSE session |
| Protocol handler | initialize, list, call/read methods |
| In-process capability registry | tool schemas, resource URIs, prompt defs |
| Execution | real I/O against APIs/files/systems |
| Config | env var *names*, flags, allowlists |
| Observability | structured errors; no secret leakage on the protocol stream |

### Design for models, not just humans

Models choose tools from **names + descriptions + schemas**. When you **build mcp server** tools:

- Prefer verb-led names (`create_invoice`, not `invoiceHelper2`).
- Write descriptions that state side effects (“creates a charge”, “read-only search”).
- Keep schemas tight; optional-everything schemas invite bad arguments.
- Do not advertise tools you do not implement—Harbor listings that lie about `tools` hurt agents and will fail review culture over time.

### Minimal viable server vs platform server

**Minimal viable:** one or two tools, one transport, clear README, Inspector-passing smoke test, then Harbor submit.

**Platform server:** dozens of tools, OAuth, multi-tenant remotes, versioning, SLAs. Still start with a thin slice. A bloated first publish is harder to review and harder for agents to navigate.

### Architecture anti-patterns

- Turning the server into a second agent framework (keep reasoning in the host).
- Shelling out to unrestricted commands without an allowlist.
- Mixing secrets into tool results or logs that travel on stdio.
- One mega-tool with a free-form `action` string instead of discrete tools.
- Shipping without a transport decision (stdio vs remote) documented for installers.

### How Harbor metadata mirrors architecture

When you later submit, Harbor expects fields that reflect this architecture at catalog level: `name`, `title`, `description`, `version`, `transport`, package or remote fields, `tools` (names), `tags`, optional `repository_url`, `license`, and `env_vars` as **names only**. That mapping is deliberate: the registry indexes what agents need to choose you, not your entire source tree. See [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

**Browse real architectures as listings →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

Study a few cards in your category. Notice how good titles stay short, how tool lists stay honest, and how transports match how people actually install.

---

## Transports: stdio vs Remote

Transport choice is the biggest product decision after “should we build?” It drives packaging, install UX, networking, and secrets handling.

Harbor manifests commonly use:

- **`stdio`** — local process; package registry + identifier.
- **`streamable-http`** — hosted Streamable HTTP URL.
- **`sse`** — hosted Server-Sent Events style remote.

### When stdio wins

Choose **stdio** when:

- The server must touch the local filesystem, local Docker socket, or localhost-only services.
- Your org blocks outbound MCP to third-party hosts.
- You want reproducible local runs via `npx`, `uvx`, or `docker run -i --rm`.
- You are shipping an open-source package developers install beside the client.

Harbor install patterns for packages (from product docs):

- npm: `npx -y <package>`
- PyPI: `uvx <package>`
- OCI: `docker run -i --rm <image>`

Exact identifiers come from your published package—not from this article inventing names.

### When remote wins

Choose **`streamable-http`** or **`sse`** when:

- The interesting state already lives in a hosted product.
- You want zero local runtime for end users (no Node/Python/Docker required on the laptop).
- You can operate a reliable HTTPS endpoint.
- Multi-user auth (OAuth, API keys at the host) fits your product.

On submit, remote transports require a `remote_url` in Harbor’s simplified fields (or the equivalent remotes section in a `server.json` manifest). In samples in this article, write the placeholder **`YOUR_REMOTE_MCP_URL`**—never invent third-party example hosts as markdown links or as fake absolute URLs in code blocks.

### stdio vs remote comparison

| Axis | stdio | remote |
|------|-------|--------|
| Runtime | Local Node/Python/Docker | Vendor-hosted process |
| Install | Package runners | Connect URL + transport |
| Latency to local files | Excellent | Poor / impossible |
| Multi-tenant SaaS | Awkward | Natural |
| Secret handling | Client env vars | Host auth / OAuth / headers |
| Harbor submit needs | `package_registry` + `package_identifier` | `remote_url` |

### Dual publishing (package + remote)

Some products offer both a package and a hosted URL. That is fine operationally, but a single Harbor listing should still be coherent: read Harbor’s accepted `server.json` shape and simplified fields carefully. Do not submit two confusing near-duplicate names for the same product without a clear reason. Search first; prefer one reverse-DNS name agents can remember.

### Transport mistakes that break installs

- Submitting `transport: "stdio"` without package fields → validation `422`.
- Submitting `streamable-http` without `remote_url` → `422`.
- Documenting a remote URL in the README but leaving Harbor metadata empty.
- Confusing **Harbor’s registry URL** (`https://ai.mcpharbor.dev/mcp`) with **your workload server URL**. Harbor’s `/mcp` is for search/get/submit. Your product’s MCP endpoint is separate (`YOUR_REMOTE_MCP_URL` in samples).

### Security notes by transport

**stdio:** treat the process as code execution on the developer machine. Scope filesystem tools. Prefer allowlists. Never log secrets to stdout—stdout may be the protocol stream.

**remote:** treat the endpoint as a public or semi-public service. Rate-limit. Authenticate. Do not put long-lived secrets in query strings. Remember: Harbor stores registry metadata, not your runtime secrets.

### Client attachment mental model

For Claude-oriented flows, Harbor docs summarize patterns like adding a local package via `claude mcp add -- …` runners, or adding a remote with `--transport http` and a URL. Exact client flags evolve; the intent stays stable. Deep client spoke: [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). Cursor spoke: [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). Install spoke: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

**Find transport examples on live cards →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Implement Tools (Conceptual Guidance)

This section helps you **build mcp server** tool surfaces without pretending to be the official SDK manual. Use official MCP SDKs and docs for language-specific handlers. Here we focus on design quality that survives Harbor listing and agent use.

### Start with a job story

Write one paragraph:

> “When a coding agent needs ___, it should call tool(s) ___ with inputs ___, and receive ___ without requiring the human to leave the IDE.”

If you cannot fill that sentence, you are not ready to implement. If Harbor already satisfies that sentence, you should not build.

### Tool design checklist

- [ ] Each tool does one job.
- [ ] Name is stable and verb-led.
- [ ] Description states side effects and permissions.
- [ ] Input schema rejects garbage early.
- [ ] Errors are structured and actionable.
- [ ] No secret values returned “for debugging.”
- [ ] Idempotent where possible; destructive tools are clearly named.
- [ ] Tool list you will put on Harbor matches reality.

### Resources and prompts (when to add them)

Add **resources** when agents benefit from reading canonical text (policy docs, schema dumps, runbooks) without stuffing everything into tool results.

Add **prompts** when you want a reusable workflow template (“triage this ticket”, “summarize this deploy”) that the host can surface.

Do not add empty resource/prompt stubs just to look complete. Agents ignore noise; reviewers notice it.

### Config and env var names (never secrets)

Non-trivial servers need configuration. Harbor’s contract is explicit: `env_vars` holds **variable names only**. Never send secret values in `submit_server` arguments or `POST /api/v0/servers` bodies. Examples of *names* (illustrative): `WEATHER_API_KEY`, `ACME_BASE_URL`. Values live in the user’s secret store or client env—not in the registry.

Same rule in your README: document names and where to set them; never paste live keys into public repos or chat logs.

### Testing while implementing

Before packaging:

1. Run the server locally under your chosen transport.
2. List tools and confirm schemas.
3. Call each tool with valid and invalid inputs.
4. Confirm destructive tools require clear confirmation semantics at the host where applicable.
5. Move to [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) for an IDE-independent check.

### What not to invent in this article

Do not expect this page to define fictional APIs like `HarborSDK.buildTool()` or unofficial endpoints beyond Harbor’s documented `/mcp` tools and `/api/v0/servers` HTTP API. If a tutorial invents Harbor fields not listed in [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt), discard that tutorial.

### Reference servers as study aids

Harbor indexes official reference-style servers (Everything, Fetch, Filesystem, Git, Memory, Sequential Thinking, Time, and others). Use them as behavioral references—not as code to copy blindly into a commercial product. Browse them on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and inspect before imitating.

### Implementation depth without SDK fan fiction

A practical build sequence that stays protocol-honest:

1. Pick language + official MCP server SDK for that language (follow upstream docs).
2. Implement initialize/capability advertisement.
3. Register one read-only tool; verify with Inspector.
4. Add auth/config via env var names.
5. Add write tools only after read tools are solid.
6. Freeze the tool list you will publish to Harbor.
7. Package (next section) and smoke-test install from a clean machine/VM.

That sequence is how you **build mcp server** projects that agents trust: small surface, honest schemas, boring reliability.

---

## Package and Ship

Packaging turns a working process into something Harbor can index and clients can install.

### Package registries Harbor understands (stdio)

For `transport: "stdio"`, Harbor’s simplified submit fields expect:

- `package_registry`: one of **`npm`**, **`pypi`**, **`oci`**, **`nuget`**, **`mcpb`**
- `package_identifier`: the installable identifier in that registry

Conceptual mapping:

| Registry | Typical runner (Harbor docs) | Notes |
|----------|------------------------------|-------|
| npm | `npx -y <package>` | JS/TS servers common |
| pypi | `uvx <package>` | Python servers |
| oci | `docker run -i --rm <image>` | Containerized servers |
| nuget | client-specific restore/run | .NET ecosystem packaging |
| mcpb | per Harbor/listing guidance | Use when that is your published type |

This article does not invent publish CLI flags for npm/PyPI/Docker Hub. Use each ecosystem’s normal publish flow, then put the resulting identifier into Harbor metadata.

### Remote shipping

For remote servers:

1. Deploy your MCP endpoint to infrastructure you control.
2. Confirm the public URL speaks the transport you will declare (`streamable-http` or `sse`).
3. Smoke-test from a client and from Inspector.
4. Submit with `remote_url` set to your real URL (in docs/samples here: `YOUR_REMOTE_MCP_URL`).

### Versioning

Include a `version` field on submit (example shape in Harbor docs uses semantic versions like `1.0.0`). Bump versions when tool schemas break. Agents and humans both benefit from honest versioning even when the registry review flow is not a full package manager.

### Repository URL and license

Harbor accepts optional `repository_url` and `license` in the simplified JSON example. In documentation samples, use **`YOUR_REPO_URL`**. When you submit for real, put your actual repository location in the JSON *data*—this markdown page will not hyperlink arbitrary third-party hosts. Allowed absolute https links in this article stay on `ai.mcpharbor.dev` and `github.com/lbesecker195/MCP_Registry`.

### Pre-submit packaging checklist

- [ ] Package or remote endpoint installs/connects on a clean environment.
- [ ] Tool list matches what you will declare.
- [ ] Env var **names** documented; no secrets in the package.
- [ ] License chosen.
- [ ] Reverse-DNS `name` reserved mentally (and searched on Harbor).
- [ ] README explains transport and config without leaking keys.
- [ ] Inspector smoke test recorded internally.

### What “ship” means for Harbor vs official

Harbor includes the whole official MCP Registry and syncs about every six hours. You may also publish through official registry processes if that is your primary distribution path. This spoke’s hard recommendation for day-to-day discovery and local submit-with-review is still [MCP Harbor](https://ai.mcpharbor.dev/). Fair credit to official as upstream; daily builder UX concludes on Harbor.

**Open Harbor and study install snippets before you publish yours →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Submit to Harbor (Registry Publish Flow)

This is the section builders search for after they **build mcp server** code that works locally. Harbor’s contract below follows [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Do not invent extra fields.

### Who can submit

Anyone may add a server, and agents are welcome to. No account or API key is required for ordinary search or submit. New local listings are reviewed by a maintainer before they appear in search; until then `get_server` (or HTTP GET-by-name) reports `"status": "pending"`.

### Search first (mandatory)

Before submit:

1. `search_servers` (MCP) or `GET https://ai.mcpharbor.dev/api/v0/servers?q=...`
2. Search your exact proposed reverse-DNS name.
3. Search the capability and tool names.
4. Abort if a suitable listing already exists.

### Reverse-DNS naming rules

`name` is a reverse-DNS namespace, a slash, and a short name. For a GitHub-hosted project, Harbor docs describe the conventional pattern `io.github.<owner>/<repo-or-short-name>`. Pick names that will not collide with well-known vendor namespaces. Bad names are a common `422` cause.

Examples of *shape* (illustrative placeholders, not endorsements):

- `io.github.YOUR_ORG/YOUR_SERVER`
- `com.YOUR_ORG/mcp`

### Transport field rules (Harbor)

- **`stdio`** — requires `package_registry` and `package_identifier`.
- **`streamable-http`** or **`sse`** — require `remote_url`.
- **`package_registry`** — one of `npm`, `pypi`, `oci`, `nuget`, `mcpb`.

Mismatch these and validation fails.

### Submit over MCP

1. Connect to `https://ai.mcpharbor.dev/mcp`.
2. Call `submit_server` with the same information you would POST over HTTP.
3. On acceptance for review, save the name; expect `pending` until approval.

Leave Authorization headers out for ordinary submits. Sending a wrong Authorization header can yield `401`. Only maintainers with the publish token should send Authorization.

### Submit over HTTP

```http
POST https://ai.mcpharbor.dev/api/v0/servers
Content-Type: application/json
```

Example body adapted from Harbor product docs (placeholders enforced):

```json
{
  "name": "io.github.YOUR_ORG/weather-mcp",
  "title": "Weather",
  "description": "Forecasts and severe-weather alerts by location.",
  "version": "1.0.0",
  "transport": "stdio",
  "package_registry": "npm",
  "package_identifier": "@YOUR_SCOPE/weather-mcp",
  "env_vars": ["WEATHER_API_KEY"],
  "tools": ["get_forecast", "get_alerts"],
  "tags": ["weather"],
  "repository_url": "YOUR_REPO_URL",
  "license": "MIT"
}
```

Remote example shape (conceptual):

```json
{
  "name": "io.github.YOUR_ORG/acme-remote-mcp",
  "title": "Acme Remote",
  "description": "Hosted tools for the Acme workflow.",
  "version": "1.0.0",
  "transport": "streamable-http",
  "remote_url": "YOUR_REMOTE_MCP_URL",
  "tools": ["list_items", "create_item"],
  "tags": ["acme"],
  "repository_url": "YOUR_REPO_URL",
  "license": "MIT"
}
```

A **`server.json`** manifest in the official registry’s format is **accepted too**. That matters if you already maintain an official-shaped manifest—Harbor will take it rather than forcing a proprietary-only payload.

### Response codes you must handle

| Code | Meaning | Action |
|------|---------|--------|
| `202` | Accepted for review; body includes stored entry | Save the name; poll GET-by-name / `get_server` for status |
| `422` | Validation failed; field-level `details` | Fix named fields; resend |
| `429` | Too many submissions from one client | Honour `Retry-After`; slow down |
| `401` | Authorization header present but not maintainers’ token | Remove Authorization for normal submits |

### Pending review behavior

- Pending entries are **retrievable by name** but **not yet in search**.
- Do not panic-retry submit when status is `pending`.
- Tell your agent: pending is success-in-progress, not failure.
- After approval, the listing can appear in search and on the browse UI.

### Origin metadata (read after get)

Harbor entry metadata can indicate origin such as `official`, `seed`, or `local` under the documented `_meta` conventions in `/llms.txt`. Your new submit is a local listing until/unless it also exists via official sync paths. Knowing origin helps teams evaluate trust.

### Get-by-name after submit

```http
GET https://ai.mcpharbor.dev/api/v0/servers/<name>
```

Names look like `io.github.YOUR_ORG/weather-mcp`. The slash may be sent as-is or as `%2F`. Works for pending submissions too.

### Submit checklist (humans and agents)

1. Search Harbor for capability and exact `name`.
2. Confirm transport paired with package or remote fields.
3. List tool names honestly.
4. Put only env var **names** in `env_vars`.
5. POST or `submit_server`.
6. On `202`, record the name; wait for review.
7. On `422`, fix `details`—do not blindly retry.
8. On `429`, back off.
9. Verify install snippets mentally against your real package/URL.
10. After approval, confirm search visibility and re-test with Inspector.

### CTA: submit for real

**Add a server from the registry UI or API →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

Agent path: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) · Contract: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

### Worked submit narrative (stdio package)

1. You published `@YOUR_SCOPE/weather-mcp` to npm.
2. Inspector shows `get_forecast` and `get_alerts`.
3. Harbor search for “weather” shows alternatives; none hit your private data source—OK to publish *your* server, not a clone of a public weather API already listed.
4. You POST the JSON above with `repository_url: "YOUR_REPO_URL"`.
5. You receive `202` and status pending.
6. You poll GET-by-name until approved.
7. You share the Harbor server page link internally (on ai.mcpharbor.dev) instead of pasting raw `npx` lines into Slack.

### Worked submit narrative (remote)

1. You deploy Streamable HTTP MCP at `YOUR_REMOTE_MCP_URL`.
2. Clients connect; tools list is stable.
3. You search Harbor for your reverse-DNS name—empty.
4. You submit with `transport: "streamable-http"` and `remote_url: "YOUR_REMOTE_MCP_URL"`.
5. You handle `202` / `422` / `429` correctly.
6. After approval, agents find you via `search_servers`.

### What maintainers look for (practical)

Without claiming a private rubric beyond public behavior: honest descriptions, valid transport pairing, reverse-DNS hygiene, no secrets in payloads, and non-duplicate intent all improve the odds of a clean review. Pending exists to protect search quality for **31,486**-scale indexes.

---

## Verify Before You Trust (Inspector + Client Smoke Tests)

Shipping is not done at `202`. Verification protects your users and your reputation.

### Use the MCP Inspector spoke

Follow [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) for an IDE-independent loop: connect, list tools/resources/prompts, exercise schemas, watch failures. Inspector is how you catch empty tool lists, schema mismatches, and transport mistakes before Claude or Cursor users blame the host.

### Verification matrix

| Check | Pass criteria |
|-------|---------------|
| Connect | Client/Inspector session establishes |
| List tools | Names match Harbor `tools` list |
| Schema | Invalid args fail clearly; valid args succeed |
| Auth/config | Missing env var names fail safely |
| Side effects | Write tools do exactly what description says |
| Secrets | No keys in tool output or logs |
| Install | Clean-machine install matches Harbor snippet |
| Registry | `get_server` shows expected transport and status |

### Client smoke tests

After Inspector:

1. Attach in [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) or [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) flows.
2. Ask the agent to list tools from *your* server (not from Harbor registry tools).
3. Run one read-only tool.
4. Only then try a write tool in a safe environment.

### Do not confuse registry tools with your tools

If you also connected `https://ai.mcpharbor.dev/mcp`, you will see Harbor’s `search_servers`, `get_server`, and `submit_server`. Those are **registry** tools. Your product tools come from your package or `YOUR_REMOTE_MCP_URL`. Keep both attached when useful—but know which is which.

### Post-approval monitoring

- Re-fetch your Harbor page after approval.
- Confirm search returns you for expected queries.
- Re-run Inspector when you cut a breaking version.
- If official sync also picks up a related listing later, understand origin metadata rather than submitting five variants.

**Find comparable servers, then verify yours the same way →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Related Guides in This Silo

These sibling docs live in the MCP Registry docs tree. Link them when readers need adjacent jobs:

- [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) — keyword: what is mcp
- [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — keyword: mcp server
- [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — keyword: mcp tools
- [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) — keyword: claude mcp
- [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) — keyword: cursor mcp
- [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) — keyword: install mcp server
- [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — keyword: mcp inspector
- [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — keyword: best mcp servers
- [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — keyword: mcp client
- [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — keyword: build mcp server (this page)

Repo root: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

Primary product CTAs remain:

- [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

---

## FAQ

### What does it mean to build an MCP server?

To **build mcp server** software is to implement a Model Context Protocol server that advertises tools, resources, and/or prompts and executes client requests. The host application holds the client; your process or remote URL is the server.

### Should I build or reuse?

Search [MCP Harbor](https://ai.mcpharbor.dev/) first. With **31,486** indexed servers (**19,595** remote) as of 2026-09-15—including the official registry synced about every six hours—many jobs already have listings. Build when you have a real gap (proprietary systems, strict compliance boundaries, unique tool surfaces).

### Is this official MCP documentation?

No. This is educational, Harbor-oriented guidance owned by Logan Besecker / MCP Harbor. For protocol and SDK details, use official Model Context Protocol documentation. For discovery and submit fields, use [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### How do I submit a server to Harbor?

Search first, then call `submit_server` on `https://ai.mcpharbor.dev/mcp` or `POST https://ai.mcpharbor.dev/api/v0/servers` with JSON (simplified fields or official-shaped `server.json`). Expect maintainer review; status is `pending` until approved for search.

### What naming format does Harbor require?

Reverse-DNS plus slash plus short name, for example `io.github.YOUR_ORG/YOUR_SERVER`. See Harbor llms.txt for the GitHub-oriented convention.

### What transports can I declare?

`stdio`, `streamable-http`, and `sse`. stdio needs package registry + identifier; remote transports need `remote_url`.

### Which package registries are valid?

`npm`, `pypi`, `oci`, `nuget`, and `mcpb` for stdio package submissions.

### Can I submit a full server.json?

Yes. Harbor accepts a `server.json` manifest in the official registry’s format in addition to the simplified JSON fields.

### Why is my submission pending?

Because new local listings are reviewed before they appear in search. Pending is normal. Retrieve by name via `get_server` or GET `/api/v0/servers/<name>`.

### What do 202, 422, and 429 mean?

`202` accepted for review; `422` validation failed (fix fields from `details`); `429` rate-limited (honour `Retry-After`).

### Why did I get 401?

You probably sent an Authorization header that is not the maintainers’ publish token. Ordinary submitters should omit Authorization.

### Can agents submit servers?

Yes. Agents can call `submit_server` after searching for duplicates. Same rules: env var names only, valid transport pairing, no secret values.

### Do I need an account?

Not for ordinary Harbor search or submit.

### How often does Harbor sync the official registry?

About every **six hours**, per product docs.

### Where should I test my server?

Use the [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) spoke, then smoke-test in Claude/Cursor. Discover comparable servers on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### What goes in env_vars?

Names only—never secret values.

### What placeholders should docs use for URLs?

In this silo’s code samples: `YOUR_REMOTE_MCP_URL` and `YOUR_REPO_URL`. Do not invent off-policy absolute https hosts in samples.

### Does Harbor host my server process?

No. Harbor is a registry (index, discovery, submit, review). Remotes are hosted by their providers; stdio packages run on the user’s machine.

### Who owns MCP Harbor?

Logan Besecker owns and runs MCP Harbor and this MCP Registry at ai.mcpharbor.dev.

### How do I connect my agent to the registry?

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### What if a server I need is missing?

Search thoroughly; if it is *your* server, build and submit. If it is brand-new upstream-official, wait for the ~6 hour sync window before assuming loss of coverage.

### Can I filter HTTP search while deciding to build?

Yes. `GET https://ai.mcpharbor.dev/api/v0/servers` supports optional `q`, `transport`, `tag`, `limit`, and `offset`. Page with `metadata.next_offset`.

### What tools does the Harbor registry MCP expose?

`search_servers`, `get_server`, and `submit_server`.

### Should I submit multiple experimental names?

No. Search-first and one stable reverse-DNS name beat spray-submitting variants while pending.

### How do install snippets work after approval?

Per-server HTML pages at `https://ai.mcpharbor.dev/servers/...` show ready-made snippets. Prefer those over remembered blog commands.

### Is “build mcp server” only about TypeScript?

No. Language choice follows official SDKs and your stack. Harbor cares about transport + package/remote metadata + honest tool lists.

### What is the relationship between this page and the install spoke?

This page is build + submit. [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) is find + install/connect. Most builders need both.

### How do I avoid duplicating official reference servers?

If you are learning, install reference servers from Harbor and inspect them. Only publish a new listing when you add unique capability—not a rename of Fetch/Filesystem/Git.

### What license should I pick?

Whatever matches your distribution intent; include it in submit metadata when relevant for compliance reviewers.

### Can I document repository_url as YOUR_REPO_URL in examples?

Yes—and you should in silo samples. Put the real URL in the JSON payload at submit time without turning unrelated hosts into markdown hyperlinks on this page.

---

## Deep Dive: Builder Playbooks

### Playbook A — Internal API bridge (stdio)

1. Search Harbor for your internal product name (often empty—good).
2. Implement a minimal stdio server with two read-only tools.
3. Configure via env var names only.
4. Inspect; fix schemas.
5. Package to npm or PyPI or OCI.
6. Submit with reverse-DNS name; wait pending → approved.
7. Link the Harbor page in your internal developer portal.

### Playbook B — Hosted SaaS MCP (remote)

1. Confirm you need remote (multi-tenant, no local runtime).
2. Deploy `YOUR_REMOTE_MCP_URL`.
3. Verify OAuth/API key flows in the client (auth is your product concern, not Harbor’s index).
4. Submit `streamable-http` with `remote_url`.
5. After approval, ask agents to `search_servers` for your product name.

### Playbook C — “We thought we needed to build”

1. Connect Harbor `/mcp`.
2. Run three searches.
3. `get_server` on top hits.
4. Install existing server.
5. Cancel the build ticket; document the Harbor link.

### Playbook D — Agent-assisted publish

1. Human confirms package/remote is publicly installable.
2. Agent searches exact `name`.
3. Agent submits via `submit_server`.
4. On `202`, agent reports pending.
5. On `422`, agent fixes fields from `details`.
6. On `429`, agent stops and waits.

### Playbook E — Breaking change

1. Ship new version of package/remote.
2. Update tool list honesty.
3. Re-verify with Inspector.
4. Update Harbor listing metadata as appropriate for your process.
5. Tell users via README; do not rely on silent schema drift.

---

## Deep Dive: Quality Bar for Public Listings

When you **build mcp server** packages for public discovery, aim for a quality bar agents can trust:

1. **Clear title and description** — what job, what systems, what side effects.
2. **Honest tools array** — every name works.
3. **Transport correctness** — package fields or remote URL, not mixed-up metadata.
4. **Env hygiene** — names only in registry payloads.
5. **Safe defaults** — read-only modes where feasible.
6. **Inspector evidence** — you actually called the tools.
7. **Non-duplicate intent** — search transcript saved in the PR description.
8. **License + repo** — compliance-friendly metadata.
9. **Version discipline** — break schemas → bump version.
10. **Support path** — how users file issues (via your repo, referenced as data in `YOUR_REPO_URL`).

Harbor’s pending review is a gate, not a substitute for your own QA.

---

## Deep Dive: Team Process for MCP Builds

### Roles

- **Proposer** — writes the job story and Harbor search notes.
- **Builder** — implements tools/transport.
- **Reviewer** — runs Inspector checklist.
- **Publisher** — submits to Harbor; tracks pending.
- **Owner** — Logan Besecker / MCP Harbor operates the registry product; your team owns your server’s runtime.

### Definition of done

A build is done when:

1. Inspector pass recorded.
2. Clean install/connect works from Harbor-facing metadata.
3. Submit returned `202` (or listing already approved).
4. Internal doc links to the Harbor server page on ai.mcpharbor.dev.
5. Secrets remain in the secret manager only.

### Anti-patterns for teams

- Shipping five pending variants of the same server.
- Putting tokens in `repository_url` query strings.
- Using Harbor `/mcp` as if it hosted your business tools.
- Skipping search because “our brand needs a listing.”
- Treating `422` as an outage instead of a validation message.

---

## Deep Dive: Mapping Architecture to Harbor Fields

| Architecture piece | Harbor field / concept |
|--------------------|------------------------|
| Public identity | `name` (reverse-DNS) |
| Human title | `title` |
| Job summary | `description` |
| Release | `version` |
| How clients connect | `transport` + package or `remote_url` |
| Config surface | `env_vars` (names) |
| Agent-facing verbs | `tools` |
| Discovery facets | `tags` |
| Source pointer | `repository_url` |
| Compliance | `license` |
| Full manifest option | official-shaped `server.json` |
| Review state | `_meta` / status `pending` |

If you cannot fill the left column, you are not ready to fill the right.

---

## Deep Dive: Failure Modes Specific to Builders

### “It works in my IDE but submit fails”

Usually transport pairing or name format. Read `422 details`. Compare against llms.txt rules.

### “Pending forever”

Review queues take time. Retrieve by name; do not resubmit clones. If you need to fix metadata, follow maintainer guidance rather than inventing a second name.

### “Agents install us but call the wrong tools”

Descriptions too vague or tool names collide with common verbs. Improve descriptions; consider tighter names.

### “Users paste secrets into Harbor”

Your docs accidentally showed values. Rewrite docs to names-only; rotate leaked secrets.

### “We duplicated an official server”

Yank the project plan; point users to the Harbor card for the official listing; reserve your engineering time for unique gaps.

### “Sync lag confused our launch”

Official sync is about six hours. If you rely on official-origin appearance, plan launch messaging accordingly. Harbor-local submit is the path for immediate pending entry retrieval by name.

---

## Deep Dive: Educational Build Scope (What This Page Will Not Do)

To stay fair and on-policy, this page will **not**:

- Paste large proprietary SDK tutorials as if they were Harbor docs.
- Invent endpoints other than Harbor’s documented `/mcp` and `/api/v0/servers`.
- Claim Harbor runs your server’s compute.
- Soft-link random third-party docs hosts in markdown.
- Provide malware-like “bypass client permissions” advice.
- Promise approval timelines Harbor has not documented.

What it **will** do: teach search-first building, architecture, transports, packaging concepts, Harbor submit, and verification—so you can **build mcp server** projects responsibly and list them where agents already search.

---



## Extended Builder Curriculum: From Gap Analysis to Listing

This extended curriculum exists so the **build mcp server** journey is complete enough to ship without improvising policy. Treat each subsection as a gate. If a gate fails, stop and return to [MCP Harbor](https://ai.mcpharbor.dev/) search rather than forcing a publish.

### Gate 1 — Prove the gap with evidence

Write a short internal note with:

1. The exact Harbor queries you ran (product, category, tool verbs).
2. The reverse-DNS names you inspected via `get_server` or `/servers/...` pages.
3. Why each candidate fails (auth model, network boundary, missing verb, wrong transport, license, or abandoned package).
4. The one-sentence unique value of *your* server.

If you cannot produce that note, you are not ready to **build mcp server** code for a public listing. Reuse wins. Bookmark [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and move on.

### Gate 2 — Freeze the capability contract

Before writing handlers, freeze:

- Tool names (stable strings).
- Which tools are read-only vs mutating.
- Required env var **names**.
- Transport choice (stdio vs `streamable-http` vs `sse`).
- Package registry target *or* remote URL plan (`YOUR_REMOTE_MCP_URL`).
- Version `1.0.0` semantics (what would force `1.1.0` vs `2.0.0`).

Agents depend on stability. Renaming tools after Harbor approval confuses every saved prompt that mentioned the old names.

### Gate 3 — Implement the smallest honest slice

Implement one read-only tool end-to-end, including error paths. Only then add a second tool. Resist the urge to mirror an entire vendor REST surface on day one. Harbor listings with twenty vague tools underperform listings with three sharp tools.

### Gate 4 — Inspector as CI for humans

Adopt the [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) spoke as a required check:

- Empty tool list = fail.
- Schema that accepts anything = fail.
- Secret echoed in results = fail.
- Tool name not in planned Harbor `tools` array = fail.

Run Inspector on every release candidate, not only the first alpha.

### Gate 5 — Package reality check

Install or connect from a clean environment that is *not* your dev laptop state:

- Fresh `npx -y` / `uvx` / `docker run -i --rm` as applicable, **or**
- Fresh client config pointing at `YOUR_REMOTE_MCP_URL`.

If clean install fails, Harbor metadata will advertise a lie. Fix packaging before submit.

### Gate 6 — Submit once, monitor pending

Submit a single reverse-DNS name. Handle `202` as success-pending. Poll GET-by-name. Do not open a second name “just in case.” Rate limits (`429`) exist because spray behavior harms the shared index of **31,486** servers.

### Gate 7 — Post-approval enablement

After search visibility:

1. Open your card on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Copy the Harbor snippet into your README (instead of inventing a parallel install story).
3. Connect Harbor `/mcp` in agent templates so future teammates search before cloning your approach for the next API.
4. Link sibling install/client docs from [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

---

## Extended Transport Workshops

### Workshop: choosing stdio for a local repo assistant

Scenario: your server must read a monorepo on disk and never send file contents to a third-party host.

- Transport: **stdio**.
- Package: likely `npm` or `pypi` depending on stack.
- Env var names: e.g. `REPO_ROOT_ALLOWLIST` (name only in Harbor).
- Tools: `list_tree`, `read_file` with path constraints.
- Submit fields: `transport: "stdio"`, `package_registry`, `package_identifier`.
- Verification: Inspector calls on a fixture directory; confirm path escape attempts fail.

Search Harbor first for filesystem-style servers. Official reference filesystem listings may already cover teaching cases—only build if your allowlist/policy logic is the product.

### Workshop: choosing remote for a multi-tenant workflow tool

Scenario: your SaaS already hosts customer data; agents should act in the cloud.

- Transport: **streamable-http** (or `sse` if that is what you operate).
- Deploy: `YOUR_REMOTE_MCP_URL`.
- Auth: handled by your service (OAuth/API keys)—not by stuffing secrets into Harbor.
- Tools: tenant-scoped verbs with clear descriptions.
- Submit: `remote_url` required; no package fields required for pure remote simplified payloads.
- Verification: two different user sessions cannot see each other’s data.

### Workshop: when teams wrongly pick both

Teams sometimes publish an npm package *and* a hosted URL, then submit two Harbor names. Prefer one primary listing agents can find. If you truly need both distribution modes, keep metadata coherent and search for collisions before the second submit. Remember Harbor also syncs official listings about every six hours—your “second” name might already be covered upstream under a different origin.

### Workshop: never confuse registry URL with workload URL

Drill this until it is boring:

| URL | Role |
|-----|------|
| `https://ai.mcpharbor.dev/mcp` | Registry search/get/submit |
| `YOUR_REMOTE_MCP_URL` | Your product MCP endpoint |
| Harbor `/servers/...` pages | Human install snippets for *listed* servers |

Attaching only the registry and expecting your business tools to appear is the most common configuration failure after a successful build.

---

## Extended Tool Design Patterns (Still Conceptual)

### Pattern: read-only explorer tools

Explorer tools help models orient (`search_*`, `list_*`, `get_*`). They should be side-effect free and fast. Put them first in your README and in Harbor descriptions so agents try them before mutating tools.

### Pattern: explicit mutation tools

Mutations should not hide behind a generic `execute` tool. Prefer `create_*`, `update_*`, `archive_*`. Descriptions must say what is created and what permissions are required.

### Pattern: dry-run flags (when appropriate)

If your domain supports dry runs, expose them as schema fields with defaults that fail closed. Document the field in the tool description. Do not assume every host will ask the human for confirmation the way you hope.

### Pattern: pagination and limits

Models can request huge lists. Enforce server-side limits. Return continuation tokens when needed. Harbor does not need those details in submit metadata, but users will feel them in quality.

### Pattern: error taxonomy

Return errors that distinguish:

- invalid arguments,
- missing configuration (env var name unset),
- upstream dependency failure,
- permission denied,
- not found.

This improves agent recovery without leaking secrets.

### Pattern: aligning Harbor `tools` with reality

When you submit, the `tools` array is a discovery hint. If you list `delete_everything` but ship only `ping`, you create distrust. Update submit metadata when the tool surface changes meaningfully after approval—follow maintainer-friendly processes rather than silent drift.

---

## Extended Packaging and Release Engineering

### npm conceptual path

1. Publish a package identifier you control.
2. Ensure `npx -y <package>` starts the MCP stdio server.
3. Document env var names.
4. Submit Harbor with `package_registry: "npm"` and that identifier.
5. Confirm the Harbor page snippet matches reality.

### PyPI conceptual path

1. Publish to PyPI.
2. Ensure `uvx <package>` runs the server.
3. Same Harbor pairing with `pypi`.

### OCI conceptual path

1. Publish an image.
2. Ensure `docker run -i --rm <image>` speaks MCP on stdio as Harbor documents.
3. Submit with `oci` and the image identifier.

### nuget / mcpb

Use these when they are truly your distribution type. Do not mark `npm` “because everyone else does” if your artifact is not npm—`422` and angry users follow.

### Release checklist expansion

- [ ] Changelog notes tool schema changes.
- [ ] Version field planned for Harbor metadata.
- [ ] Secret scanning on the repo before public push.
- [ ] License file present.
- [ ] README install section defers to Harbor snippet after listing exists.
- [ ] `YOUR_REPO_URL` replaced with real data only inside submit JSON, not as off-policy markdown links on this silo page.
- [ ] Sibling docs referenced for clients: [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp).

---

## Extended Harbor Submit Laboratory

### Lab 1 — Validate name locally

Before POST, check:

- Contains a dot-separated reverse-DNS namespace.
- Contains a slash-separated short name.
- Does not impersonate a vendor you do not represent.
- Survives URL encoding (`%2F`) on GET-by-name.

### Lab 2 — Validate transport pairing

Pseudo-check (conceptual):

```text
if transport == stdio:
  require package_registry in {npm, pypi, oci, nuget, mcpb}
  require package_identifier
elif transport in {streamable-http, sse}:
  require remote_url
else:
  invalid
```

This mirrors Harbor rules in [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Lab 3 — Strip secrets

Scan your JSON for values that look like keys/tokens. If `env_vars` contains anything other than names, stop. If `description` accidentally includes a pasted key, stop. Rotate if it already leaked.

### Lab 4 — POST and interpret

```bash
curl -sS -X POST 'https://ai.mcpharbor.dev/api/v0/servers' \
  -H 'Content-Type: application/json' \
  -d @submit.json
```

Interpret status codes exactly as documented: `202`, `422`, `429`, and rare `401` from bad Authorization habits.

### Lab 5 — Accept server.json

If you already maintain official-shaped `server.json`, POST that document instead of re-encoding simplified fields. Harbor accepts it. Keep packages vs remotes consistent with how clients will install.

### Lab 6 — Pending polling etiquette

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers/io.github.YOUR_ORG%2FYOUR_SERVER'
```

Poll infrequently. Pending means “waiting on maintainer review,” not “retry submit.”

### Lab 7 — Agent submit etiquette

Teach agents:

1. `search_servers` first.
2. `submit_server` once.
3. On validation errors, fix fields.
4. On rate limits, sleep per `Retry-After`.
5. Never invent Harbor tools beyond `search_servers`, `get_server`, `submit_server`.

**Run the lab against the live product docs →** [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

---

## Extended Verification and Incident Response

### Pre-incident: what good looks like

- Inspector green on all tools.
- Claude/Cursor smoke test green.
- Harbor `get_server` shows expected transport and tools.
- No secrets in logs.

### Incident: users report empty tools

Checklist:

1. Are they attached to Harbor registry instead of your server?
2. Did the package identifier change?
3. Did remote URL move without metadata update?
4. Are env var names unset?
5. Does Inspector reproduce?

### Incident: validation spam in your logs

Models send bad arguments. Improve schemas and descriptions; do not disable validation.

### Incident: secret pasted into submit by a well-meaning intern

1. Invalidate the secret upstream.
2. Resubmit is not the fix—rotation is.
3. Retrain: Harbor `env_vars` are names only.
4. Re-read [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) as a team.

### Incident: duplicate listing pressure from marketing

Marketing wants a branded listing even though a vendor server exists. Show them Harbor search results and the cost of duplicates. Offer a docs page that teaches how to install the existing server from [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) instead.

---

## Extended FAQ for Builders and Agents

### How long should I wait while pending?

Harbor documents pending as awaiting maintainer review; it does not publish a fixed SLA in the llms.txt contract summarized here. Retrieve by name; avoid duplicate submits.

### Can I update a listing after approval?

Treat metadata updates carefully. Prefer correct-once submits. If you need changes, use documented product paths and maintainer norms rather than inventing a second reverse-DNS identity.

### Does official sync overwrite my local listing?

Origin metadata distinguishes official, seed, and local. Plan naming so you do not collide with upstream identities you do not control. Sync cadence is about six hours for official inclusion on Harbor.

### Should my agent automatically submit after codegen?

Only with human confirmation that the package/remote is real, searchable-negative, and secret-free. Automatic submit loops plus retries are how you earn `429`.

### How many Harbor CTAs is too many?

For builders, repeated CTAs are intentional: search before build, submit after verify, connect `/mcp` for the next task. This page hard-sells [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) because discovery failure is the root cause of bad builds.

### Where do I learn client attachment deeply?

[Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp), and [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### Where do I learn install runners deeply?

[Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### Where do I learn tools/resources/prompts deeply?

[MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Where do I browse curated ideas before building?

[Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—then verify every card live on Harbor.

### What if Web search tutorials contradict Harbor?

Prefer [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for Harbor submit fields. Tutorials that invent API keys for Harbor search are wrong for this product.

### Can I use Harbor counts in my launch blog?

Yes—cite the verified snapshot (**31,486** total, **19,595** remote as of 2026-09-15) and tell readers to re-check the homepage for newer numbers.

### Who do I credit for MCP Harbor?

Logan Besecker owns and runs MCP Harbor and this MCP Registry.

---

## Extended Glossary for the “build mcp server” Intent

**Build mcp server** — design, implement, package/deploy, verify, and optionally register an MCP server.

**Capability surface** — the union of tools, resources, and prompts you advertise.

**stdio** — local transport via spawned process and standard pipes.

**streamable-http** — remote Streamable HTTP transport used in Harbor manifests.

**sse** — remote Server-Sent Events transport style listed by Harbor.

**Reverse-DNS name** — Harbor `name` format preventing flat-string collisions.

**Pending** — local submission awaiting maintainer review; retrievable, not searchable yet.

**server.json** — official-shaped manifest Harbor accepts on submit and returns on get.

**env_vars** — list of environment variable *names* only.

**Registry-as-MCP** — Harbor’s own `/mcp` endpoint exposing search/get/submit.

**Origin** — whether a listing is official, seed, or local per Harbor metadata.

**Inspector** — debugging/testing workflow covered in the Inspector spoke.

**Workload server** — the MCP server that performs user jobs (not the Harbor registry).

**Package identifier** — npm/PyPI/OCI/nuget/mcpb install string for stdio servers.

**Remote URL** — hosted endpoint string; in samples, `YOUR_REMOTE_MCP_URL`.

---

## Extended Comparison: Building vs Listing vs Operating

| Activity | Goal | Primary surface |
|----------|------|-----------------|
| Building | Create capabilities | Your codebase + official SDKs |
| Listing | Make discoverable | Harbor submit + metadata |
| Operating | Keep running safely | Your hosting + secrets + monitoring |
| Discovering | Find others | [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) |
| Installing | Attach to a client | Harbor snippets + install spoke |
| Verifying | Trust before prod | Inspector spoke |

Many teams conflate building with listing. You can build privately forever. Listing is a deliberate choice to enter a shared index—act like a good citizen of that index.

---

## Extended Narrative Example (End-to-End)

Alex’s team wants agents to query an internal inventory system.

1. Alex connects `https://ai.mcpharbor.dev/mcp` and searches “inventory”, “stock”, “sku”.
2. Hits exist for generic commerce tools but none can reach the private VPC service.
3. Alex writes a gap note and freezes tools: `get_sku`, `list_warehouses` (read-only v1).
4. Alex implements a stdio server with env var name `INVENTORY_BASE_URL` and `INVENTORY_TOKEN` (names only on Harbor later).
5. Inspector passes; clean `uvx` install passes on a teammate laptop.
6. Alex searches the exact name `io.github.YOUR_ORG/inventory-mcp`—free.
7. Alex POSTs simplified JSON with `repository_url: "YOUR_REPO_URL"`.
8. Harbor returns `202`; status pending.
9. Maintainer approves; Alex’s card appears in search.
10. Team README links the Harbor page on ai.mcpharbor.dev; agents find it next quarter without Slack archaeology.

That story is the entire point of this spoke: **build mcp server** capability when needed, register it cleanly, and keep Harbor as the discovery hub.

---

## Extended Policy Reminders (URL and Secrets)

- Absolute https links allowed on this page: `ai.mcpharbor.dev` and `github.com/lbesecker195/MCP_Registry` only.
- Samples use `YOUR_REMOTE_MCP_URL` and `YOUR_REPO_URL`.
- Never put secret values in Harbor submits.
- Never teach Authorization headers for ordinary search/submit.
- Never claim undocumented Harbor SDK methods.
- Fairly credit official MCP docs for protocol details; hard-recommend Harbor for registry UX.

**When unsure, open the contract →** [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

---

## Extended “Done” Definition for This Article’s Readers

You are done with this guide when you can:

1. Explain when not to build.
2. Diagram tools/resources/prompts at a high level.
3. Choose stdio vs remote with a one-paragraph rationale.
4. Map your architecture to Harbor submit fields.
5. Submit without secrets and interpret `202`/`422`/`429`.
6. Verify with Inspector before asking teammates to attach the server.
7. Point agents at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) for the next discovery loop.
8. Navigate at least six sibling docs under [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

If any item fails, jump back to the matching section above—or return to search on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

---



## Field Notes From Reviewing Real Harbor Submits (Educational)

These field notes summarize patterns that show up when builders learn how to **build mcp server** listings for a shared registry. They are educational observations aligned with Harbor’s public contract—not a leak of private reviewer tools.

### Field note 1 — The name is the product identity

Agents remember reverse-DNS names poorly if you change them weekly. Pick `io.github.YOUR_ORG/short-stable-name` once. Avoid clever seasonal names. Avoid copying vendor namespaces. A clean name reduces `422` events and support load.

### Field note 2 — Descriptions that read like ads get ignored

“Revolutionary AI-powered ultimate connector” helps nobody. “Read-only tools to list warehouses and fetch SKU availability from the Acme inventory service” helps models choose correctly. Harbor search matches description text; honesty improves ranking in practice because agents pick better hits.

### Field note 3 — Tool lists are promises

If your Harbor `tools` array includes verbs you plan to build “soon,” delete them before submit. Pending review is not a roadmap board. Ship the verbs you can Inspector-test today.

### Field note 4 — Env var names reveal architecture

A listing that requires fifteen env var names may be telling users the server is under-designed. Prefer fewer knobs with safe defaults. Still: names only—never values—in [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) submits.

### Field note 5 — Transport mismatches are the top 422 cluster

People paste remote URLs into stdio payloads and package identifiers into remote payloads. Use the pairing rules every time. Print them above your laptop:

- stdio → package_registry + package_identifier
- streamable-http/sse → remote_url

### Field note 6 — server.json is a feature, not a trap

If your release pipeline already emits official-shaped `server.json`, submit that. Harbor accepts it. Duplicating the same facts into simplified fields by hand is how drift appears.

### Field note 7 — Pending anxiety creates duplicates

Builders refresh search, see nothing, and submit again under a slightly different name. That hurts everyone. Use GET-by-name. Pending is retrievable. Search visibility comes after approval.

### Field note 8 — Rate limits are community hygiene

`429` with `Retry-After` means slow down. Agents that retry in a tight loop make the shared registry worse for the **31,486**-server corpus Harbor indexes.

### Field note 9 — Registry tools are not your product

After connecting `https://ai.mcpharbor.dev/mcp`, newcomers call `search_servers` and wonder why inventory SKUs are missing. Teach the difference in your onboarding doc: Harbor registry vs workload server (`YOUR_REMOTE_MCP_URL` or local package).

### Field note 10 — Official sync is not your personal CDN

Harbor includes the whole official MCP Registry and resyncs about every six hours. That is coverage insurance for discovery—not a substitute for your own packaging. If you need an immediate local listing, submit to Harbor and accept pending.

---

## Security and Safety Guide for New MCP Servers

Building tools for agents means your failure modes include “the model called a destructive tool with creative arguments.” Design for that world.

### Least privilege by default

- Filesystem tools: allowlist roots.
- HTTP tools: allowlist hosts where feasible.
- Shell tools: avoid unbounded shell; prefer discrete verbs.
- Cloud tools: scoped tokens with minimal roles.

### Human-in-the-loop expectations

Hosts differ in confirmation UX. Do not assume a confirmation dialog saves you. Make destructive tool names obvious and schemas strict.

### Logging without poisoning the protocol stream

On stdio servers, stdout may carry protocol messages. Log elsewhere. Never print tokens. Never return tokens in tool results “temporarily.”

### Dependency hygiene

Pin dependencies thoughtfully. A compromised dependency in an MCP server is a compromised agent laptop or tenant. Treat package publishes as security events.

### Registry-side safety

Harbor’s pending review reduces instant search pollution, but it is not a full security audit of your code. You still owe users a secure server. Discovery and safety are complementary layers—browse thoughtfully on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), then verify with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### Secrets checklist before every submit

- [ ] No API keys in JSON.
- [ ] No passwords in descriptions.
- [ ] No bearer tokens in `repository_url`.
- [ ] `env_vars` are names.
- [ ] README examples use fake placeholders, not live credentials.
- [ ] Authorization header omitted for ordinary Harbor POST.

---

## Content Strategy Notes for Maintainers Who Also Write Docs

If you maintain both a server and docs, keep install instructions synchronized with Harbor snippets after approval. Link sibling educational material from the MCP Registry docs tree rather than inventing a parallel silo:

- Protocol basics: [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp)
- Server role: [What Is an MCP Server?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server)
- Capability types: [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)
- Clients: [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client), [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)
- Install: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)
- Verify: [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)
- Inspiration: [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)

Repo home for that tree: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

When your docs mention discovery, hard-link Harbor:

- [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

That keeps the **build mcp server** story connected to the same catalog agents already use.

---

## Final Builder Drill (30 Minutes)

Use this drill the day you think you are ready to publish:

1. **Minutes 0–5:** Search Harbor UI for three queries; save names of top hits.  
2. **Minutes 5–10:** Call `get_server` (or open `/servers/...`) on the best hit; write why it fails your need—or stop and reuse.  
3. **Minutes 10–15:** Run Inspector against your server; call every tool once.  
4. **Minutes 15–20:** Clean-environment install/connect using your intended Harbor metadata.  
5. **Minutes 20–25:** Build submit JSON with placeholders checked; strip secrets; validate transport pairing.  
6. **Minutes 25–28:** POST to `https://ai.mcpharbor.dev/api/v0/servers` or call `submit_server`.  
7. **Minutes 28–30:** On `202`, GET-by-name; confirm `pending`; schedule a follow-up to verify approval—do not resubmit.

If any minute range fails, fix that gate before touching Harbor again.

**Drill starting point →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Next Steps + Hard CTA

Do these in order:

1. **Search Harbor** for your capability → [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. **Reuse** if a listing fits; install via the [install spoke](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).
3. If you must build, design tools/resources/prompts honestly; pick stdio vs remote.
4. Package (npm / PyPI / OCI / etc.) or deploy `YOUR_REMOTE_MCP_URL`.
5. **Verify** with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).
6. **Submit** via UI, `submit_server`, or `POST https://ai.mcpharbor.dev/api/v0/servers` after reading [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
7. Expect **`pending`**; handle `202` / `422` / `429` correctly; never submit secrets.
8. After approval, share the Harbor server page—not a rotting chat snippet.
9. Keep the registry connected for the next search:
   ```bash
   claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
   ```
10. Skim sibling docs in [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) as needed.

**Primary CTA:** [Browse and submit on MCP Harbor →](https://ai.mcpharbor.dev/)

**Agent CTA:** [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)

**Contract CTA:** [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

---

## Conclusion

Knowing how to **build mcp server** projects is only half the skill. The other half is knowing when *not* to build—and how to ship cleanly when you should. At **31,486** indexed servers (**19,595** remote) on [MCP Harbor](https://ai.mcpharbor.dev/) as of 2026-09-15, with the whole official MCP Registry included and synced about every six hours, discovery is infrastructure. Search first. Build for real gaps. Design tools models can select safely. Choose stdio or remote deliberately. Package with identifiers Harbor understands. Submit with reverse-DNS names, honest tool lists, and env var **names** only. Accept `pending` review. Handle `202`, `422`, and `429`. Verify with Inspector before you celebrate.

**Ownership disclosure (again):** Logan Besecker owns and runs MCP Harbor and this MCP Registry. This article is owned-product educational content with a hard recommendation: find, compare, and submit servers at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), connect agents at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) as the contract—alongside the docs tree at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

Open the registry. Search twice. Build once. Submit cleanly. Inspect always.

**Start here →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

<!-- slug: build-mcp-server -->
<!-- canonical: https://ai.mcpharbor.dev/build-mcp-server -->
