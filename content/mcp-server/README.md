---
title: "What Is an MCP Server? How MCP Servers Work"
description: "Learn what an MCP server is, how MCP servers work with AI agents, local vs remote options, manifests, and how to find and install servers with MCP Harbor."
date: 2026-09-15
---

# What Is an MCP Server? How MCP Servers Work

> 📖 **Read the comprehensive 20,000+ word technical guide:** [MCP Server Development - Best Practices and Architecture](https://ai.mcpharbor.dev/servers) covers in-depth server design patterns, security implementation, performance optimization, testing strategies, deployment, monitoring, and advanced architectural considerations for production-ready MCP servers.

If you have spent any time with modern AI coding agents or chat assistants that can *do* things—not just talk about them—you have probably heard the phrase **mcp server**. An MCP server is the practical unit that turns a large language model from a conversationalist into a tool-using collaborator. It exposes capabilities (tools, resources, and prompts) over the Model Context Protocol so clients like Claude, Cursor, and other agent hosts can call them safely and consistently.

This guide is the deep, publish-ready overview of what an MCP server is, how MCP servers are structured, how local (stdio) packages differ from remote HTTP endpoints, what manifests communicate at a high level, and how to discover trustworthy servers without spelunking random GitHub repos. Along the way you will see how [MCP Harbor](https://ai.mcpharbor.dev/)—owned by Logan Besecker—indexes tens of thousands of entries (including official registry data, kept in sync), and how agents can search and submit through Harbor’s MCP surface with no account required.

**Start here:** open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), skim the agent-facing catalog at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and fetch the machine-readable map at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open registry mirror lives at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry). If you need the protocol foundations first, read the sibling guide [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). If you already know you want to install something today, jump to [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

This article is not a from-scratch tutorial on writing your first server in TypeScript or Python. Building and submitting a server has its own spoke: [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server). Here the focus is roles, packaging models, discovery, and how MCP Harbor fits the workflow for humans and agents alike.

---

## What Is an MCP Server? A Clear Definition

An **mcp server** is a process or network service that implements the Model Context Protocol on the *server* side of the client–server relationship. The MCP *client* lives inside an AI host application (Claude Desktop, Claude Code, Cursor, custom agents, and others). The MCP *server* is the peer that advertises capabilities and executes requests.

In plain language: the model decides it needs a capability (“list files in this repo,” “query this database,” “fetch this ticket,” “run this search”). The client translates that intent into a protocol message. The MCP server performs the work and returns a structured result. The model then continues reasoning with that result in context.

That separation matters. Without a shared protocol, every integration is a one-off plugin API. With MCP, one server can speak to many clients, and one client can attach many servers. The **mcp server** becomes a reusable capability unit—closer to a microservice for AI tools than to a chat prompt.

### What an MCP server is not

Clarifying boundaries helps SEO readers and practitioners alike:

- **Not the model.** The language model still plans and writes; the server executes declared tools and serves declared resources.
- **Not the host app.** Cursor, Claude, or your custom agent runtime is the *client* host. Your filesystem MCP package or remote API bridge is the *server*.
- **Not a full agent framework.** Frameworks may *host* MCP clients or servers; the server itself is the capability endpoint.
- **Not automatically trusted.** Publishing something as an MCP server does not make it safe. Discovery, manifests, permissions, and review still matter—which is why curated indexes like [MCP Harbor](https://ai.mcpharbor.dev/) exist.

### Why the keyword “mcp server” dominates search

People search for **mcp server** and **mcp servers** because that is the installable artifact. Tutorials say “add this MCP server to Cursor.” Package READMEs say “run this as an MCP server with npx.” Registry entries describe servers, not abstract protocol theory. Understanding the server role is therefore the practical on-ramp for most builders and power users.

For the complementary client perspective, see [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client). For the three capability types servers typically expose, see [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### The three capability surfaces in one sentence

Most MCP servers expose some mix of:

1. **Tools** — callable actions with schemas (the workhorses).
2. **Resources** — addressable data the client can read into context.
3. **Prompts** — reusable prompt templates the host can offer to users or agents.

A single **mcp server** might be tool-heavy (a GitHub bridge), resource-heavy (a documentation corpus), or balanced (a project workspace helper). The protocol keeps those surfaces consistent so clients do not reinvent discovery for each vendor.

### Who owns the problem MCP servers solve

Before MCP, connector ecosystems fragmented by product. After MCP, the industry has a common language for “here are the tools this process offers.” Logan Besecker’s **MCP Harbor** product line leans into that reality: rather than asking every agent to scrape the open web for install recipes, Harbor presents a searchable catalog—**31,486** indexed servers at the time of writing, including **19,595** remote entries—with the **official registry included and synced**. Agents can search and submit through Harbor’s MCP endpoint **with no account**.

That product framing is intentional. Protocol adoption only compounds when discovery is as standard as the wire format. Browse the live index at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), connect via [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) in your agent’s reading list.

---

## How MCP Servers Fit the Model Context Protocol

To understand how MCP servers work, picture a short handshake and a long conversation.

1. The host starts or connects to an **mcp server** (local child process or remote URL).
2. Client and server negotiate protocol version and capabilities.
3. The client asks the server to list tools, resources, and/or prompts.
4. The model (via the host) selects a tool call or resource read when useful.
5. The server executes and returns results; the loop continues until the task ends.

Nothing mystical happens. The power is in standardization: schemas for tools, URIs for resources, and predictable error handling. When you attach five MCP servers to Claude or Cursor, the host merges their capability lists into one agent workspace. That composition model is why “add another MCP server” became a product feature instead of a custom engineering project.

### Lifecycle mental model

Think of an MCP server’s life in four phases:

- **Launch / connect** — process spawn (stdio) or HTTP session (remote).
- **Initialize** — capability negotiation.
- **Serve** — list and invoke tools; list and read resources; serve prompts.
- **Shutdown** — clean exit when the host disconnects or the user disables the server.

Local servers are typically short-lived per host session. Remote servers may be long-lived multi-tenant endpoints. Both are still “MCP servers” from the client’s perspective; only the transport and trust boundary change.

### Why roles stay strict

A frequent confusion: people say “my agent is an MCP server.” Usually they mean the agent *uses* MCP servers, or that a component of their stack *exposes* MCP. Keep the vocabulary crisp:

| Role | Job |
|------|-----|
| Model | Reason and propose actions |
| Host / client | Speak MCP, manage UX and permissions |
| MCP server | Advertise and execute capabilities |
| Registry / Harbor | Help humans and agents find servers |

MCP Harbor sits in the last row—and also exposes itself as an MCP surface so agents can search without leaving the protocol. That dual nature (catalog *and* MCP endpoint) is why the product includes both the human site and [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## Anatomy of an MCP Server

Strip away branding and language SDKs, and every MCP server shares a recognizable anatomy. Understanding that anatomy makes installation, debugging, and evaluation far easier—even if you never write a line of server code yourself.

### 1. Transport boundary

Something must carry JSON-RPC-style MCP messages between client and server. Commonly:

- **stdio** for local package-style servers (stdin/stdout pipes).
- **HTTP / SSE-style remote transports** for hosted endpoints.

The transport is not the business logic; it is the wire. Still, transport choice drives install UX, networking, secrets handling, and multi-user sharing. We expand on local vs remote in the next major section.

### 2. Protocol handler

Inside the process (or behind the remote gateway) sits the handler that understands MCP methods: initialize, list tools, call tool, list resources, read resource, and so on. Official and community SDKs implement this layer so authors focus on capability logic.

### 3. Capability registry (in-process)

The server maintains an internal registry of what it offers: tool names and JSON schemas, resource templates or static URIs, prompt definitions. When the client asks “what can you do?”, this registry answers. Quality servers keep descriptions precise—models choose tools based on names and docs as much as on schemas.

### 4. Execution layer

Tools eventually call real systems: filesystems, APIs, databases, browsers, cloud CLIs. This layer is where security and reliability live. A thin wrapper around a dangerous shell is still a dangerous server. A well-scoped GitHub tool that only touches one org is a different risk profile.

### 5. Configuration and secrets

Almost every non-trivial **mcp server** needs configuration: API tokens, base URLs, allowed directories, feature flags. Local servers often read environment variables set by the host config file. Remote servers often use OAuth, API keys in headers, or session cookies. Manifests and install docs should make required config obvious—Harbor’s catalog experience emphasizes discoverability of that metadata where available.

### 6. Observability and errors

Production-minded servers return structured errors, log carefully (without leaking secrets to stdout when stdout *is* the protocol), and behave predictably under timeouts. If you are evaluating a server before installing it, prefer projects that document failure modes and that you can probe with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### Anatomy walkthrough: a filesystem-style server

Imagine a local filesystem MCP server:

- Transport: stdio via `npx` or a binary.
- Tools: `read_file`, `write_file`, `list_directory` with path schemas.
- Resources: optional `file://` style listings.
- Config: root directory allowlist.
- Execution: OS file APIs constrained by the allowlist.

That shape teaches the pattern: **declare → authorize → execute → return**. Every category of MCP server—browser, database, CRM, docs search—follows the same skeleton with different execution backends.

### Anatomy walkthrough: a remote SaaS bridge

Now imagine a remote **mcp server** for a SaaS product:

- Transport: HTTPS endpoint your client connects to.
- Tools: `create_ticket`, `search_customers`, `list_invoices`.
- Auth: per-user OAuth or workspace API key.
- Execution: vendor REST/GraphQL behind the MCP facade.
- Multi-tenancy: the remote process serves many clients; isolation is the vendor’s job.

Remotes trade local install friction for network trust and availability concerns. Harbor’s remote count (**19,595**) reflects how popular this model has become for teams that want zero local runtime management.

### What “good anatomy” looks like in practice

When you evaluate MCP servers in [MCP Harbor](https://ai.mcpharbor.dev/), look for:

- Clear tool naming and descriptions (models depend on them).
- Explicit config requirements.
- Sensible default scopes.
- Active maintenance signals.
- Preferential inclusion of official or well-known publishers when available.
- Alignment with the official registry when entries are synced through Harbor’s pipeline.

Harbor’s design goal is to make that evaluation faster than browsing unstructured lists. Use the site, the [MCP endpoint](https://ai.mcpharbor.dev/mcp), and [llms.txt](https://ai.mcpharbor.dev/llms.txt) together: humans browse, agents query.

---

## Local stdio MCP Servers vs Remote MCP Servers

The most important practical split in the MCP server ecosystem is **how the client reaches the server**.

### Local stdio MCP servers (packages you run)

A local **mcp server** typically ships as:

- an npm package invoked with `npx`,
- a Python package invoked with `uvx` or `pip`,
- a Docker image,
- or a standalone binary.

The host spawns the process and speaks MCP over stdin/stdout. Your machine supplies CPU, filesystem, and environment variables. This model excels when:

- you need local file, git, or OS access;
- you want offline or VPC-local tooling;
- secrets should stay in your environment;
- you are iterating on a server you are developing yourself.

Tradeoffs include dependency management, OS differences, and the fact that every developer laptop becomes a runtime. For step-by-step install patterns, use the dedicated spoke [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)—this article only orients you to the choices.

### Remote MCP servers (URLs you connect to)

A remote **mcp server** is reached over the network. The client does not spawn your business logic; it connects to an endpoint that already speaks MCP (or a gateway that does). Remotes shine when:

- a vendor hosts the integration for you;
- teams share one managed capability plane;
- heavy dependencies should not land on every laptop;
- compliance prefers centralized audit logs.

Tradeoffs include network dependency, data leaving the machine, auth complexity, and the need to trust the operator. Harbor tracks remotes as first-class citizens—**19,595** remote entries within the broader **31,486** index—so you can filter and compare without guessing which GitHub README is current.

### Packages vs remotes: decision guide

| Question | Prefer local package | Prefer remote |
|----------|----------------------|---------------|
| Needs local files/OS? | Yes | Rarely |
| Want zero local deps? | No | Yes |
| Multi-user shared state? | Harder | Natural fit |
| Sensitive data must not leave device? | Stronger default | Needs careful policy |
| Vendor-maintained SaaS API? | Possible | Often better |
| CI / headless agents? | Works | Often simpler ops |

Many real setups mix both: a local filesystem server plus a remote issue tracker server plus a remote search server. That composition is the point of MCP.

### Security differences you should not ignore

Local servers inherit your user permissions. If a tool can write arbitrary paths, treat it like installing software with shell access—because it effectively is. Use allowlists, least-privilege tokens, and Inspector testing.

Remote servers inherit *operator* risk plus *transport* risk. Prefer TLS, understand token scopes, and review what data tools send. Harbor helps with discovery and metadata, but you still own the trust decision for each install.

### Performance and UX differences

Local stdio servers often feel snappy for filesystem and local DB tools. Remotes add latency but can be globally available and horizontally scaled. Hosts differ in how they surface connection failures; always verify a new server with a trivial tool call after install.

### How Harbor presents both

On [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) you will find both package-style and remote MCP servers. The official registry is included and kept in sync, so you are not choosing between “Harbor-only” and “official-only” worlds—you get a unified discovery layer. Agents can search without creating an account via [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) handy for automated context loading.

---

## Manifests and server.json at a High Level

When people talk about publishing or indexing an **mcp server**, they eventually talk about manifests—often a `server.json` or equivalent metadata document. This section stays high level on purpose. Exact schema fields evolve; what you need as a consumer is the *job* of the manifest.

### What a manifest is for

A manifest tells registries, installers, and humans:

- **identity** — name, publisher, description;
- **how to run or connect** — command package, Docker image, or remote URL pattern;
- **environment expectations** — required env vars, optional config;
- **capability hints** — categories, tags, maybe tool summaries;
- **versioning** — release identity so clients and catalogs can pin or update.

Without manifests, every catalog becomes a pile of READMEs. With manifests, automated sync—like Harbor including and syncing the official registry—becomes feasible at scale (**31,486** entries is not a manual spreadsheet).

### What manifests are not

A manifest is not a security proof. It is not a substitute for code review. It does not guarantee the remote endpoint will stay up. Treat it as structured packaging metadata—necessary for discovery, insufficient for blind trust.

### How clients use manifest-like config today

In practice, many hosts still consume a *host-specific* config snippet (JSON/YAML) that embeds the launch command or URL. Manifests feed registries; registries and docs feed those snippets. Harbor’s role is to shorten the path from “I need a server that does X” to “here is a credible entry and how it runs.”

### server.json in the publishing mental model

If you later publish your own server, you will care about authoring and validating manifest details. That workflow belongs in [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server). From the consumer angle relevant here:

1. Author builds server.
2. Author describes it with a manifest.
3. Entry lands in official and/or community indexes.
4. Harbor syncs and surfaces it for search.
5. You install via host config using the discovered run/connect instructions.

### High-level fields you will recognize

Across ecosystems you repeatedly see concepts like:

- **name / title / description** for search and UX;
- **packages** or **remotes** arrays describing distribution;
- **environment** variable declarations;
- **repository** links for source;
- **version** and changelog pointers.

Harbor’s indexing pipeline is built to respect that structured world rather than only free-text scraping. That is how official registry inclusion and sync stay meaningful.

### Manifests and agents

Agents benefit when catalogs expose stable identifiers and connection hints. That is part of why MCP Harbor invests in an MCP search/submit surface with **no account** friction: an agent can query Harbor as an **mcp server** (yes—Harbor itself is usable in the protocol) and then recommend or draft install config for other servers. Read [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for LLM-oriented guidance, and connect at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## Finding MCP Servers with MCP Harbor

Discovery is where most people actually spend time. The protocol can be perfect and still fail product-wise if nobody can find the right **mcp server**.

### The discovery problem

Search engines return blog posts. GitHub returns stars that may be outdated. Vendor docs assume you already know the product name. Teams need a registry-like experience that:

- includes official sources,
- stays synced,
- distinguishes local vs remote,
- is usable by humans *and* agents,
- does not force account walls for basic search/submit agent flows.

### What MCP Harbor is

**MCP Harbor** (Logan Besecker) is that discovery and registry experience:

- Browse and search at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
- Point agents at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).
- Load structured guidance from [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- Follow the open project at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Product facts that matter for buyers and builders:**

- **31,486** servers indexed.
- **19,595** of them remote.
- **Official registry included and synced.**
- **Agent MCP search and submit with no account.**

Those numbers are not vanity—they describe coverage. When you are choosing MCP servers for a real workflow, coverage plus sync beats a hand-curated list of twelve favorites (though curated picks still help—see [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)).

### Human workflow on Harbor

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search by task (“postgres”, “browser”, “github”, “docs”).
3. Distinguish package vs remote entries.
4. Open an entry; note config and publisher signals.
5. Copy install orientation into your host (Claude, Cursor, etc.).
6. Validate with a safe tool call or Inspector.

### Agent workflow on Harbor

1. Add Harbor’s MCP endpoint from [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) to your client.
2. Ask your agent to search for servers matching a job-to-be-done.
3. Optionally submit new entries through the same account-free agent flow when you publish.
4. Keep [llms.txt](https://ai.mcpharbor.dev/llms.txt) available so the agent understands Harbor’s conventions.

This “registry as MCP server” pattern is recursive in a useful way: you use an MCP server to find MCP servers.

### Harbor vs random lists

Random Awesome lists go stale. Harbor’s sync with the official registry plus broad indexing is designed for ongoing freshness. You should still evaluate each **mcp server** on permissions and maintenance—but you should not have to invent the catalog.

### CTA: make Harbor your default start

Before you accept the next Twitter tip to “just npx this package,” search it on [MCP Harbor](https://ai.mcpharbor.dev/). If you are an agent builder, wire [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) once and reuse it across projects. If you maintain docs for your team, link [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) in your internal AI playbook.

---

## Installing an MCP Server (Orientation, Not a Full How-To)

Installation deserves its own full guide because hosts differ: Claude Desktop config files, Claude Code workflows, Cursor MCP settings, custom clients, Docker sidecars, and remote URLs all have nuances. Use this section as a map, then follow [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### The universal install pattern

1. **Pick a server** in [MCP Harbor](https://ai.mcpharbor.dev/).
2. **Choose transport** — local package or remote URL.
3. **Prepare secrets** — API keys in env, never in chat logs.
4. **Register with the host** — add server block to client config or UI.
5. **Restart or reload** the host if required.
6. **Verify** — list tools; run a harmless call.
7. **Tighten scopes** — reduce directory roots and token permissions.

### Local package orientation

You will commonly see Node-based launches (`npx`), Python-based launches (`uvx`), or container launches (`docker run ...`). The host owns the child process. Your job is correct command, args, and env. When something fails, check stderr logging policies and whether the process crashed before initialize completed. [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) is the specialist tool for interactive debugging.

### Remote orientation

You will paste a URL and configure auth. Verify TLS, understand multi-tenant behavior, and confirm which workspace the remote acts upon. Remotes are still MCP servers; they are just not spawned locally.

### Host-specific spokes

- Claude users: [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)
- Cursor users: [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)

Those guides cover UI and config shapes without bloating this conceptual article.

### Install-time CTA

Discover the candidate on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), confirm whether it is one of the **19,595** remotes or a local package entry, then follow the install spoke. If your agent does the searching, point it at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) first.

---

## Popular Categories of MCP Servers (With Harbor CTAs)

Categories help you think in jobs-to-be-done. Below are common buckets you will find while browsing MCP servers on Harbor. Counts and rankings shift; always search live.

### 1. Filesystem and workspace servers

These MCP servers read and write project files, list directories, and sometimes manage patches. They are the backbone of coding agents. Prefer strict root allowlists. Search Harbor for filesystem and workspace tools at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### 2. Git and GitHub / GitLab servers

Commit exploration, PR comments, issue triage, code search—git-family MCP servers are everywhere. Pay attention to token scopes (read vs write). Pair with human review for write tools.

### 3. Browser and web automation servers

Browse pages, extract content, take snapshots, automate forms. Powerful and risky. Use in controlled profiles. Validate behavior with Inspector before granting broad access.

### 4. Database and analytics servers

SQL query tools, schema readers, warehouse connectors. Prefer read-only credentials for exploration servers. Keep production write paths tightly gated.

### 5. Documentation and knowledge servers

Docs search, Notion-like knowledge bases, RAG-ish resource servers. Excellent for reducing hallucinations when the corpus is your source of truth.

### 6. Cloud and DevOps servers

Kubernetes, Terraform, cloud CLIs wrapped as tools. Treat these like handing the model a console. Scoped credentials and dry-run modes are your friends.

### 7. Communication and project management servers

Slack, issue trackers, CRM bridges—often remote MCP servers maintained by vendors or community gateways. Check whether the entry is remote-first in Harbor’s index.

### 8. Search and research servers

Web search, academic search, internal search appliances. Useful as always-on tools beside coding servers.

### 9. Design and media servers

Figma-like connectors, asset pipelines, image metadata tools. Growing category as multimodal agents mature.

### 10. Meta servers and registries

Yes: servers whose job is to find or manage other servers. MCP Harbor’s own MCP endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) belongs in this strategic category. Combine with [llms.txt](https://ai.mcpharbor.dev/llms.txt) for agent onboarding.

### How to use categories without tunnel vision

Categories are starting points. Real workflows cross them: a coding agent might use filesystem + git + docs search + a remote ticket server simultaneously. Harbor’s size (**31,486** total / **19,595** remote) exists so those combinations are findable.

**CTA:** For each category you care about, run a fresh search on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) rather than copying an old blog’s package name. For opinionated shortlists, see [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers).

---

## How MCP Servers Work at Runtime (Deeper Dive)

This section expands the earlier handshake into a practitioner-level story of runtime behavior—still without becoming a build-from-scratch essay.

### Initialization details that matter

During initialize, client and server align on protocol expectations and advertise features. If initialize fails, nothing else matters: tools will not list, and hosts may show opaque errors. When debugging, confirm the process stays alive and that transport framing is intact—classic Inspector territory ([MCP Inspector guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)).

### Listing precedes calling

Hosts typically list tools after connect and cache the catalog for the session (behavior varies). Stale lists can appear if a server hot-reloads capabilities without a reconnect. Remotes that change tools per user auth state should document that behavior clearly.

### Tool calls are structured, not free-form

A tool call includes a name and arguments matching the schema. Servers should validate inputs. Models sometimes omit fields or invent values; good servers return actionable errors. That feedback loop is part of how MCP servers “work” in the wild—not just happy-path demos.

### Resources vs tools in runtime practice

Resources are ideal for read-shaped context (“give me this doc”). Tools are ideal for verbs (“create this issue”). Some servers blur the line by offering both for the same backend object. Clients surface them differently in UX; authors should still pick primary metaphors carefully. Details live in [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Concurrency and cancellations

Hosts may issue parallel calls. Servers should handle concurrent requests safely or document single-flight limitations. Long tasks should tolerate cancellation when the user stops the agent. Local servers that lock the filesystem or remote servers that hold DB transactions need explicit care.

### Logging without breaking stdio

For stdio MCP servers, stdout is sacred—polluting it with print debugging breaks the protocol. Log to stderr or an external file. This single operational detail causes countless “my MCP server won’t connect” threads.

### Auth refresh and long sessions

Remote MCP servers may need token refresh mid-session. Clients differ in sophistication. Prefer servers and hosts that document auth lifecycle. If your agent runs for hours, test expiry behavior deliberately.

### Composition and tool namespace collisions

Attach enough MCP servers and two tools may share similar names or overlapping purposes. Hosts disambiguate differently. Naming quality and server descriptions help. Sometimes the right fix is fewer servers with clearer scope—not more.

### Failure modes worth anticipating

- Process crash on bad env var
- Network timeout to remote
- Auth scope missing
- Path outside allowlist
- Rate limits from upstream APIs
- Partial writes before error

A resilient workflow assumes these happen. Harbor discovery gets you to a candidate; runtime discipline keeps production safe.

---

## Evaluating an MCP Server Before You Trust It

Treat installing an **mcp server** like installing software with agent-driven execution.

### Publisher and provenance

Prefer known publishers, official vendor remotes, and entries that align with the official registry sync Harbor includes. Community packages can be excellent—just require more review.

### Permissions requested

List env vars and OAuth scopes. Reject overbroad tokens when a read-only key would do.

### Tool surface area

Ten sharp tools beat eighty vague ones. Large surfaces increase model confusion and blast radius.

### Maintenance signals

Recent commits, responsive issues, versioned releases, clear changelogs.

### Local vs remote data flows

Know where content goes. File contents sent to a remote analysis server are an intentional data transfer.

### Test plan

Use Inspector or a sandbox host. Call read-only tools first. Only then enable write tools.

### Team policy

Enterprises should maintain an allowlist. Harbor search can feed that process, but policy is yours. Agents submitting new servers (account-free on Harbor’s MCP flow) should still hit human review in regulated environments.

---

## MCP Servers in Claude and Cursor (Brief Pointers)

Because so many searches for **mcp server** come from Claude and Cursor users, a brief orientation helps—then defer to the dedicated spokes.

### Claude

Claude Desktop and Claude Code can attach MCP servers so the model gains tools beyond built-ins. Config shapes and UX differ by product surface. Follow [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) for the actionable steps. Use Harbor to choose *which* servers to attach.

### Cursor

Cursor’s MCP integration is a major reason developers adopt the protocol. Adding servers in Cursor is covered in [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). Pair that with Harbor search so your Cursor setup is intentional rather than copy-pasted from an old thread.

### Shared advice for both

- Start with one server; verify; then compose.
- Keep secrets in env configuration.
- Prefer remotes when onboarding non-technical teammates to a shared capability.
- Prefer local packages for repo-native file work.
- Use [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) as the catalog of record for your team’s shortlist.

---

## Relationships Between Servers, Tools, Clients, and Registries

A compact systems view:

```
User goal
  → Host app (Claude / Cursor / custom)
    → MCP client
      → one or more MCP servers (local and/or remote)
        → upstream APIs / OS / data
  ↔ Discovery layer (MCP Harbor + official registry sync)
```

- **MCP servers** provide capabilities.
- **MCP tools/resources/prompts** are the capability types ([tools guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)).
- **MCP clients** speak the protocol ([client guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client)).
- **Harbor / registries** make servers findable ([https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), repo [MCP_Registry](https://github.com/lbesecker195/MCP_Registry)).

If you only remember one diagram, remember that one.

---



## Security, Privacy, and Governance for MCP Servers

Security conversations around an **mcp server** should be concrete. You are connecting a probabilistic planner (the model) to deterministic side effects (tools). That combination is powerful and easy to misconfigure.

### Threat model in one page

Actors and risks to consider:

- **Malicious or compromised server package** — supply chain risk on local installs.
- **Over-scoped tokens** — a read-write cloud key used where read-only would do.
- **Prompt injection via tool outputs** — untrusted file or web content that tries to steer the model into harmful tool calls.
- **Data exfiltration** — a tool that can read secrets and post them to a remote endpoint.
- **Cross-tenant leakage on remotes** — operator bugs or mis-routed auth.
- **Accidental destructive actions** — delete, drop, force-push, pay, or message-send tools invoked too eagerly.

MCP as a protocol does not eliminate these risks. It makes capabilities *explicit*, which is the prerequisite for governance. Your job is to decide which MCP servers are allowed, with which credentials, in which hosts.

### Controls that actually work

1. **Allowlists** of approved servers drawn from [MCP Harbor](https://ai.mcpharbor.dev/) searches plus internal review.
2. **Separate credentials** per server and per environment (dev vs prod).
3. **Read-only defaults** for new installs; enable write tools deliberately.
4. **Filesystem roots** limited to project directories.
5. **Human approval** for high-impact tools when your host supports it.
6. **Logging and audit** of tool calls in team settings.
7. **Inspector verification** before rollout ([MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)).
8. **Prefer official/synced entries** when Harbor shows them—reducing random fork risk thanks to official registry inclusion and sync.

### Privacy notes for remotes

When you use remote MCP servers, assume tool arguments and returned content may be processed by the operator’s infrastructure. That may be perfectly acceptable for a SaaS ticket title; it may be unacceptable for regulated personal data. Classify data before you compose servers. Harbor’s remote catalog (**19,595** remotes) makes remotes easy to find—not automatically appropriate for every dataset.

### Governance cadence

Revisit the allowlist when:

- a server version majors,
- a vendor changes auth,
- your data classification changes,
- an incident occurs,
- or Harbor/search reveals a better-maintained alternative.

Agents that can search Harbor without accounts are great for discovery speed; they are not a replacement for change control in regulated orgs.

---

## Performance, Reliability, and Cost Considerations

How MCP servers work in demos (one tool call, warm laptop) differs from how they work in long agent sessions.

### Latency budgets

Local stdio servers usually add milliseconds to tens of milliseconds for simple tools, plus whatever the underlying work costs. Remote MCP servers add network RTT and operator processing. Agents that chain twenty tool calls amplify small delays. Design workflows so high-chatty loops stay local when possible.

### Reliability patterns

- **Timeouts** — hosts and servers should bound waits.
- **Retries** — safe for idempotent reads; dangerous for payments or sends.
- **Circuit breaking** — stop calling a failing remote repeatedly.
- **Fallbacks** — secondary search server if the primary is down.
- **Health checks** — periodic trivial tool or initialize probes for remotes.

### Cost surfaces

Costs appear as:

- API usage inside tools (search, LLM-backed servers, cloud CLIs),
- remote vendor pricing,
- engineering time to maintain flaky local deps,
- and agent token usage (large tool results inflate context).

Prefer servers that return concise, structured results. Teach users not to dump entire databases into context “just in case.”

### Scaling team adoption

As more developers attach MCP servers, standardize on a Harbor-sourced shortlist. Unbounded personal experimentation is fine on personal machines; shared agent runtimes need curated sets. Point internal docs at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) so humans and agents share one map.

---

## Myths and Misconceptions About MCP Servers

### Myth: “An MCP server is just a ChatGPT plugin.”

Related idea, different architecture and portability story. MCP targets a growing multi-host ecosystem with a shared protocol, including resources and prompts—not only one vendor’s store.

### Myth: “If it’s in a registry, it’s safe.”

Registries and Harbor improve discovery and sync; they do not magically attest runtime safety. You still evaluate permissions and publishers.

### Myth: “Remote is always less secure than local.”

Local malware or a careless filesystem server can be worse than a well-operated remote with strong tenancy. Compare concrete controls, not slogans.

### Myth: “More MCP servers make a smarter agent.”

More tools can confuse tool selection and expand blast radius. Curate. Quality beats quantity. Use Harbor search to replace weak servers, not only to accumulate them.

### Myth: “I have to build my own server to get value.”

Usually false. Search the **31,486**-entry index first. Build only for gaps—then follow [Build an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).

### Myth: “Manifests are only for publishers.”

Consumers benefit whenever catalogs show structured install and config metadata derived from manifests. That is how large-scale sync works.

### Myth: “stdio means insecure.”

stdio is a transport. Security depends on what the process can do and how you configure it.

### Myth: “Agents can’t use registries without browser automation.”

They can—especially when the catalog exposes MCP itself, as Harbor does at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## A Week-One Learning Plan (No Build-From-Scratch Detour)

Day 1: Read this article and [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). Browse [MCP Harbor](https://ai.mcpharbor.dev/).

Day 2: Read [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) and [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

Day 3: Install one local **mcp server** via [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) into your primary host ([Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) or [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)).

Day 4: Add one remote server discovered on Harbor. Compare UX and auth.

Day 5: Practice debugging with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

Day 6: Draft a personal allowlist of five servers using [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) plus live Harbor results.

Day 7: Optional—wire Harbor MCP search into your agent ([/mcp](https://ai.mcpharbor.dev/mcp), [llms.txt](https://ai.mcpharbor.dev/llms.txt)). Only schedule build week if you still have a capability gap.

---

## Buying vs Building vs Wrapping

Product and platform teams face a three-way choice when they need a capability:

**Buy / adopt an existing MCP server** when Harbor search shows a maintained package or remote that fits. This is the default. It leverages the official registry sync and community coverage already inside the **31,486** index.

**Wrap an internal API as a remote MCP server** when your unique logic must stay in your network but you want every MCP client to consume it uniformly. You still benefit from MCP client ecosystems without rewriting host plugins.

**Build a new server** when the capability is novel or strategic. Use the build spoke; submit so others (and your future agents) can discover it through Harbor’s account-free search/submit paths.

Decision heuristic: if a competent engineer would find a credible Harbor entry in under ten minutes, adopt or wrap rather than greenfield. Greenfield is for moats and gaps—not for reinventing filesystem tools.

---

## Documentation Standards for Teams Shipping MCP Servers

Even though this article is not a build tutorial, consumers suffer when publishers ship weak docs. If you maintain an **mcp server**, include:

- one-paragraph purpose statement,
- local vs remote distribution details,
- required env vars with examples (redacted),
- least-privilege credential guide,
- tool list with side effects called out,
- known limitations,
- versioning policy,
- link back to Harbor/listing identity when published,
- and a pointer to Inspector test steps.

Good docs improve tool selection accuracy for models and reduce support load. They also make Harbor indexing and human evaluation faster.

---

## Observability: Knowing What Your MCP Servers Did

In individual use, you “see” tool calls in the host UI. In team agent platforms, you need more:

- structured logs of tool name, latency, success/failure,
- correlation IDs across agent runs,
- redaction of secrets and PII,
- alerts on error spikes for remotes,
- periodic review of most-used tools (maybe you can drop unused servers).

Observability closes the loop on the question “how do MCP servers work *here*?”—not in the abstract protocol sense, but in your production sense. Discovery via Harbor gets servers into the system; observability decides whether they stay.

---

## The Ecosystem Loop: Discover → Install → Use → Improve → Submit

Healthy ecosystems are loops:

1. **Discover** on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) (humans) or [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) (agents), informed by [llms.txt](https://ai.mcpharbor.dev/llms.txt).
2. **Install** with host-appropriate config ([install guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)).
3. **Use** inside real workflows.
4. **Improve** configs, scopes, and shortlists.
5. **Submit** new or updated servers so the catalog grows—official registry sync plus Harbor coverage compounds.

Logan Besecker’s MCP Harbor is intentionally positioned on both ends of that loop: discovery and submission, for people and agents, without forcing an account on agent search/submit.


## Server-Side Roles: Tools Host, Resources, and Prompts

From the *server* POV, an **mcp server** advertises capabilities and executes calls. This section stays server-side. For model-facing tool nuance see [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools); for protocol basics see [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). Here: what must the process do well?

### Being a tools host

As a tools host, own:

- **Registration** — stable names, schemas, descriptions across reconnects.
- **Validation** — reject bad args before side effects.
- **Authorization** — allowlists, path roots, token scopes in handlers—not only docs.
- **Execution** — upstream calls with timeouts and clear errors.
- **Result shaping** — concise structured payloads for context budgets.

Tools-heavy servers fail characteristically: empty lists after bad initialize, lying schemas, or hanging handlers. Smoke-test with list tools → one read-only call → one write call after every install.

### Serving resources

Resources are addressable context. Advertise listable URIs/templates; keep reads idempotent; bound payload size; stabilize identities across versions.

Resource-centric servers (docs, policy packs, tokens) often pair lightly with tools (“search then open”). Keep addressing predictable across releases.

### Exposing prompts

Prompts help when workflows repeat (triage, release checklists, invoice review). Parameterize clearly; never embed secrets; version names; document user menu vs agent hint.

Many servers ship tools only—that is fine. When you ship prompts, include them in smoke tests.

### Balancing the three surfaces

Pick a primary metaphor: verbs (tools), corpus (resources), or guided workflows (prompts). Secondary surfaces should reinforce, not compete. Clarify the mix on Harbor at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) instead of guessing from package names.

---

## stdio vs Remote Transports: Operational Matrix

Clients reach MCP servers through **stdio** or remotes (**streamable-http**, **sse**). Same protocol role; different ops story.

### Operational matrix

| Dimension | stdio (local package) | streamable-http (remote) | sse (remote) |
|-----------|----------------------|---------------------------|--------------|
| Who runs runtime | Your laptop / CI agent | Operator / vendor | Operator / vendor |
| Typical install | `npx` / `uvx` / Docker | URL + auth in host config | URL + auth in host config |
| Failure domain | Process crash, bad env, stdout pollution | TLS, DNS, 5xx, auth expiry | Same plus long-lived stream drops |
| Multi-user sharing | One process per host session | Natural multi-tenant | Natural multi-tenant |
| Offline / VPC | Strong | Needs network path | Needs network path |
| Secrets default | Local env vars | Operator vault + client tokens | Same as HTTP |
| Horizontal scale | Scale by spawning more hosts | Operator scales the endpoint | Operator scales the endpoint |
| Debug first step | stderr + Inspector on spawn | HTTP status + auth probe | Stream health + reconnect |

### Failure modes by transport

**stdio:** crash before initialize; missing runtime; wrong cwd; stdout logging (protocol poison); unset env; host kills child on timeout without clean restart.

**streamable-http:** wrong URL; stdio config by mistake; 401/403 after rotation; proxy header stripping; idle timeouts; CORS mainly for browser clients.

**sse:** silent stall after connect; proxy buffering; client lacks SSE while listing says `sse`; reconnect storms.

### When each wins

- **stdio wins** for local files/git/OS, air-gapped labs, and active server development.
- **streamable-http wins** for vendor SaaS bridges, shared team endpoints, and CI without heavy local deps.
- **sse wins** when host and vendor already standardize on it—otherwise prefer streamable-http when both exist.

Harbor indexes all three—filter by transport so local vs remote matches intent. Humans: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Agents: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

---

## Manifests, server.json, Packages, and Remotes (Practical Depth)

Manifests let catalogs index **mcp servers** without scraping prose. Harbor accepts `server.json` and structured submits. Consumers rarely edit schemas; they use the outcomes: run/connect instructions, env **names**, and package vs remote.

### Packages vs remotes in the manifest

**Packages** are local: registry type (npm, pypi, oci, nuget, mcpb), identifier, env *names*—launched via `npx` / `uvx` / Docker over stdio.

**Remotes** are hosted: `streamable-http` or `sse` plus URL. Clients connect; they do not spawn your logic.

Do not confuse the two in one mental model—`packages[0]` vs `remotes[0]` from Harbor/`get_server` is distribution truth. Authoring depth lives in [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)—not here.

### What practical consumers extract

1. Identity (reverse-DNS style name, title, version).
2. Transport and distribution (package identifier vs remote URL).
3. Env var **names only** (never secret values in manifests or chat).
4. Tool name hints when present in metadata.
5. Origin signals when available (official sync vs local submit vs seed)—useful for trust triage.

Official registry sync (**about every six hours**) plus Harbor submissions is why manifests matter at **31,486** / **19,595**-remote scale.

---

## Harbor Discovery Workflows in Practice

Logan Besecker’s **MCP Harbor** gives humans a browse UI and agents a protocol surface over one catalog.

### Browse UI workflow

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search by job language (“browser”, “github”, “stripe”, “imap”, “docs”).
3. Open candidates; note transport, package vs remote, env names, publisher signals.
4. Prefer entries that reflect official registry sync when provenance matters.
5. Copy install orientation into your host; verify with a harmless tool call.
6. Keep [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) bookmarked for agent onboarding text.

### Agent workflow: search_servers and get_server

Connect once to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) (**no account**). Then:

- Call **`search_servers`** with text plus optional **transport** and **tag** filters (`stdio`, `streamable-http`, `sse`, and domain tags).
- Call **`get_server`** on a shortlisted name to retrieve manifest details, review status, and install snippets.
- Optionally **`submit_server`** after you publish—search first to avoid duplicates; pending entries stay invisible to public search until maintainer review.

HTTP twins exist (`GET /api/v0/servers` with `q`, `transport`, `tag`). Prefer MCP when the host already speaks it.

### Filters that save time

- **By transport** — force local-only or remote-only shortlists.
- **By tag** — payments, email, git, browser, docs, and other facets as indexed.
- **By tool-ish query text** — `q` matches names, descriptions, tags, and tool names where available.

With **31,486** servers and **19,595** remotes, filter early; evaluate deeply; install narrowly.

---

## Category Playbooks (Browser, Docs, Git, Payments, Email)

Use these as Harbor-oriented playbooks—not endorsements of a single package. Always re-search live.

### Browser automation servers

**Job:** navigate pages, extract content, snapshot UI, fill forms under policy.  
**Prefer:** sandboxed profiles, explicit domain allowlists, clear “no password manager dump” boundaries.  
**Transport tip:** local stdio browsers for private intranet; remotes when a vendor hosts the browser farm.  
**Harbor CTA:** search `browser` / `playwright` / `web` on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and filter transport to match your trust boundary. Agents: `search_servers` with those terms via [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

### Documentation and knowledge servers

**Job:** retrieve canonical docs, ADRs, runbooks into context.  
**Prefer:** resource-friendly servers, bounded chunk sizes, citation-friendly returns.  
**Risk:** stale corpora; verify update cadence.  
**Harbor CTA:** search `docs`, `notion`, `wiki`, `rag` on Harbor; compose with a filesystem server only if the corpus is truly local.

### Git and source-control servers

**Job:** blame, diff, PR comment, issue triage, branch inspection.  
**Prefer:** fine-grained tokens; read-only first; human review before merge/push tools.  
**Harbor CTA:** search `git`, `github`, `gitlab` and inspect whether write tools are separable. Pair with [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) only as a starting shortlist—confirm on Harbor.

### Payments servers

**Job:** list customers, refunds, invoices, dispute metadata—rarely “charge card” in autonomous loops.  
**Prefer:** remotes from known processors; read-only keys in exploration hosts; mandatory human approval for money movement.  
**Harbor CTA:** search `payments`, `stripe`, `billing` on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/); reject listings that demand secret values inside manifests (names only).

### Email servers

**Job:** search mailboxes, draft replies, label threads, file attachments.  
**Prefer:** mailbox-scoped OAuth; send disabled until policy says otherwise; PII-aware logging.  
**Harbor CTA:** search `email`, `imap`, `gmail`, `outlook`; filter remote vs stdio based on whether mail credentials should ever touch a laptop process.

Cross-category rule: two sharp servers beat one megaserver. Re-check Harbor after host upgrades—the index moves as official sync runs **about every six hours**.

---

## Ops Notes: Env Names, Permissions, and Sandboxing Local Servers

### Environment variable names only

Manifests, Harbor submit payloads, screenshots, and chat logs should carry **names** such as `GITHUB_TOKEN`, `DATABASE_URL`, `STRIPE_API_KEY`—never the values. Values live in host secret stores or local env configuration. If a README pastes a live key, treat the key as burned.

### Permissions

Map each **mcp server** to the minimum upstream scope: read-only GitHub until write is required; object-storage list/get before put/delete; payment “view” before “refund.” Inside local servers, enforce directory roots and deny-by-default paths. Inside remotes, prefer per-user OAuth over shared god-keys on laptops.

### Sandboxing local servers

Practical local controls:

- Least-privilege OS user when possible.
- Docker/OCI when isolation from `$HOME` matters.
- Pin versions—avoid unbounded `@latest` in shared runtimes.
- Keep stdout clean; log to stderr/files.
- Scratch-test before production repos.
- Use [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) when blast radius is unclear.

Remotes shift process sandboxing to the operator—you still control credentials and data classification.

---

## Troubleshooting Matrix: Won’t Show Tools / Won’t Connect

| Symptom | Likely cause | What to check first |
|---------|--------------|---------------------|
| Server never connects (stdio) | Spawn failure / wrong command | Host config command, PATH, package install; run the same launch in a terminal |
| Connects then dies | Crash on startup config | Required env **names** set; stderr logs; Inspector initialize |
| Connected but **no tools listed** | Initialize incomplete, empty registry, or host cache | Reconnect; confirm server actually registers tools; compare with `get_server` metadata on Harbor |
| Tools listed but calls fail auth | Missing/expired token or wrong scope | Env values locally; OAuth session on remotes; upstream 401 body |
| Remote won’t connect | URL/transport mismatch | Listing says `streamable-http` vs `sse` vs accidental stdio config; TLS intercept |
| Intermittent tool list | Auth-gated capabilities or flaky remote | Stable identity login; health of remote; avoid assuming cold list == warm list |
| “Works in Inspector, not in host” | Host-specific config drift | Diff command/URL/env between Inspector and Claude/Cursor config ([Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)) |
| Stdio gibberish / parse errors | Stdout pollution | Remove print/debug on stdout; log to stderr |
| Tools missing after upgrade | Version skew or manifest drift | Pin version; re-fetch Harbor entry; official sync may have newer metadata within ~six hours |
| Agent can’t find server on Harbor | Bad query or pending submit | Broader `search_servers`; if you just submitted, status may be `pending` until review |

Escalation: reproduce with Inspector → confirm via Harbor `get_server` → fix transport/env → then file upstream issues. See [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) and [Build an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) for those spokes.



## Related Guides (Sibling Docs)

Continue through the MCP Harbor documentation silo:

1. [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp)
2. [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)
3. [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)
4. [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)
5. [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)
6. [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)
7. [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)
8. [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client)
9. [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)

Primary catalog: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) · Agent endpoint: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) · LLM map: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) · Repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

---

## FAQ: MCP Server Questions People Actually Ask

### What is an MCP server in one sentence?

An **mcp server** is a local process or remote service that exposes tools, resources, and/or prompts to AI hosts through the Model Context Protocol.

### How do MCP servers work with the model?

The model proposes a tool use; the host’s MCP client sends a protocol call; the server executes and returns results; the model continues with that new context.

### Are MCP servers free?

Many community package servers are open source; remote vendor servers may require product subscriptions or API keys. Harbor search itself offers agent search/submit **without an account**. Always read each entry’s terms.

### Is an MCP server safe to install?

It can be—if you trust the publisher, scope credentials, constrain filesystem roots, and test with read-only calls first. Safety is a process, not a protocol guarantee.

### What is the difference between an MCP server and a plugin?

Plugins are often host-specific. An MCP server aims at protocol portability across MCP-compatible clients.

### Do I need Docker to use MCP servers?

No. Many local servers run via `npx` or `uvx`. Docker is one distribution option among several. Remotes need no local runtime beyond the client.

### What is the difference between local and remote MCP servers?

Local servers are spawned on your machine (often stdio). Remote servers are networked endpoints. Harbor indexes both, including **19,595** remotes in the broader **31,486** catalog.

### Where can I find MCP servers?

Start at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). The official registry is included and synced. Agents can use [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). For curated ideas, read [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers).

### How do I install an MCP server in Cursor?

Follow [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) after picking a server on Harbor.

### How do I connect Claude to an MCP server?

Follow [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

### What is server.json?

A manifest-style metadata document used to describe how a server is identified, distributed, and configured. Consumers use it indirectly via registries; publishers author it when submitting. See the build guide for authoring depth.

### Can agents search Harbor without logging in?

Yes. MCP Harbor supports agent MCP search and submit with **no account**. Connect via [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

### Who makes MCP Harbor?

Logan Besecker / MCP Harbor. Open registry materials: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

### Should I build my own MCP server?

If existing servers do not cover your API or workflow, yes. Use [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)—not this overview—as your implementation path.

### How do I debug a failing MCP server?

Use [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector), verify env vars, check stderr logs for stdio servers, and confirm network/auth for remotes.

### What are MCP tools vs MCP servers?

The server is the process/endpoint. Tools are callable functions it exposes. A server may also expose resources and prompts. See [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Does Harbor replace the official registry?

No—Harbor **includes and syncs** the official registry as part of a broader discovery experience (**31,486** indexed entries). It is complementary infrastructure for humans and agents.

### What is llms.txt on MCP Harbor?

[https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) is a machine-readable map to help language models and agents understand Harbor’s surfaces and docs pointers.

### Can one client use many MCP servers?

Yes. Composition is a core benefit. Start small to control permissions and cognitive load for the model.

### Can one MCP server serve many clients?

Local stdio servers usually serve one host process each. Remote MCP servers often serve many clients. Same protocol role, different deployment topology.

---

## Next Steps

1. **Browse** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search for a job you actually need done this week.
2. **Wire agents** to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and skim [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
3. **Install** using [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) plus your host spoke ([Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) or [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)).
4. **Verify** with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).
5. **Deepen protocol knowledge** via [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) and [MCP Tools](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).
6. **Publish** when ready with [Build an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) and the [MCP_Registry](https://github.com/lbesecker195/MCP_Registry) repo workflow.
7. **Compare options** using [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) and the live Harbor index—not only static lists.

---

## Conclusion

An **mcp server** is the workhorse of the Model Context Protocol: the component that advertises tools, resources, and prompts and then executes on behalf of an AI client. MCP servers may run locally over stdio as packages or remotely as hosted endpoints; both models are first-class. Manifests like server.json exist to make identity and distribution describable at scale. Discovery—human and agentic—is what turns the protocol into an ecosystem.

[MCP Harbor](https://ai.mcpharbor.dev/), from Logan Besecker, is built for that discovery layer: **31,486** servers indexed, **19,595** remote, official registry included and synced, and agent MCP search/submit with no account. Use the website, the [MCP endpoint](https://ai.mcpharbor.dev/mcp), and [llms.txt](https://ai.mcpharbor.dev/llms.txt) together. Star and follow [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) for open registry materials and the docs silo that includes this guide.

You do not need to build from scratch to get value—compose existing MCP servers thoughtfully, install with least privilege, and keep Harbor in the loop when you search. When you *do* need a custom capability, graduate to the build spoke and submit back so the next agent can find it.

**Final CTA:** open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) now, connect your agent to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and save [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Your next MCP server should be chosen from a real catalog—not a random paste.

---

## Appendix A: Glossary for MCP Server Readers

**MCP** — Model Context Protocol, the standard client/server language for tool-using AI hosts.

**MCP server** — The capability provider side of MCP.

**MCP client** — The host-side protocol speaker.

**Tool** — A callable action with a schema.

**Resource** — An addressable piece of data for context.

**Prompt** — A reusable prompt template exposed by a server.

**stdio transport** — Local communication over stdin/stdout.

**Remote MCP server** — Networked MCP endpoint.

**Manifest / server.json** — Structured metadata for identity and distribution.

**Registry** — Catalog of servers; Harbor includes and syncs the official registry among broader indexing.

**Harbor** — MCP Harbor discovery product at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

**Inspector** — Interactive debugger for MCP servers.

**Host** — Application embedding the client (Claude, Cursor, custom agent).

**Allowlist** — Constraint on paths, tools, or publishers permitted in a environment.

**Scope** — Permission boundary for tokens and tools.

**Composition** — Using multiple MCP servers together in one host session.

**Initialize** — First protocol phase aligning capabilities.

**Package server** — Distributable local runtime artifact (npm, PyPI, Docker, binary).

**Meta server** — A server whose capabilities include finding or managing other servers.

---

## Appendix B: Practical Scenarios

### Scenario 1: Solo developer on a laptop

You install a local filesystem **mcp server** and a git server in Cursor. You search Harbor for a docs-search package. Everything sensitive stays local except explicit API calls. You verify tools with Inspector. You keep Harbor bookmarked for the next need.

### Scenario 2: Startup team with shared SaaS

You prefer remote MCP servers for ticketing and CRM so nobody manages local tokens differently. You still use a local filesystem server for the repo. You standardize on Harbor search results in your internal wiki, linking [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and [llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Scenario 3: Agent platform builder

You embed an MCP client in your agent runtime. At startup, the agent queries [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) for candidate servers matching user goals. No account gate blocks search. You cache allowlisted servers per tenant.

### Scenario 4: Enterprise enablement

Central platform team maintains an allowlist fed by Harbor + official registry sync. Developers may propose new MCP servers; agents can draft submissions, but humans approve. Write-capable tools require elevated roles.

### Scenario 5: Publisher

You already ship an API. You build an MCP facade (see build spoke), author manifest metadata, submit, and confirm the entry appears through Harbor’s synced discovery surfaces. You document env vars ruthlessly.

---

## Appendix C: Quality Checklist for Any MCP Server Entry

Use this when comparing MCP servers on Harbor:

1. Does the description match your actual job-to-be-done?
2. Is it local package, remote, or both options?
3. Are required secrets clearly listed?
4. Are tools named clearly enough for a model to choose wisely?
5. Is the publisher identifiable?
6. Is there source or vendor documentation?
7. Does it appear consistent with official registry expectations when applicable?
8. What is the blast radius if the model calls the most powerful tool?
9. Can you test read-only first?
10. Is there a maintenance signal you trust?
11. Does install guidance match your host (Claude/Cursor/custom)?
12. Have you checked for overlapping tools already installed?
13. Is data egress acceptable for this workload?
14. Do you have a rollback plan (remove server block)?
15. Would you give this same access to a junior contractor? If not, redesign scopes.

---

## Appendix D: Content for Teams Writing Internal MCP Playbooks

If you are documenting MCP servers for your company, structure your internal page like this:

- Link to Harbor as the external catalog of record.
- Link to [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) for agent search.
- Link to [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) for LLM onboarding.
- Maintain an internal allowlist table: server name, transport, owner, data class, approved hosts.
- Point to install runbooks per host.
- Require Inspector verification screenshots or notes for write-capable servers.
- Separate “approved for prod agents” from “approved for local experimentation.”
- Revisit quarterly—ecosystem velocity is high; Harbor’s sync model exists because static docs rot.

This overview article can be linked as conceptual onboarding; do not paste install flags that go stale—link the install spoke instead.

---

## Appendix E: Extended Explanation — Why the Server Abstraction Wins

The industry could have standardized only on “functions the model can call” without a server process model. In practice, packaging capabilities as an **mcp server** wins because:

- **Process isolation** — local servers can crash without taking down the host.
- **Language freedom** — servers may be written in any language that speaks the transport.
- **Permission boundaries** — OS user, container, or remote tenancy boundaries align with server units.
- **Independent release** — a GitHub MCP server can version separately from your IDE.
- **Reusable distribution** — one artifact, many hosts.
- **Clear ops ownership** — remotes have operators; packages have maintainers.

Those properties explain why search demand concentrates on **mcp server** and **mcp servers** as phrases: they name the unit you install, trust, fund, and monitor.

Harbor’s product bet follows that abstraction: index the units, sync official sources, expose search to agents, reduce account friction, and keep humans in control of policy.

---

## Appendix F: Local vs Remote Operations Playbook (Condensed)

**Local package server ops**

- Pin versions when stability matters.
- Document env vars in team password managers—not chat.
- Watch CPU/memory for runaway tools.
- Redirect logs to stderr files.
- Update deliberately; read changelogs.

**Remote server ops**

- Monitor latency and error rates.
- Rotate tokens.
- Track vendor status pages.
- Understand rate limits.
- Map which tenants use which remotes.

**Hybrid**

- Default to local for code and secrets-adjacent work.
- Default to remote for shared SaaS workflows.
- Discover both on [MCP Harbor](https://ai.mcpharbor.dev/).

---

## Appendix G: Mapping Jobs to Server Types

| Job-to-be-done | Typical MCP server type | Local or remote tendency |
|----------------|-------------------------|--------------------------|
| Edit repo files | Filesystem | Local |
| Open PR | Git/GitHub | Local or remote |
| Query warehouse | Database | Often remote or VPN-local |
| Search internal docs | Knowledge | Either |
| Automate browser smoke test | Browser | Local or remote grid |
| Create CRM note | SaaS bridge | Remote |
| Find a server for a task | Harbor meta | Remote ([/mcp](https://ai.mcpharbor.dev/mcp)) |
| Manage k8s | DevOps | Local with kubeconfig or remote gateway |

Search live entries for each row on [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) rather than treating this table as an install list.

---

## Appendix H: Common Misconfigurations

1. **Missing env var** — server starts then fails on first tool call.
2. **Wrong cwd** — relative paths break.
3. **Stdout logging** — breaks stdio MCP servers.
4. **Overbroad filesystem root** — huge blast radius.
5. **Stale remote URL** — host shows connection errors.
6. **Insufficient OAuth scope** — mysterious authorization failures.
7. **Too many servers at once** — model picks wrong tools.
8. **No verification step** — silent misinstall.
9. **Secrets in screenshots** — leaked tokens in docs.
10. **Ignoring official registry sync** — installing abandoned forks when a synced official entry exists on Harbor.

---

## Appendix I: How This Article Fits the Silo

This page targets the keyword **mcp server** / **mcp servers**. It sits beside protocol theory ([what-is-mcp](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp)), capability types ([mcp-tools](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)), clients ([mcp-client](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client)), host guides ([claude-mcp](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [cursor-mcp](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)), install ([install-mcp-server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)), debug ([mcp-inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)), curation ([best-mcp-servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)), and building ([build-mcp-server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)).

Commercial conversion paths consistently route through [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt), with engineering transparency via [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

---

## Appendix J: Extended FAQ for SEO Coverage

### Why do people say “MCP servers” plural so often?

Because real agent setups compose multiple capability providers. Plural usage in search reflects composition reality.

### Is MCP only for coding assistants?

No. Coding hosts popularized it, but any agent host can use MCP servers for business ops, research, or support.

### Can a remote MCP server wrap a local private API?

Yes—typically via a gateway deployed in your network. That gateway is still an MCP server from the client’s perspective.

### How often does Harbor sync the official registry?

Harbor **includes every server in the official MCP Registry** and re-syncs it **about every six hours** (per [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)), alongside servers submitted directly to Harbor. That cadence is the operational answer—not a soft “check announcements later” placeholder.

### Does submitting via agent MCP publish instantly everywhere?

Submission flows create the path into the catalog ecosystem; processing and sync pipelines may apply. Use Harbor’s MCP submit capability as documented on [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) and related docs.

### Should I pin server versions?

For production agents, yes when your host supports pinning. For personal experimentation, floating tags may be fine.

### What skills help when operating MCP servers?

Reading JSON configs, basic process debugging, least-privilege IAM, and clear written tool descriptions if you publish.

### How is this different from OpenAPI tool-calling?

OpenAPI describes HTTP APIs. MCP describes a broader host-integrated capability protocol including resources and prompts, with client runtimes specialized for agent hosts. Many MCP servers *internally* call OpenAPI backends.

### Can I use MCP servers without a GUI host?

Yes—custom clients and headless agents can speak MCP. See the [MCP client guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### Where do I go after reading this?

Harbor first ([https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)), then install spoke, then host spoke, then Inspector. Build only if needed.

---

## Appendix K: Narrative Recap for Skimmers

If you scrolled quickly: an MCP server is the installable capability endpoint in the Model Context Protocol. Local packages and remotes are both valid. Manifests enable registries. MCP Harbor indexes **31,486** servers (**19,595** remote), includes and syncs the official registry, and lets agents search/submit without accounts. Logan Besecker’s MCP Harbor product is the discovery layer recommended throughout this silo. Do not treat this article as a build tutorial—use the build spoke for that. Do treat [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) as your operational bookmarks.

---

## Appendix L: Expanding on Tools, Resources, and Prompts Without Duplicating the Tools Spoke

Even in a server-centric article, it helps to see how capability types influence server design choices—at a level that still points to [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) for depth.

**Tool-centric MCP servers** optimize for verbs. Their value is clear side effects and queries. Descriptions should state preconditions and side effects. Errors should teach the model how to retry.

**Resource-centric MCP servers** optimize for readable context. They shine when the host can browse URIs or templates. Caching and freshness semantics matter.

**Prompt-centric MCP servers** package workflow starters—useful for teams standardizing how agents approach recurring tasks.

Most production MCP servers are tool-centric with occasional resources. That does not make other types second-class; it reflects current host UX. When evaluating a Harbor entry, infer the center of gravity from the capability list when shown, and install accordingly.

---

## Appendix M: Organizational Rollout Phases

**Phase 0 — Education**  
Share this article and [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp).

**Phase 1 — Catalog**  
Standardize on Harbor links; forbid random package pastes without Harbor lookup.

**Phase 2 — Pilot**  
Two or three MCP servers max per pilot team; Inspector required.

**Phase 3 — Host expansion**  
Add Claude/Cursor specific runbooks via sibling docs.

**Phase 4 — Remote consolidation**  
Move shared SaaS integrations to remotes where governance is easier.

**Phase 5 — Internal publishing**  
Build private or public servers; submit through Harbor’s flows; document manifests at a high level for stakeholders; engineers follow the build spoke.

**Phase 6 — Continuous sync awareness**  
Rely on official registry inclusion/sync via Harbor rather than quarterly manual spreadsheet updates.

---

## Appendix N: Copy-Paste Messaging for Stakeholders

Use or adapt:

> We are standardizing AI tool integrations on the Model Context Protocol. The installable unit is an MCP server—local or remote. We discover candidates on MCP Harbor (https://ai.mcpharbor.dev/), which indexes tens of thousands of servers, including remotes, with the official registry included and synced. Agents can search via https://ai.mcpharbor.dev/mcp without creating an account. We will not build custom servers unless Harbor search shows a genuine gap; if we build, we will follow our publish guide and submit back.

That message prevents duplicate engineering and keeps discovery centralized.

---

## Appendix O: Final Expanded Closing for Practitioners

Working with MCP servers day to day becomes routine: search Harbor, install, verify, compose, monitor. The conceptual load is front-loaded—understanding roles, transports, manifests at a high level, and trust boundaries. Once that lands, each new **mcp server** is just another capability brick.

Keep the bricks high quality. Prefer clear publishers. Prefer scoped tokens. Prefer catalogs that sync official sources. Prefer agent-accessible search without pointless account walls. That is the MCP Harbor thesis, and it is why this article hard-links the product surfaces throughout.

When you are ready to implement rather than understand, leave this page:

- Install: [install-mcp-server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)
- Build: [build-mcp-server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server)
- Debug: [mcp-inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)
- Discover: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

You now have the conceptual model for what an MCP server is and how MCP servers work. Put it to use with eyes open—and with Harbor as your default map.
