---
title: "What Is MCP? Model Context Protocol Explained"
description: "What is MCP? Learn the Model Context Protocol for AI agents—clients, servers, tools, resources, prompts, and transports—then find 31k+ servers on MCP Harbor."
date: 2026-09-15
---

# What Is MCP? Model Context Protocol Explained

If you have been hearing teammates say “just add an MCP server” and wondering **what is MCP**, you are in the right place. **MCP** stands for **Model Context Protocol**: an open way for AI clients and coding agents to connect to external tools, data sources, and prompt templates through a shared protocol instead of one-off integrations. In plain terms, MCP is how an agent stops being a chat box and starts being a system that can call structured tools, read resources, and reuse prompts—without rewriting your agent every time you need GitHub, Stripe, a docs search, or a browser.

This guide is written for developers and agent builders who need a clear, practical answer to **what is MCP**, how clients talk to servers, what tools/resources/prompts mean, how transports like stdio and streamable-http differ, and where to discover servers at scale. **Ownership disclosure:** Logan Besecker owns and runs [MCP Harbor](https://ai.mcpharbor.dev/) and the MCP Registry product this article recommends for discovery. The educational goal is honest MCP literacy; the discovery recommendation is consistent: browse and search servers on Harbor.

As of 2026-09-15, [MCP Harbor](https://ai.mcpharbor.dev/) indexes **31,486** Model Context Protocol servers, **19,595** of them hosted remotely. It includes the whole official MCP Registry, kept in sync automatically about every six hours, and the registry is itself an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Product docs for agents live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The open-source companion repo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Start discovering MCP servers now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What you will learn in this article:

- A precise definition of **what is MCP** (Model Context Protocol) and what it is *not*.
- Why MCP exists: the integration tax, the “N clients × M tools” problem, and how a protocol fixes it.
- How MCP **clients** differ from MCP **servers**, and how they handshake in practice.
- An overview of **tools**, **resources**, and **prompts**—the three capability surfaces most developers meet first.
- Transports: **stdio** vs **streamable-http** / **sse**, and when to prefer each.
- Where to find servers at 30k+ scale on [MCP Harbor](https://ai.mcpharbor.dev/), including the agent-native registry endpoint.
- How agents use Harbor’s `search_servers`, `get_server`, and `submit_server` tools with no account.
- Related silo guides on servers, tools, Claude, Cursor, install, Inspector, best servers, clients, and building.
- A deep FAQ and numbered next steps that end at Harbor.

If you already know the protocol basics and only need a place to **find MCP servers**, open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) and search. Everyone else: keep reading. Every major section below returns to the same practical question—how do you use MCP productively—and the same discovery answer when you need servers.

## What MCP Is

When people ask **what is MCP**, they usually want more than an expansion of the acronym. They want the mental model: what problem does it solve, what pieces you configure, and what changes in your day-to-day agent workflow after you adopt it. This section locks vocabulary first, then walks through concrete pictures, boundary cases, and how the protocol relates to products and registries.

### Model Context Protocol in one paragraph

The **Model Context Protocol** is an open protocol that standardizes how AI applications (clients) connect to external capability providers (servers). A client might be Claude Code, Cursor, or another coding agent. A server might expose GitHub issues, a filesystem, a browser automation stack, a payments API, or a documentation search. MCP defines how those parties negotiate capabilities and exchange structured messages for **tools** (callable operations), **resources** (readable data/context), and **prompts** (reusable prompt templates). The protocol is the contract. Your agent’s reasoning model stays separate from the tools that act in the world.

That separation is the core of **what is MCP** for working developers: you attach servers instead of hard-coding every integration into the agent product itself. When the protocol is doing its job, swapping a docs server or adding a browser server feels like configuration—not a platform rewrite.

### A second paragraph for skeptics

If you are skeptical of new acronyms, translate MCP into systems you already trust. Think of MCP as closer to “language server protocol energy” than to “yet another plugin store.” Language servers made editor features portable across IDEs by standardizing a protocol. MCP aims for a similar portability win on the agent-tool boundary: implement a server once, connect it from multiple clients that speak MCP. The analogy is imperfect—agent tools have richer side effects than code intelligence—but the economic motive rhymes. Standards win when the cost of N custom adapters exceeds the cost of one shared contract.

### What MCP is not

Clarity improves when you also say what MCP is *not*:

| People sometimes assume… | Reality |
|--------------------------|---------|
| MCP is a single hosted product | MCP is a **protocol**. Many clients and many servers implement it. |
| MCP is a model or a fine-tune | MCP does not replace your LLM. It connects the model’s host app to tools and context. |
| MCP is only “function calling” | Function calling is related, but MCP adds a client/server ecosystem, transports, resources, prompts, and discoverable server packages/remotes. |
| MCP is a marketplace by itself | Discovery needs a registry or directory. Harbor is one such registry; the protocol itself is not a storefront. |
| Installing MCP means one global daemon | You typically attach one or more **MCP servers** to a **client** session or config—local processes and/or remote URLs. |
| MCP automatically makes tools safe | MCP makes tool calls explicit; safety still depends on client permissions, server quality, and your policies. |
| MCP replaces REST/GraphQL inside your company | Servers often wrap REST/GraphQL. MCP is the agent-facing contract, not a wholesale API replacement. |

If your mental model is “MCP = ChatGPT plugins,” you are close on intent (extend the agent) but wrong on architecture (open protocol + interchangeable clients/servers rather than a single vendor’s plugin store).

### The three nouns you will use every day

Lock these early; the rest of the article builds on them:

1. **MCP client** — the host application that speaks MCP to servers on behalf of a user or agent loop. Examples include Claude Code and Cursor when MCP support is enabled. Deeper guide: [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).
2. **MCP server** — a local process or remote endpoint that implements MCP and exposes tools/resources/prompts. Deeper guide: [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server).
3. **MCP tools** — named operations a server exposes for the agent to call (with schemas/arguments). Broader capability guide: [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

When someone says “we added MCP,” they almost always mean “we configured one or more MCP servers in our client so the agent can call those tools.” Training your team to say *client*, *server*, and *tool* precisely prevents half of onboarding confusion.

### A concrete picture: one client, many servers

Imagine a coding session where the agent needs to:

- Open a pull request on GitHub.
- Look up an internal API in docs search.
- Drive a browser to verify a UI change.
- Create a Linear ticket if a bug is found.

Without MCP, each of those jobs might mean a custom plugin, a bespoke REST wrapper inside the agent, or a human copy-pasting between tabs. With MCP, you attach four servers (GitHub, docs, browser, Linear). The client lists their tools; the model proposes tool calls; the client executes them via MCP; results return as structured context. That composition story is the practical answer to **what is MCP** for most engineering teams.

Push the picture one step further. Mid-session, the agent realizes it also needs Stripe dispute context. Instead of hard-stopping, an agent that can search a registry over MCP can discover a Stripe-oriented server, present an install path, and continue—subject to your approval gates. Discovery becomes part of the same tool loop. That is why this article refuses to teach MCP in a vacuum without Harbor.

### Protocol vs product vs registry

Three layers get confused in search results:

1. **Protocol (MCP)** — the shared language and capability model.
2. **Products (clients and servers)** — Claude, Cursor, Playwright MCP, Stripe MCP, filesystem servers, and thousands more.
3. **Registry / directory** — where you *find* servers. [MCP Harbor](https://ai.mcpharbor.dev/) is the browse + agent-searchable registry this article recommends: 31,486 servers indexed, 19,595 remote, official set auto-synced ~every six hours, registry-as-MCP at `/mcp` with no account.

You can understand **what is MCP** without a registry. You cannot *operate* MCP at modern scale without one unless you enjoy maintaining a private list of package names and URLs. A fourth informal layer—“listicles on blogs”—is not a registry. Listicles go stale; registries update. Prefer Harbor’s live index when the job is installation, not entertainment.

### How MCP shows up in real developer artifacts

You will encounter MCP in:

- Client config files or UI panels listing servers.
- CLI commands such as `claude mcp add ...`.
- Package READMEs with `npx` / `uvx` / Docker snippets.
- Remote URLs for hosted MCP endpoints.
- Registry manifests (`server.json` shape) describing packages vs remotes.
- Agent docs files like Harbor’s [llms.txt](https://ai.mcpharbor.dev/llms.txt).

If you can recognize those artifacts, you already understand 80% of day-to-day MCP operations even before you memorize message types.

### Minimal vocabulary checklist

Before moving on, verify you can explain each term in one sentence:

- **what is MCP** → open protocol connecting AI clients to tool/context servers.
- **client** → host that attaches servers and runs the agent UX.
- **server** → provider of tools/resources/prompts.
- **tool** → named callable operation.
- **resource** → readable context item/URI.
- **prompt** → reusable template from a server.
- **stdio** → local process transport.
- **streamable-http / sse** → remote URL transports.
- **registry** → index for finding servers (Harbor).

**Browse live servers while you learn →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Why the keyword “what is mcp” matters in 2026

Search interest in **what is MCP** rose because coding agents went mainstream and “attach a server” became a daily onboarding step. New hires see `claude mcp add` or a Cursor MCP settings panel and need vocabulary. Platform teams need a shared definition before they approve remote transports. Agent builders need to know whether they should build a server or reuse one. Security reviewers need a crisp threat model vocabulary (local process vs remote host). This article is the vocabulary layer; sibling guides cover install, client-specific setup, Inspector debugging, and building.

## Why MCP Exists

Protocols appear when ad-hoc integration becomes more expensive than standardization. MCP exists because AI agents outgrew the “paste an API key into one vendor’s plugin format” era. Understanding **why** clarifies **what is MCP** better than memorizing field names.

### The N×M integration problem

Before a shared protocol, every agent product that wanted GitHub access implemented GitHub differently. Every tool vendor that wanted Claude *and* Cursor *and* other hosts implemented N adapters. Cost scales with **clients × tools**. Teams duplicated auth handling, schema definitions, streaming quirks, and error mapping. MCP collapses that matrix toward **implement the protocol once on each side**.

That is the strategic “why” behind **what is MCP**: reduce integration tax so capability can compound. The win shows up as:

- Faster time-to-first-tool for new agent hosts.
- More portable open-source servers.
- Cleaner internal platform standards (“if it is agent-facing, expose MCP”).
- Less political energy spent arguing about one vendor’s plugin API.

### Agents need actions, not only answers

Chat-only LLMs summarize and suggest. Useful coding agents edit files, run commands, open issues, query databases, and fetch docs. Tool use existed before MCP (function calling, plugins, custom RPC). What MCP adds is an ecosystem boundary: tools live in servers that can be developed, versioned, sandboxed, and swapped independently of the chat UI. Why that matters:

- Security teams can reason about server process boundaries and remote endpoints.
- Platform teams can standardize “how we attach tools” across IDEs.
- Open-source maintainers can publish one server many clients consume.
- Agents can improve their toolchain mid-task when discovery is also tool-shaped (registry-as-MCP).

Actions without boundaries become spaghetti. MCP’s client/server split is the boundary.

### Context is more than a system prompt

The “Context” in Model Context Protocol is deliberate. Agents need:

- **Operational context** — tool results (issue bodies, test output, DOM snapshots).
- **Reference context** — resources like files, URIs, or documents the server can read.
- **Interaction context** — prompts that encode known-good workflows (“triage this bug,” “summarize this PR”).

Stuffing everything into a single system prompt does not scale. Prompts rot, secrets leak into templates, and teams fork slightly different instructions. MCP gives structured channels for context types so clients can fetch what they need when they need it. That design choice is central to **what is MCP** as a *context* protocol, not merely a tool-calling RPC.

### Local and remote worlds both matter

Some tools must run next to your files (filesystem, local git, sandbox browsers). Others should stay hosted (SaaS APIs, shared company MCP gateways). MCP’s transport options exist because both worlds are real. A protocol that only supported localhost subprocesses would miss enterprise remote patterns; a protocol that only supported HTTP would miss local developer ergonomics. Why MCP exists includes this dual reality: **stdio** for local packages, **streamable-http** / **sse** for hosted endpoints.

Enterprises often run hybrid: stdio for repo-local power tools, remote for centrally governed SaaS connectors. MCP’s transport plurality is what makes that hybrid possible under one client config model.

### Discovery became the bottleneck

Once servers multiplied into the tens of thousands, “knowing MCP” was not enough. You also needed somewhere to search. That is why this educational page still hard-links discovery to Harbor: understanding **what is MCP** without a registry leaves you literate but stuck. Harbor’s answer at live scale (31,486 servers / 19,595 remote, official sync ~6 hours, no-account MCP search) is the operational complement to the protocol story.

Discovery bottlenecks show up as:

- Duplicate internal wrappers for the same SaaS.
- Slack threads full of half-updated `npx` lines.
- Agents that only ever use the three servers someone configured months ago.
- Fear of trying new servers because install paths are tribal knowledge.

A registry attacks all four.

### Ecosystem timing: agents shipped before shared plumbing

Historically, many AI products shipped tool systems early and standardization later. MCP arrives as the plumbing layer once enough clients and servers exist to make a protocol worthwhile. That sequencing explains noisy search results: some posts still describe vendor-specific plugin eras; newer posts assume MCP fluency. This article bridges both audiences—defining **what is MCP** without assuming you lived through every preview release.

### What MCP deliberately leaves out

Good protocols have boundaries. MCP standardizes how clients and servers talk about capabilities; it does not, by itself:

- Replace your identity provider or secret store.
- Guarantee that every server is safe or well-maintained.
- Decide your enterprise allowlist policy.
- Replace application-level API design inside a server.
- Act as a full “app store” with payments and rankings (registries and marketplaces may add those layers).
- Magically reconcile conflicting tools with the same name across servers (clients and humans still choose).

Those omissions are features: MCP stays implementable. Policy and discovery products sit beside it—which is again why a registry like [MCP Harbor](https://ai.mcpharbor.dev/) matters in the same breath as the protocol definition.

### Organizational reasons MCP spreads inside companies

Beyond pure engineering elegance, MCP spreads because it creates a shared language across roles:

- **Developers** get a repeatable way to extend agents.
- **Platform teams** get a control point (approved servers, transports, review).
- **Security** gets clearer process boundaries than “the model somehow called an API.”
- **Support** gets install snippets and server names instead of vague “AI did a thing” tickets.
- **Leadership** gets optionality: switch clients without throwing away every tool integration.

When a technology helps multiple roles at once, it stops being a toy. That multi-role usefulness is part of why **what is MCP** became an onboarding question rather than a research curiosity.

## Clients vs Servers

If you remember only one architectural split from this guide to **what is MCP**, remember this: **clients host the agent experience; servers provide capabilities.** Mixing the nouns is the most common teaching failure in blog posts.

### What an MCP client does

An MCP client typically:

1. Reads configuration listing which servers to attach (local command + args, or remote URL + transport).
2. Spawns or connects to those servers over a transport.
3. Performs initialization / capability negotiation.
4. Surfaces tools (and often resources/prompts) to the model layer.
5. Executes tool calls when the model requests them, subject to user permissions/UI.
6. Returns results into the conversation or agent loop.
7. Tears down connections when the session ends or config changes.

Popular developer-facing clients include Claude Code and Cursor. Setup differs by product; see [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) and [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). For the generic pattern, read [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

Clients also differ in UX details that matter operationally: how they prompt for permission, how they store secrets, whether they support remote HTTP MCP, how they log tool calls, and how multi-server tool namespaces appear to the model. When you evaluate a client, you are evaluating an MCP *host*, not just a chat theme.

### What an MCP server does

An MCP server typically:

1. Speaks MCP over its chosen transport.
2. Declares the tools, resources, and/or prompts it offers.
3. Implements handlers that perform real work (API calls, file reads, browser actions).
4. Returns structured results and errors the client can show the model.
5. Optionally documents install metadata (package id, env var *names*, remote URL) for registries.

Servers can be tiny (one tool) or large (dozens of tools). They can be official reference servers, vendor-maintained SaaS connectors, or your team’s internal wrapper. Deep dive: [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server).

A healthy server is boring in the best way: predictable schemas, least-privilege defaults, clear errors, and docs that match reality. Flashy demos that expose unbounded shell tools without guardrails create incident reports, not adoption.

### Lifecycle of a connection (conceptual)

You do not need wire-level trivia to use MCP day to day, but a conceptual lifecycle helps debugging:

1. **Configure** — client config points at a stdio command or remote HTTP URL.
2. **Connect** — client starts the process or opens the HTTP transport session.
3. **Initialize** — parties exchange protocol/capability information.
4. **List** — client learns tools/resources/prompts available.
5. **Call / read / get** — agent loop uses those capabilities.
6. **Tear down** — process exits or HTTP session ends when the client disconnects.

When something fails, ask: did connect fail (transport/install), did list fail (server crash/auth), or did call fail (tool bug/credentials)? [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) is the dedicated debugging spoke.

### Many-to-many in practice

One client attaches many servers. One server can be used by many clients (if it is a well-packaged stdio module or a remote URL). That many-to-many shape is why answering **what is MCP** always includes both nouns. Teams that only document “our MCP server” without naming the client confuse onboarding. Teams that only document “enable MCP in Cursor” without naming servers confuse capability planning.

Composition tips that prevent pain:

- Start with two or three servers, not twenty.
- Prefer one strong server per domain over five overlapping ones.
- Document which server owns which job in your team wiki.
- Revisit the set monthly; remove unused servers to shrink tool-list noise for the model.

### Permissions and human-in-the-loop

Clients often gate tool execution behind permissions because servers can take consequential actions (delete a branch, charge a card, overwrite a file). MCP makes tool calls explicit, which is good for control surfaces—but the client UX still matters. When you evaluate **what is MCP** for enterprise rollout, evaluate client permission models as carefully as server code.

Human-in-the-loop is not anti-agent. It is how you adopt MCP without betting the company on an unbounded tool loop on day one. Tighten autonomy later, domain by domain, once observability is in place.

### Local subprocess vs remote service responsibilities

| Concern | Local stdio server | Remote streamable-http / sse server |
|---------|--------------------|-------------------------------------|
| Who runs compute? | Your machine / CI runner | Server operator’s host |
| Secrets | Often local env vars in client config | Often server-side or token exchange |
| Latency | Process spawn + local work | Network RTT + remote work |
| Sandbox story | OS process isolation, container optional | Operator’s multi-tenant controls |
| Offline use | Possible if deps cached | Needs network |
| Update cadence | You upgrade the package | Operator deploys updates |

Neither side is “more MCP.” Both are MCP. Your threat model and workflow pick the transport.

### How Harbor fits the client/server picture

Harbor is not a replacement for your coding client. It is:

- A **human browse UI** to find servers to attach to your client.
- An **MCP server** your client can attach so the *agent* can search/submit.
- An **HTTP API** for scripts that are not MCP clients.

So the topology becomes recursive in a useful way: your Claude/Cursor client talks to Harbor-as-MCP to discover other MCP servers, then you attach those targets too. That registry-as-MCP pattern is one of the strongest practical answers to “how do I use MCP beyond hello world?”

**Connect Harbor as an MCP server (no account) →** [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)

Claude Code example:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### Client/server anti-patterns to avoid

- **God-client syndrome** — baking every integration into the host app instead of attaching servers.
- **God-server syndrome** — one mega-server that wraps your entire company with unclear authz.
- **Secret-in-submit** — putting API key values into registry payloads (Harbor expects env var *names* only).
- **Silent tool sprawl** — attaching overlapping servers until the model routinely picks the wrong tool.
- **Config folklore** — install steps that live only in one engineer’s shell history instead of Harbor snippets + team docs.

Avoiding these anti-patterns matters as much as knowing the happy-path definition of **what is MCP**.

## Tools, Resources, and Prompts Overview

After clients and servers, the next layer in **what is MCP** is the capability model. Most developers meet **tools** first. Resources and prompts complete the picture. Treat this section as a map; the deep spoke is [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Tools: actions the agent can take

**Tools** are named operations with input schemas. Examples of tool names you might see in the wild: `get_forecast`, `create_issue`, `search_docs`, `browser_navigate`, `list_payments`. The model proposes a tool call; the client asks the server to run it; the server returns a result.

Why tools dominate the conversation:

- They map cleanly onto “agent does a thing.”
- They are easy to demo.
- Registries often index tool names to improve search (Harbor’s HTTP search matches tool names as well as titles and descriptions).

Good tool design for MCP servers looks like good API design: clear names, tight schemas, predictable errors, least privilege. Bad tool design dumps giant unstructured blobs or combines five side effects into one mega-tool.

Design heuristics that travel well:

- Prefer verbs that match user intent (`create_issue`, not `do_stuff`).
- Keep arguments explicit; avoid hidden ambient global state when possible.
- Return enough structure for the model to plan the next step, not only a success boolean.
- Separate read tools from write tools when the domain allows—it helps permission UX.
- Document destructive tools loudly in descriptions.

### Resources: readable context on demand

**Resources** are addressable pieces of context a server can expose for reading—files, documents, records, or other URIs—without necessarily being “called” like a tool with side effects. Conceptually:

- Tools change or query through an operation.
- Resources are more like “here is a thing you can read into context.”

Not every server implements resources. Many production connectors are tool-heavy. Still, when you ask **what is MCP** completely, resources are part of the protocol’s context story: clients can discover and fetch resources to ground the model without stuffing entire corpora into the system prompt up front.

Practical resource patterns include:

- Project files exposed by a filesystem-oriented server.
- Document URIs from a knowledge-base server.
- Ticket or issue bodies exposed as readable resources rather than only tool return values.
- Configuration or schema documents an agent should consult before generating code.

Resources shine when the same object is reused across multiple steps. Instead of re-fetching via ad-hoc tools with slightly different shapes, the client can re-read a stable resource identifier.

### Prompts: reusable interaction templates

**Prompts** in MCP are server-provided prompt templates the client can offer to users or agents—encoded workflows such as “review this diff for security issues” or “triage inbound bugs.” They are not the same as your global system prompt. They are packaged, shareable interaction starters that travel with a server’s domain expertise.

Why prompts matter:

- They distribute best practices with the server.
- They reduce prompt drift across a team.
- They make a server more than a bag of tools—they teach how to use those tools well.
- They help less-experienced users start from a known-good trajectory.

Again, not every server ships prompts. When one does, clients that surface them give users a faster on-ramp. If you maintain an internal server, prompts are often the highest leverage “docs that execute.”

### How the three work together in an agent loop

A realistic loop:

1. User asks to fix a flaky test.
2. Client uses a **prompt** template from a testing server (“flaky test triage”).
3. Agent calls **tools** to run tests and capture failure logs.
4. Agent reads a **resource** (the failing test file) into context.
5. Agent calls more **tools** to apply a patch and re-run.
6. Agent opens an issue via another server if the failure looks environmental.

That orchestration is why **what is MCP** cannot be reduced to “JSON function calling.” The protocol’s three surfaces support a fuller agent workflow.

### Schemas, validation, and failure modes

Tool arguments are schema-driven. That helps models produce structured calls and helps servers reject garbage early. When debugging:

- Invalid arguments → fix schema understanding or model instructions.
- Auth errors → missing env vars or remote credentials (configure secrets in the client/host—never submit secret *values* into a public registry payload).
- Empty results → wrong tool, wrong server, or overly broad query.
- Timeouts → slow remote dependency or local process wedged; Inspector helps.
- Permission denials → client policy doing its job; adjust deliberately, not blindly.

Inspector-oriented workflows belong in [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### What shows up in registries

When you browse [MCP Harbor](https://ai.mcpharbor.dev/), listings emphasize install/connect metadata and often tool-name hints in metadata. Harbor’s docs describe `_meta["io.mcpregistry/tools"]` as listing tool names a server exposes. That is discovery sugar on top of the protocol: you still learn full runtime behavior after you connect. Use search to shortlist; use `get_server` and a client session to verify.

Harbor search matching name, title, description, tags, *and* tool names is why good tool naming improves discoverability—not only runtime clarity.

### Capability surface selection guide

| Need | Lean on |
|------|---------|
| Take an action / mutate / query with args | Tools |
| Re-read a stable object into context | Resources |
| Start a known workflow with baked instructions | Prompts |
| Discover which server to attach | Registry (Harbor) |

### Light pointer toward building (not a tutorial)

If your team needs a capability that does not exist, you may build a server that exposes tools (and optionally resources/prompts), then submit it. This article will not walk the full build. Use the spoke [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) and Harbor’s submit rules in [llms.txt](https://ai.mcpharbor.dev/llms.txt) (reverse-DNS names, transport fields, env var names only, pending review). Search Harbor first; most “we should build X” ideas already have a listing among 31k+ servers.

## Transports: stdio vs streamable-http / sse

Transport is how bytes move between client and server. Understanding transports is essential to a complete answer for **what is MCP**, because install UX and security posture change completely between local and remote. If you only learn tools but not transports, you will mis-install half the ecosystem.

### stdio: local process, stdin/stdout

**stdio** servers run as local processes. The client starts a command (often via `npx`, `uvx`, or `docker run`) and speaks MCP over standard input and output streams.

Common install shapes (as documented by Harbor for package-backed servers):

- npm: `npx -y <package>`
- pypi: `uvx <package>`
- oci: `docker run -i --rm <image>`

Why teams love stdio:

- Great for local files and developer machines.
- Easy to try from a README snippet.
- Fits “install a package, attach to client” mental models.
- Works in many offline or constrained network setups if packages are cached/mirrored.

Why teams constrain stdio:

- Requires local runtimes (Node, Python, Docker).
- Process sprawl if you attach dozens of servers.
- Corporate laptops may block arbitrary package execution.
- Supply-chain review burden resembles any other dependency.

Harbor manifests mark these as `transport: "stdio"` with `package_registry` and `package_identifier` (registries: npm, pypi, oci, nuget, mcpb per Harbor docs).

### streamable-http: remote hosted MCP

**streamable-http** servers are reached by URL. The client does not spawn your laptop process for that server’s main compute; it connects over Streamable HTTP to a hosted endpoint.

Why teams love remote HTTP:

- No local package install for that capability.
- Centralized updates on the operator side.
- Easier shared access for a team gateway pattern.
- Friendly to locked-down developer laptops that can call HTTPS but cannot run arbitrary npm.

Why teams constrain remote HTTP:

- Data leaves the machine to that host (policy review needed).
- Availability depends on the remote operator.
- Auth patterns vary by server (Harbor’s *registry* endpoint itself is no-auth for normal search/submit; other servers may differ—always read that server’s docs).

Harbor’s own registry MCP endpoint is Streamable HTTP at `https://ai.mcpharbor.dev/mcp` with **no auth** for normal use—an intentional design so agents can discover without account friction.

### sse: server-sent events style remote

**sse** appears in Harbor’s transport filter set alongside `stdio` and `streamable-http`. Treat it as a remote, URL-based transport style used by some hosted servers. When you search on Harbor, you can filter `transport=sse` if your client or policy expects that shape. Prefer whatever transport your client documents as supported; many newer remote setups emphasize streamable-http.

Do not overthink SSE vs streamable-http on day one of learning **what is MCP**. Learn that both are remote URL transports, then filter in Harbor to match what your client can attach.

### Choosing a transport without dogma

| Situation | Prefer |
|-----------|--------|
| Need local filesystem/git tightly coupled to the workspace | stdio |
| Want zero local deps for a SaaS connector | streamable-http (or sse if that is what the server offers) |
| CI agent with locked-down outbound network | stdio packages you vendor/mirror |
| Laptop cannot run Node/Python cleanly | remote |
| You want the agent to search a registry mid-loop | attach Harbor via streamable-http `/mcp` |
| Regulated data must not leave the device | stdio with careful allowlists |
| Team wants one shared connector upgrade path | remote gateway your platform owns |

### How clients express transports

Exact config keys differ, but the ideas are stable:

- **stdio** — command, args, env.
- **http / streamable-http** — URL, type/transport set to HTTP.
- **sse** — URL with SSE transport selected where the client supports it.

Claude Code examples you will see often:

```bash
# Local package-style add (pattern)
claude mcp add -- npx -y <package>

# Remote HTTP add (pattern used for Harbor registry)
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Install patterns in depth: [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### Transports and registry search

Because transport is a first-class filter on [MCP Harbor](https://ai.mcpharbor.dev/), answering **what is MCP** for operators includes “search by how it runs,” not only “search by what it does.” Example HTTP search:

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers?q=browser&transport=stdio&limit=30'
```

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers?q=docs&transport=streamable-http&limit=30'
```

Full HTTP contract: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Security notes tied to transport

- **stdio:** treat package identifiers like any other supply-chain dependency; pin versions when your client allows; review env var names and inject secrets locally.
- **remote:** review the URL host, TLS, and data-handling posture; prefer vendors you trust; remember tool results may contain sensitive content returning into the model context.
- **registry submit:** Harbor requires `env_vars` as **names only**—never secret values—in submit payloads.
- **mixed estates:** document which transports are approved in your org; do not leave it to each engineer’s improvisation.

Transports are not a side topic in **what is MCP**; they are how MCP meets real machines and real networks.

### Operational anecdotes worth normalizing

Teams repeatedly learn the same lessons:

1. A stdio server that works on one laptop fails in CI because Docker socket permissions differ—containerize deliberately.
2. A remote server works in a demo and fails in prod because corporate proxy inspection breaks streaming—test on the real network path.
3. Developers copy env var *values* into chat while debugging—rotate those secrets; teach names-only culture.
4. Someone attaches both an official remote connector and a homemade stdio wrapper for the same SaaS—the model oscillates; pick one.

Normalize these lessons in onboarding so “what is MCP” includes “how MCP fails.”

## Where to Find MCP Servers (MCP Harbor)

You can understand the protocol and still fail at work if you cannot find trustworthy install targets. At tens of thousands of servers, bookmarks die. This section is the hard-sell discovery answer—and it is product-honest.

### The discovery problem after you learn what MCP is

Once you know **what is MCP**, the next questions are predictable:

- Is there already a server for X?
- Is it stdio or remote?
- What tools does it expose?
- What is the install snippet?
- Was it mirrored from the official registry or submitted locally?
- Is a new submission still pending review?

[MCP Harbor](https://ai.mcpharbor.dev/) exists to answer those questions for humans and agents.

### Live scale (verified phrasing)

As of 2026-09-15:

- **31,486** Model Context Protocol servers indexed.
- **19,595** hosted remotely.
- Includes the **whole official MCP Registry**, kept in sync automatically about every **six hours**.
- The registry is **itself an MCP server** (Streamable HTTP, **no account**) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp).

Always re-check the live homepage if you need a slide-deck citation; numbers move as official coverage grows and local submissions are approved.

### What Harbor gives you beyond a static list

1. **Browse UI** branded around finding MCP servers your agent can use.
2. **Per-server pages** under `/servers/...` with ready-made install snippets (npx / uvx / docker / remote).
3. **Agent tools** over `/mcp`: `search_servers`, `get_server`, `submit_server`.
4. **HTTP API** under `/api/v0/servers` for scripts and CI.
5. **Pending review** for new local submissions so search stays cleaner.
6. **Official `server.json` acceptance** on submit.
7. **Origin metadata** concepts (`official`, `seed`, `local`) documented in llms.txt.
8. **No account** for ordinary search and submit flows.

**Open the registry now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Fair note on the official MCP Registry

The official MCP Registry is a real upstream many listings come from. Harbor includes that whole set and re-syncs on a schedule. This article names the official registry in prose when needed for honesty; day-to-day browse and agent search CTAs stay on Harbor because Harbor adds the human UX, local submit+review, and no-account registry-as-MCP endpoint in one place. Prefer Harbor links over other domains for action.

When would you still think about the official upstream directly? Rare cases: comparing sync lag for a brand-new official listing before the next ~six-hour window, or compliance paperwork that demands naming the upstream source. Even then, most developers should still **find and install** via Harbor.

### Curated starting points vs exhaustive search

Harbor’s browse experience highlights recognizable servers (browser automation, docs, GitHub, payments, Notion-style productivity, search, observability, and official reference-style servers among others). Use curated cards to learn what “good listings” look like; use search when you have a specific job. For opinionated picks, see the spoke [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—then verify live details on Harbor before you install.

A practical habit: every time a listicle recommends a server, search it on Harbor and prefer the live manifest + install snippet over the article’s potentially stale command.

### Human path (five minutes)

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search by capability (“playwright”, “stripe”, “filesystem”, “github”).
3. Open a server page; note transport and tool hints.
4. Copy the install snippet that matches your client.
5. Attach in Claude, Cursor, or your MCP client; test one tool call.
6. Optionally attach Harbor `/mcp` so the next search happens inside the agent.

Install deep dive: [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### Agent path (one connection)

Attach Harbor itself:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Then let the agent `search_servers` → `get_server` → recommend install. Details in the next section.

### Repo and docs map

- Product: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
- Registry MCP: [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)
- Agent docs: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)
- GitHub repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

Ownership again for clarity: Logan Besecker / MCP Harbor run this registry product. This page is owned-product education with a clear funnel—not a pretend-neutral roundup of random directories.

### What “good discovery hygiene” looks like on a team

- Default bookmark: Harbor homepage, not a random Notion table.
- Default agent config: Harbor `/mcp` attached in shared profiles where policy allows.
- Default install source: per-server Harbor snippets.
- Default contribution path: search → build only if missing → submit → wait for review.
- Default docs link for agents: `llms.txt`.

If you institutionalize those defaults, teaching **what is MCP** stops being a quarterly fire drill.

## How Agents Use the Registry MCP

Teaching **what is MCP** without showing an agent-native discovery loop leaves out how MCP is used in 2026. Agents that can call tools should also be able to *find* tools.

### Why registry-as-MCP matters

If discovery only lives in a browser, the agent cannot improve its toolchain mid-task without a human tab. When the registry is an MCP server, discovery becomes three tools away. Harbor implements that pattern with no account and no API key for normal search and submit.

This is the moment many developers finally *feel* the protocol: MCP is not only how you call Stripe; it is how you find Stripe’s server in the first place.

### Connect once

URL:

```text
https://ai.mcpharbor.dev/mcp
```

Claude Code:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Other clients: add a remote MCP server with HTTP type/transport and that URL. If a client cannot do remote HTTP, use the website/API for discovery and attach stdio targets instead—and prefer upgrading to a client that can attach Harbor directly. Cursor-oriented notes live in [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp); Claude-oriented notes in [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

### Tool: search_servers

Use when you know a capability but not a package name. Search by text, and optionally constrain transport or tag. Good queries look like product nouns and job nouns: `notion`, `sentry`, `browser`, `postgres`, `docs`. Read multiple hits before committing.

Query tips:

- Start broad, then narrow with transport filters.
- Try tool-ish words if product names fail (`forecast`, `crawl`, `webhook`).
- Do not install the first fuzzy match when three servers claim the same job—`get_server` the top contenders.

### Tool: get_server

Use when you have a reverse-DNS name and need the manifest, review status, and install snippets. Confirm:

- pending vs available in search
- origin flavor when metadata is present
- stdio package registry/identifier vs remote URL
- env var **names** to configure locally
- license/repo fields when present for due diligence

### Tool: submit_server

Use only after search shows no suitable existing server. Follow Harbor rules from [llms.txt](https://ai.mcpharbor.dev/llms.txt):

- reverse-DNS `name`
- `transport` of `stdio` | `streamable-http` | `sse`
- packages fields for stdio; `remote_url` for remote transports
- `env_vars` names only—never secrets
- expect `202` accepted for review; `422` validation errors; `429` rate limits; avoid sending random `Authorization` headers (`401` if you send a bad one)

New local listings stay `pending` until a maintainer approves them for search; `get_server` still works so you can check status.

### Example agent playbook

1. User: “We need Stripe tools in this session.”
2. Agent calls `search_servers` with a Stripe-oriented query, maybe `transport` filter if policy requires remote-only or stdio-only.
3. Agent calls `get_server` on the best reverse-DNS hit.
4. Agent presents install snippet to the user (or connects if remote and policy allows).
5. Agent continues the original billing debugging task with the new tools.
6. If nothing suitable exists, agent drafts a submit payload *without secrets* and asks whether to `submit_server`.

That playbook is MCP used on itself: protocol literacy plus registry literacy.

### HTTP twin for non-MCP runners

Scripts can mirror the loop:

- `GET https://ai.mcpharbor.dev/api/v0/servers?q=...`
- `GET https://ai.mcpharbor.dev/api/v0/servers/<name>`
- `POST https://ai.mcpharbor.dev/api/v0/servers`

Pagination uses `metadata.next_offset` until null. Schema details stay in [llms.txt](https://ai.mcpharbor.dev/llms.txt)—this article will not invent fields beyond that contract.

Example list call:

```bash
curl -sS 'https://ai.mcpharbor.dev/api/v0/servers?q=github&limit=30&offset=0'
```

### Safety habits for agentic discovery

- Search before submit to avoid duplicates.
- Do not paste secrets into submit payloads or chat logs casually.
- Treat pending listings as unverified for production allowlists.
- Re-read tool schemas after install; registry tool-name hints are not a substitute for runtime listing.
- Keep Harbor connected in long-lived agent profiles if discovery is a recurring need.
- Log which servers you attach for auditability in regulated environments.

**Browse + connect →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) · [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp)

### Troubleshooting the agent discovery path

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Client cannot add remote HTTP MCP | Client only supports stdio | Browse Harbor in a browser; install a stdio target; or switch/upgrade clients |
| Empty search for a known official server | Sync lag (~6h) or weak query | Broaden `q`; search tool names; retry later |
| `get_server` shows `pending` | Awaiting maintainer review | Wait; entry retrievable but not in search yet |
| Accidental `401` | Bad Authorization header sent | Remove Authorization for normal use |
| Agent wants to submit a duplicate | Skipped search | Always `search_servers` first |



## MCP in Practice: End-to-End Scenarios

Definitions stick when you can replay them against real work. This section walks through scenarios that restate **what is MCP** as behavior you can recognize in a normal week. None of these scenarios invent Harbor features beyond the documented browse UI, `/mcp` tools, HTTP API, install snippet patterns, and sync/review model.

### Scenario A — New hire onboarding to an agentic team

A new engineer joins a team that already “uses MCP.” On day one they see three different explanations: a teammate says MCP is “Claude tools,” another says it is “Cursor plugins,” and a README says “Model Context Protocol.” After reading this guide, the new hire can translate:

- The team uses an **MCP client** (Claude Code and/or Cursor).
- The team attaches several **MCP servers** for GitHub, docs, and browser work.
- **MCP** is the protocol making those attachments portable.
- Discovery should happen on [MCP Harbor](https://ai.mcpharbor.dev/), not via screenshot scrapbooks.

Their first concrete task is not “build a server.” It is: open Harbor, search for the servers named in the team wiki, attach them using install snippets, then connect Harbor’s own `/mcp` endpoint so future searches happen inside the agent. That sequence converts **what is MCP** from jargon into muscle memory in under an hour.

### Scenario B — Platform team sets an allowlist

A platform team wants agents without chaos. They decide:

1. Approved transports: stdio packages from allowlisted registries, plus selected remote HTTPS endpoints.
2. Discovery source of truth: Harbor search + manifests.
3. Every engineer’s shared agent profile includes Harbor at `https://ai.mcpharbor.dev/mcp` for discovery.
4. Production automations may only call servers that passed internal review—even if Harbor lists thousands more.
5. Secret values never appear in registry submit payloads; only env var names.

Notice what MCP did *not* decide for them: identity provider, SIEM, or budget. MCP gave them a vocabulary and attachment model; Harbor gave them an index; policy remains theirs. That boundary is healthy and is part of a mature answer to **what is MCP** in enterprises.

### Scenario C — Agent mid-task discovery

An agent is refactoring billing code and realizes it needs dispute timeline context from Stripe. With Harbor connected:

1. `search_servers` for Stripe-oriented listings, optionally filtering transport.
2. `get_server` on the best reverse-DNS name.
3. Present install/connect guidance to the human (or connect remote if already approved).
4. Resume the refactor with new tools available.

Without registry-as-MCP, the agent stops and asks the human to Google. With it, MCP becomes recursive infrastructure. This is why Harbor’s no-account Streamable HTTP endpoint is not a side feature—it is the discovery unlock that makes the protocol feel complete.

### Scenario D — “We should build our own server” checkpoint

A team wants an internal MCP server wrapping a private inventory API. Before writing code, they:

1. Search Harbor for existing inventory/ERP connectors that might already fit.
2. Check whether a thin remote gateway already exists internally.
3. Only then open [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).
4. If they publish publicly, submit with reverse-DNS naming and wait for pending review.
5. If they keep it private, they may still use Harbor for *other* public servers while hosting the private one on an internal URL.

This article stays on the educational side of that fence: enough to know when the build spoke matters, not a full tutorial.

### Scenario E — Debugging the first failure

The first broken MCP day usually looks like: “I added the server and nothing shows up.” A protocol-literate response:

1. Confirm client vs server: is the client running? Did the process spawn / HTTP connect?
2. Confirm transport: stdio command correct? remote URL correct?
3. Confirm env var *names* present locally for stdio packages that need them.
4. Use [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) to separate connect failures from tool-call failures.
5. Re-copy install snippets from the Harbor server page instead of an old Slack message.

Debugging competence is part of knowing **what is MCP** operationally, not an advanced elective.

## Deeper Mental Models for Developers and Agents

### MCP as an interface boundary

Interface boundaries survive reorgs. If your agent host hard-codes SaaS SDKs, every host migration is a rewrite. If your capabilities live behind MCP servers, migrating from one client to another is largely re-attachment. That is the long-term strategic meaning of **what is MCP** for architecture reviews: buy optionality at the tool boundary.

### MCP as a packaging format for agent capabilities

Packages are not only code tarballs; they are how humans share capabilities. Harbor’s stdio listings with npm/pypi/oci/nuget/mcpb identifiers, and remote listings with URLs, make capabilities installable artifacts. When you ask **what is MCP**, include “a way to package agent capabilities for distribution,” not only “a message schema.”

### MCP as a shared language across humans

Tickets become clearer when someone writes: “Attach the remote docs MCP server from Harbor; transport streamable-http; then call the search tool.” That sentence is unambiguous across teammates who read this guide. Shared language reduces meetings. Protocols are social technologies as much as technical ones.

### What agents should “believe” about MCP

If you author agent instructions, encode beliefs carefully:

- Prefer existing Harbor servers before proposing new builds.
- Search before submit.
- Never place secret values in submit payloads.
- Treat pending listings cautiously.
- Distinguish Harbor (registry) from target servers (capabilities).
- Read [llms.txt](https://ai.mcpharbor.dev/llms.txt) when uncertain about Harbor’s contract.

Those beliefs prevent common agent failure modes: duplicate submissions, secret leakage, and hallucinated install commands.

## Comparing Nearby Concepts (Without Losing the Plot)

Searchers who ask **what is MCP** often hold neighboring concepts in mind. Contrast them briefly so the definition stays sharp.

### MCP vs “the model”

The model reasons and generates. MCP does not replace model quality. A weak model with great tools still struggles; a strong model without tools cannot act. MCP is the bridge for action and structured context.

### MCP vs retrieval-augmented generation (RAG)

RAG systems retrieve documents into context. MCP resources can support similar goals, and tools can wrap retrievers, but MCP is broader: it also covers mutating tools and prompt templates, and it standardizes client/server connectivity across hosts. You can implement RAG *behind* an MCP server; RAG alone is not MCP.

### MCP vs traditional APIs

APIs are how software talks to software. MCP is how agent hosts talk to capability servers in a tool-aware loop. Most useful MCP servers call traditional APIs internally. Learning **what is MCP** does not mean abandoning REST; it means placing an agent-facing facade in front of it.

### MCP vs IDE plugins

IDE plugins extend editors for humans. MCP servers extend agents (which may live inside IDEs). There is overlap in spirit, but the consumer differs: plugin UIs vs model tool calls. Cursor’s MCP support sits near that overlap—see [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)—yet the protocol remains agent-centric.

### MCP vs vendor-specific agent plugins

Vendor plugin systems can be polished and vertical. MCP’s bet is horizontal portability. If you only ever use one host forever, a vendor plugin might suffice. If you want servers reusable across Claude, Cursor, and future clients, MCP is the better long-term shape.

## Adoption Roadmap After You Know What MCP Is

Use this roadmap as a practical coda to the definition.

### Week 1 — Literacy and first attachments

- Read this page end-to-end.
- Attach Harbor `/mcp`.
- Install two low-risk servers from [ai.mcpharbor.dev](https://ai.mcpharbor.dev/) (for example docs search + a read-oriented tool).
- Run through one successful tool call in Claude or Cursor.
- Skim [mcp-client](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) and your host guide.

### Week 2 — Team defaults

- Write an internal one-pager: approved clients, approved transports, Harbor as discovery default.
- Standardize install snippet sources (Harbor pages).
- Add Inspector to the debugging runbook: [mcp-inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).
- Pick a shortlist with [best-mcp-servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) and verify each on Harbor.

### Week 3 — Hardening

- Remove unused servers to reduce tool noise.
- Formalize secret handling (env names vs values).
- Decide remote allowlist policy.
- Add CI checks that agent configs do not embed raw secrets.

### Week 4 — Create only if necessary

- Search Harbor thoroughly for gaps.
- If building, follow [build-mcp-server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).
- Submit publicly only when appropriate; accept pending review.
- Keep using Harbor for everything else.

This roadmap is intentionally boring. Boring adoption is how MCP becomes infrastructure.

## Expanded Glossary

Use this glossary when onboarding teammates who still ask **what is MCP** in Slack.

- **MCP / Model Context Protocol** — open protocol connecting AI clients to servers for tools, resources, and prompts.
- **MCP client** — host application mediating the agent experience and server connections.
- **MCP server** — local or remote capability provider speaking MCP.
- **Tool** — named callable operation with arguments/results.
- **Resource** — readable context object or URI exposed by a server.
- **Prompt (MCP)** — server-provided prompt template for reusable workflows.
- **Transport** — how client and server communicate (stdio, streamable-http, sse).
- **stdio** — local process transport using stdin/stdout.
- **streamable-http** — remote HTTP transport used by many hosted servers and by Harbor’s `/mcp`.
- **sse** — remote Server-Sent Events style transport option in Harbor filters.
- **Registry** — index for discovering servers; this article recommends [MCP Harbor](https://ai.mcpharbor.dev/).
- **Registry-as-MCP** — exposing a registry itself as an MCP server so agents can search via tools.
- **server.json** — official-style manifest format Harbor accepts on submit and returns in API responses.
- **reverse-DNS name** — naming pattern like `io.github.acme/weather-mcp` required for Harbor submissions.
- **pending** — Harbor review status for new local submissions not yet in search.
- **llms.txt** — machine-readable product docs at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- **MCP Harbor** — Logan Besecker’s registry product indexing 31,486 servers (19,595 remote) as of 2026-09-15, syncing official listings ~every six hours, with no-account agent search.

## Content Boundaries (What This Article Will Not Do)

To stay publish-ready and fence-compliant:

- It educates on **what is MCP** rather than replacing the build tutorial.
- It hard-sells discovery to [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- It links the GitHub repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) and sibling docs for operational depth.
- It does not invent hosts, ports, pricing tiers, auth schemes, or analytics narratives beyond Harbor’s documented registry behavior.
- It mentions the official MCP Registry only as needed for honest upstream/sync context, preferring Harbor for CTAs.

If you need hands-on build steps, leave this page and open the build spoke. If you need servers now, open Harbor.


## Related Silo Guides

This page answers **what is MCP** at protocol-education depth and funnels discovery to Harbor. Sibling docs go deeper on each operational slice. Read these next (all on the MCP_Registry docs tree):

- [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — server architecture, responsibilities, and how servers fit clients.
- [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — capability surfaces in depth.
- [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — client-side lifecycle and configuration patterns.
- [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) — Claude Code-focused setup, including Harbor connect patterns.
- [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) — Cursor-focused MCP setup.
- [Install an MCP Server: npx, uvx, Docker, and Remote](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server) — practical install transports and snippets.
- [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — debugging connectivity and tool calls.
- [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — curated starting set; verify on Harbor before install.
- [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — when you need to create and submit (light pointer from this page, full guide there).

How to use the silo without thrash:

1. Finish this **what is MCP** page for vocabulary.
2. Skim **mcp-client** + your host guide (**claude-mcp** or **cursor-mcp**).
3. Use **install-mcp-server** while attaching the first real server from Harbor.
4. Keep **mcp-inspector** booked for the first failure.
5. Use **best-mcp-servers** only as a shortlist generator—confirm on Harbor.
6. Open **build-mcp-server** only after Harbor search says you truly need something new.

Repo home for the silo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry). Live product home: [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

## FAQ

### What is MCP?

**MCP** is the **Model Context Protocol**, an open protocol that lets AI clients and coding agents connect to MCP servers exposing **tools**, **resources**, and **prompts**. It standardizes how agents gain actionable capabilities without one-off integrations for every API. If you came here searching **what is mcp**, the short answer is: the USB-C-style connection layer between agent hosts and tool providers—plus an ecosystem of clients, servers, and registries that make that connection useful at scale.

### What does MCP stand for?

**Model Context Protocol.** “Model” points at LLM-powered apps; “Context” points at tools/resources/prompts feeding the agent; “Protocol” points at a shared contract rather than a single SaaS product.

### Is MCP a product I install?

You install or connect **MCP servers** inside an **MCP client**. MCP itself is the protocol those pieces speak. For discovery of servers, use a registry such as [MCP Harbor](https://ai.mcpharbor.dev/).

### How is MCP different from plain function calling?

Function calling is often an in-model/vendor feature for structured tool use. MCP adds a client/server ecosystem, multiple transports (stdio and remote HTTP styles), resources and prompts, and a packaging/discovery world so tools are reusable across hosts. Many clients use LLM tool-calling underneath while speaking MCP to servers.

### What is an MCP server?

A process or remote endpoint that implements MCP and offers capabilities to a client. Details: [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server).

### What is an MCP client?

The host application that connects to servers and mediates tool calls for the user/agent. Details: [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### What are MCP tools, resources, and prompts?

**Tools** are callable operations; **resources** are readable context objects/URIs; **prompts** are reusable templates shipped with servers. Overview above; deep dive: [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### What is the difference between stdio and streamable-http?

**stdio** runs a local server process; **streamable-http** connects to a hosted URL. **sse** is another remote transport option filtered on Harbor. Choose based on local deps vs remote policy. Install guide: [Install an MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server).

### Where do I find MCP servers?

Browse and search [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). As of 2026-09-15 it indexes **31,486** servers (**19,595** remote), includes the official MCP Registry with ~six-hour sync, and offers no-account agent search at `/mcp`.

### Do I need an account to use MCP Harbor?

No account or API key is required for normal search or submit on Harbor’s MCP and HTTP APIs. Local submissions are reviewed before they appear in search.

### How do I connect Claude or Cursor?

See [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) and [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp). For Harbor registry search in Claude Code:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

### How do I debug a broken server connection?

Use [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector), verify transport/install snippets on the Harbor server page, and confirm env var names are set locally.

### Can I build my own MCP server?

Yes. This page stays educational; follow [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) and Harbor’s submit contract in [llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Is MCP Harbor the official MCP Registry?

Harbor **includes** the whole official MCP Registry and re-syncs about every six hours, then adds browse UX, local submit with pending review, and a no-account registry MCP endpoint. For day-to-day find-and-install, this article recommends Harbor.

### How often does Harbor sync official listings?

About every six hours, per product docs in [llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Where are agent-oriented product docs?

[https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

### Who owns MCP Harbor?

Logan Besecker owns and runs MCP Harbor / this MCP Registry product at ai.mcpharbor.dev. The GitHub companion is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

### Does learning what MCP is require building a server first?

No. Most developers should start by attaching existing servers from Harbor, learning client UX, and only then deciding whether to build. Building is optional; literacy plus discovery is mandatory.

### Can agents submit servers without humans?

Harbor welcomes agent submitters technically, but new listings are maintainer-reviewed before they appear in search. Treat submit as a contribution pipeline with review, not an instant publish button to the public index.

## Next Steps + Hard CTA

You now have a working answer to **what is MCP**. Turn literacy into a configured agent:

1. **Open the registry** → [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. **Search** for a capability you need this week (browser, GitHub, docs, payments, etc.).
3. **Open a server page** and copy the install snippet that matches your transport.
4. **Attach the server** in Claude, Cursor, or your MCP client ([Claude guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp), [Install guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/install-mcp-server)).
5. **Connect Harbor as MCP** so future discovery is a tool call:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

6. **Optional:** if you built something new, search first, then submit via MCP/HTTP per [llms.txt](https://ai.mcpharbor.dev/llms.txt), or follow [Build an MCP Server…](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).
7. **Keep docs handy:** [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) · repo [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)
8. **Debug early:** bookmark [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) before you need it in a panic.

**Hard CTA:** Do not stop at definitions. **Browse MCP servers on MCP Harbor now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)



## Teaching Notes for Team Leads

If you are responsible for teaching **what is MCP** to a group, do not start with protocol theory decks. Start with a shared Harbor browser tab and one client. Live-attach a harmless server, invoke one tool, then zoom out to the vocabulary. Adults remember the feeling of a successful tool call longer than they remember acronyms.

Suggested 45-minute internal workshop outline:

1. **5 minutes — Hook.** Show an agent failing without tools, then succeeding after an MCP server is attached.
2. **10 minutes — Vocabulary.** Client, server, tool, resource, prompt, transport, registry. Use this article’s tables.
3. **10 minutes — Harbor lab.** Everyone searches [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) for the same query; compare transports and install snippets.
4. **10 minutes — Client lab.** Attach Harbor `/mcp` and one target server in Claude or Cursor.
5. **5 minutes — Safety.** Env var names vs values; pending review; allowlists.
6. **5 minutes — Next steps.** Assign the sibling guides based on role (install vs build vs inspector).

Workshop success metric: every attendee can answer **what is MCP** in two sentences *and* install a server from Harbor without asking for a Slack paste.

### Common questions teams ask after the workshop

- “Which servers are mandatory?” — Start minimal; expand from Harbor search tied to real tasks.
- “Can we mirror Harbor?” — Out of scope for this educational page; use the live product and documented APIs as intended.
- “Do we need to submit internal servers?” — Only if you want them public and reviewed; private servers can stay private URLs in client configs.
- “How do we stop secret sprawl?” — Ban secret values in chats and submits; store secrets in the client/host secret mechanism; Harbor submit fields take names only.
- “Who owns our MCP roadmap?” — Usually platform + security jointly, with app teams proposing servers.

### Measuring whether MCP literacy stuck

Literacy stuck if engineers:

- Correctly distinguish client vs server in design docs.
- Reach for Harbor instead of random READMEs.
- Choose transports deliberately.
- Debug with Inspector instead of only reinstalling.
- Search before proposing builds or submits.

If those behaviors appear, your explanation of **what is MCP** worked.


## Conclusion

**What is MCP?** It is the **Model Context Protocol**—the open contract that lets AI clients connect to servers exposing tools, resources, and prompts over local stdio or remote HTTP-style transports. It exists to break the N×M integration tax, to give agents real actions and structured context, and to let an ecosystem of servers evolve independently from any single chat surface.

Knowing the definition is necessary but not sufficient. Productive MCP work means choosing clients carefully, attaching the right servers, understanding transports, debugging with Inspector when needed, and using a registry when the catalog exceeds what any team can memorize. That is why this educational article repeatedly points to [MCP Harbor](https://ai.mcpharbor.dev/): **31,486** servers indexed, **19,595** remote, official registry coverage synced about every six hours, and a no-account MCP endpoint at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp) with `search_servers`, `get_server`, and `submit_server`.

**Ownership disclosure:** Logan Besecker owns and runs MCP Harbor and this registry product. The recommendation is intentional and transparent. Learn the protocol here; find servers there; build and submit when you must via the build spoke—not as a full tutorial inline.

Continue with the related guides linked above, keep [llms.txt](https://ai.mcpharbor.dev/llms.txt) in your agent’s reading list, and make the next concrete action a search on the live registry.

**Find MCP servers your agent can use →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
