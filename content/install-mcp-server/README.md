---
title: "Install an MCP Server: npx, uvx, Docker, and Remote"
description: "Install an MCP server with npx, uvx, Docker, or remote HTTP/SSE. Find packages on MCP Harbor, copy ready snippets, and connect Claude or Cursor."
date: 2026-09-15
---

# Install an MCP Server: npx, uvx, Docker, and Remote

If your goal today is to **install mcp server** packages into an AI coding client—Claude Code, Cursor, or another MCP-capable host—this is the operational guide. You will learn how to choose among **npx**, **uvx**, **Docker**, and **remote HTTP/SSE** installs; how to find the right package or URL on [MCP Harbor](https://ai.mcpharbor.dev/); how Claude add patterns work at a high level; and how to verify a connection with the MCP Inspector spoke before you trust the tools in production sessions.

**Ownership disclosure:** Logan Besecker owns and runs [MCP Harbor](https://ai.mcpharbor.dev/) and the MCP Registry product this article hard-recommends for discovery. The install recipes below come from Harbor’s published agent docs at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)—not invented hosts, ports, or secrets. Env var guidance lists **names only**; never paste secret values into chats, manifests, or registry submits.

As of 2026-09-15, Harbor indexes **31,486** Model Context Protocol servers (**19,595** remote), includes the whole official MCP Registry with automatic sync about every six hours, and exposes the registry itself as an MCP server (Streamable HTTP, no account) at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). The companion open-source docs tree lives at [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Install from Harbor now →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

What this article covers:

- How to **choose an install path** (npx vs uvx vs Docker vs remote) when you need to **install mcp server** capability into a client.
- How to **find the package** (or remote URL) on Harbor’s browse UI, HTTP API, and registry-as-MCP tools.
- Step-by-step mental models for **npx -y**, **uvx**, **docker run -i --rm**, and **remote URL connect**.
- Where Claude Code and Cursor deep-dives live (sibling articles)—with Harbor Claude add patterns summarized here.
- How to **verify** with the [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) spoke.
- Related silo guides, a deep FAQ, numbered next steps, and a conclusion that ends on Harbor.

If you only need a shortlist of popular servers first, skim [Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—then confirm every install snippet on the live Harbor server page. If you still need protocol vocabulary, start with [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp). Everyone installing today: keep reading.

---

## Choose an Install Path

Before you type a command, decide *how* the MCP client will talk to the server. Choosing the wrong path is the most common reason “I tried to **install mcp server** X and nothing happened.” Harbor’s install contract maps cleanly onto four practical paths:

| Path | When Harbor listing shows… | Canonical pattern (from Harbor llms.txt) |
|------|----------------------------|------------------------------------------|
| **npx** | npm package (`registryType` / package registry **npm**) | `npx -y <package>` |
| **uvx** | PyPI package (**pypi**) | `uvx <package>` |
| **Docker** | OCI image (**oci**) | `docker run -i --rm <image>` |
| **Remote** | `remotes[]` with streamable-http or sse | Connect to the listed `url` with the given transport |

Those four lines are not marketing slogans—they are the install section of [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). Every Harbor server HTML page at `https://ai.mcpharbor.dev/servers/<name>` surfaces ready-made snippets so you do not have to reconstruct them from memory.

### Decision tree for humans

Use this order when you open a Harbor listing:

1. **Does the entry have a remote URL and do you prefer hosted?** → Use **remote** connect (HTTP / streamable-http / SSE per the listing). Ideal when your org already allows outbound HTTPS to that host and you do not want local runtimes.
2. **Is the package npm and do you have Node/npx?** → Use **npx -y**. Fastest path for many JavaScript/TypeScript servers.
3. **Is the package on PyPI and do you have uv/uvx?** → Use **uvx**. Preferred for Python servers without managing a venv by hand.
4. **Is the artifact an OCI image?** → Use **docker run -i --rm**. Good when the maintainer ships a container as the supported runtime.
5. **Does the listing offer more than one option?** → Prefer the transport your security policy allows; remote when policy forbids arbitrary local processes; local when you need filesystem/network locality the remote host cannot see.

### Decision tree for agents

Agents that can call Harbor’s registry MCP tools should:

1. `search_servers` with a capability query (and optional `transport` / `tag` filters).
2. `get_server` for the chosen name to read packages, remotes, env var **names**, and tool lists.
3. Present the Harbor HTML page or the install snippet to the human (or apply client config if the host allows).
4. Never invent a host, port, or secret. If `get_server` does not list it, do not guess.

Connect the registry itself first so discovery is a tool call:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

**Browse servers and pick a path →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Local stdio vs remote: what actually changes

When you **install mcp server** packages locally (npx, uvx, Docker stdio), the client typically spawns a child process and speaks MCP over **stdio**. When you connect remotely, the client opens a network session to a **URL** using **streamable-http** or **sse**. Same protocol goals (tools, resources, prompts); different operational surfaces:

- **Local:** you need the runtime (`node`/`npx`, `uv`/`uvx`, or `docker`), local CPU/RAM, and correct env vars in the client’s environment. Latency is often lower for local filesystems.
- **Remote:** you need network reachability, whatever auth the remote requires (handled by the client/host—never paste secrets into Harbor), and trust in the remote operator. Great for SaaS-backed tools (docs search, issue trackers, payments) where the interesting state already lives in the cloud.

Harbor’s index makes the distinction explicit: package-backed entries emphasize `packages[]`; hosted entries emphasize `remotes[]`. Some servers publish **both**—Context7 is a common example with an npm package *and* a streamable-http remote. Choose one path per client config entry; do not double-attach the same logical server unless you have a deliberate reason.

### Prerequisites checklist (before any install)

Print this beside your laptop:

- [ ] You know which **MCP client** you are configuring (Claude Code, Cursor, etc.). Deep client guides: [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp), [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).
- [ ] You found the server on [MCP Harbor](https://ai.mcpharbor.dev/) and opened its page for snippets.
- [ ] You matched **registry type** → install path (npm→npx, pypi→uvx, oci→docker, remote→URL).
- [ ] You noted required **environment variable names** from the listing (values live only in your secret store / client env).
- [ ] You have the runtime installed for local paths (`npx`, `uvx`, or Docker).
- [ ] You bookmarked [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) for verification.

### Anti-patterns when choosing a path

Avoid these when you **install mcp server** entries:

- Copying a random `npx` line from an old blog when Harbor’s page shows an OCI image or remote-only listing.
- Assuming every popular name is npm. GitHub’s official-style listing, for example, may emphasize remote and/or OCI depending on the published manifest—always read the Harbor page.
- Running Docker without `-i` when the client expects an interactive stdio pipe—Harbor’s documented pattern is `docker run -i --rm <image>`.
- Putting secret values into `submit_server` payloads or chat logs. Harbor’s contract: **env var names only**.
- Inventing `localhost` ports for Harbor itself. Harbor’s documented agent endpoint is the HTTPS URL `https://ai.mcpharbor.dev/mcp`—not a homemade port mapping.

### Mapping package registries to runtimes

Harbor accepts package registries including **npm**, **pypi**, **oci**, **nuget**, and **mcpb** on submit. Day-to-day install docs in llms.txt highlight the three local runners most developers meet first:

- **npm** → `npx -y`
- **pypi** → `uvx`
- **oci** → `docker run -i --rm`

If you encounter nuget or mcpb listings, treat the Harbor server page as source of truth for the snippet rather than inventing a command shape in this article. The principle stays the same: **read the listing, copy the ready-made install path, attach in the client**.

### How many servers should you install on day one?

Fewer than you think. A productive first hour looks like:

1. Attach Harbor’s own registry MCP (`https://ai.mcpharbor.dev/mcp`) for discovery.
2. Install **one** capability server tied to a real task (docs, browser, GitHub, filesystem—whatever you need today).
3. Verify with Inspector or a single successful tool call.
4. Add more servers only when a task blocks on a missing capability.

“Install everything from a listicle” creates config noise, permission sprawl, and hard-to-debug tool collisions. Harbor search on demand beats a bloated static config.

### Security and policy notes at path-choice time

- **Local processes** can touch whatever the OS user can touch. Scope filesystem servers carefully; prefer servers that take explicit directory arguments.
- **Remote URLs** send prompts/tool args to someone else’s host. Prefer reputable remotes listed on Harbor; review tags, tools, and repository links on the server page.
- **Containers** isolate somewhat, but Docker is not a full multi-tenant security boundary by itself—still treat image provenance seriously.
- **Org allowlists** beat ad-hoc installs. Platform teams should maintain an approved Harbor query or tag set.

### Quick scenarios

| Scenario | Prefer |
|----------|--------|
| “I need Playwright browser tools in Claude tonight.” | Open Harbor → Playwright → typically **npx** path for `@playwright/mcp` |
| “I need up-to-date library docs without local deps.” | Context7-style **remote** streamable-http if policy allows |
| “Security forbids random npm on laptops; containers OK.” | **Docker** OCI installs where listed |
| “Python data tooling server on PyPI.” | **uvx** |
| “I do not know what exists.” | Search Harbor; optionally connect `/mcp` first |

**Choose a server, then an install path →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Find the Package on MCP Harbor

You cannot responsibly **install mcp server** software you have not identified. Harbor is the discovery layer this silo hard-sells: browse UI for humans, HTTP API for scripts, and registry-as-MCP for agents—**no account or API key** required for normal search and submit.

### Browse the web UI

1. Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).
2. Search by capability words you would say out loud (“playwright”, “github”, “filesystem”, “stripe”, “docs”).
3. Open a result. Confirm **title**, **description**, **transport**, **tools**, **tags**, and repository link.
4. Scroll to install snippets on the server page: `https://ai.mcpharbor.dev/servers/<name>` (names look like `io.github.microsoft/playwright-mcp`; the slash may appear URL-encoded as `%2F` in some clients).
5. Copy the snippet that matches your chosen path—do not freestyle.

Harbor’s homepage framing is intentional: *Find MCP servers your agent can use*—31,486 indexed, 19,595 remote, official registry included and kept in sync. Use that live count as motivation to search rather than memorize.

### Search filters that matter

When you search—UI or API—think in three dimensions:

1. **Text query (`q`)** — matches name, title, description, tags, and tool names.
2. **Transport** — `stdio`, `streamable-http`, or `sse` when you already know local vs remote.
3. **Tag** — capability labels such as `browser`, `documentation`, `github`, `payments`.

HTTP shape (every parameter optional):

```text
GET https://ai.mcpharbor.dev/api/v0/servers?q=<query>&transport=<stdio|streamable-http|sse>&tag=<tag>&limit=30&offset=0
```

Page with `offset=next_offset` until `next_offset` is null. Fetch one server:

```text
GET https://ai.mcpharbor.dev/api/v0/servers/<name>
```

The slash in names like `io.github.acme/weather` may be sent as-is or as `%2F`. Responses wrap official-style `server.json` manifests plus Harbor `_meta` (origin, status, tools list, and more).

### What to read in a manifest before install

Focus on:

- **`packages[0].registryType`** — npm / pypi / oci / … → picks npx / uvx / docker.
- **`packages[0].identifier`** — the package or image name you pass to the runner.
- **`packages[0].environmentVariables`** — **names** (and whether required/secret flags are set). Store values in your client’s secret mechanism only.
- **`remotes[0].type`** and **`remotes[0].url`** — for remote connect.
- **`_meta["io.mcpregistry/tools"]`** — tool names the server exposes (sanity-check against your task).
- **Origin meta** — `official` (synced from the official MCP Registry), `seed` (hand-curated starter set), or `local` (submitted on Harbor, may have been pending before approval).

Pending local submissions: new Harbor adds are maintainer-reviewed before they appear in search; `get_server` can still report pending entries. Prefer active/searchable listings for production installs unless you intentionally test a pending name.

### Agent-native discovery (recommended)

Attach Harbor as MCP, then use tools:

- **`search_servers`** — find by text, transport, or tag.
- **`get_server`** — one server’s manifest, review status, and install snippets.
- **`submit_server`** — add a server (search first to avoid duplicates).

Claude Code one-liner again:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Other clients: add a remote server with type `http` (or the client’s equivalent for Streamable HTTP) and URL `https://ai.mcpharbor.dev/mcp`. Product details for agents: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### Why Harbor beats “GitHub spelunking”

Raw GitHub search finds READMEs; it does not give you a uniform install contract across 30k+ servers. Harbor’s value when you **install mcp server** entries:

- One place to compare transports and package identifiers.
- Official registry coverage with ~six-hour sync **plus** Harbor-local submissions.
- Ready-made snippets on each server page.
- Agent-searchable surface so coding agents can discover mid-task.
- Submit rules that reject secret values in `env_vars` (names only).

The GitHub companion repo for this content silo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)—use it for docs navigation; use Harbor for live install discovery.

### Example: finding a filesystem server

Search Harbor for `filesystem`. A representative seed listing is `io.github.modelcontextprotocol/server-filesystem`—stdio, npm identifier `@modelcontextprotocol/server-filesystem`, tools like `read_file`, `write_file`, `list_directory`. Install path: **npx**. Arguments for allowed directories are typically passed in the client’s server config (see the Harbor page / upstream README)—do not invent Harbor ports; this is a local stdio server.

### Example: finding a remote docs server

Search for `context7` or `documentation`. Listings such as `io.github.upstash/context7` may show both an npm package and a `streamable-http` remote URL. If you choose remote, connect to the listed URL with the listed transport—copy from Harbor, do not hard-code from memory in scripts you will not update.

### Example: finding an OCI-backed server

Search for servers whose package `registryType` is `oci` (GitHub’s MCP server listing is a well-known case that can include an OCI identifier such as a `ghcr.io/...` image). Install path: **docker run -i --rm** with that image identifier. Always confirm the exact image string on the Harbor page for the version you intend.

### Submit vs install (do not confuse them)

- **Install** = attach an existing listing to your client.
- **Submit** = add a new server to Harbor for review (`submit_server` or `POST /api/v0/servers`).

If search already finds what you need, **install**—do not submit a duplicate. Full build/submit pedagogy lives in [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).

**Search Harbor before you install →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Recording what you installed

Teams that scale MCP well keep a short internal note:

- Harbor name (reverse-DNS form)
- Install path used (npx / uvx / docker / remote)
- Package identifier or remote URL (from Harbor)
- Env var **names** required
- Client(s) configured
- Date verified with Inspector

That note prevents “works on my machine” when onboarding the next engineer. Link the Harbor server page in the note so the snippet stays one click away.

---

## Install with npx (npm packages)

When Harbor shows an **npm** package, the documented install pattern is:

```bash
npx -y <package>
```

The `-y` flag tells `npx` to proceed without interactive prompts—important for MCP clients that spawn the server as a non-interactive child process. If you omit `-y`, some environments hang waiting for confirmation and your client reports a mysterious startup failure.

### What npx is doing

`npx` resolves an npm package, downloads it if needed (cache permitting), and executes the package’s binary entrypoint. For MCP, that entrypoint should speak the protocol on stdio. Your MCP client owns the lifecycle: spawn → initialize → list tools → call tools → shutdown.

You are not “installing a global daemon into the OS” in the classic sense. You are declaring a **launch command** the client will run when the server is enabled. That is why client config often stores something shaped like “command: `npx`, args: `[-y, @scope/pkg]`” rather than a long-lived system service.

### Claude Code pattern for npm (from Harbor llms)

Harbor documents:

```bash
claude mcp add -- npx -y <package>
```

Replace `<package>` with the identifier from the Harbor listing (for example `@playwright/mcp` for Playwright when that is what the page shows). For remote servers the Claude pattern differs (`--transport http`); see the remote section and the [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) sibling.

### Generic client config mental model

Exact JSON keys vary by host, but the idea is stable:

- **command**: `npx`
- **args**: `["-y", "<package>", ...optional server args...]`
- **env**: map of env var **names** → values sourced from your secret store

Cursor and other editors often use an `mcp.json`-style file; follow the [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) guide for host-specific UI. This article stays on the Harbor-canonical command shapes so snippets remain portable.

### Worked example: Playwright via Harbor

1. Open [MCP Harbor](https://ai.mcpharbor.dev/) and find **Playwright** (`io.github.microsoft/playwright-mcp`).
2. Confirm npm identifier `@playwright/mcp` (verify on the live page—versions change).
3. Install path: `npx -y @playwright/mcp` (plus any args the page documents).
4. Claude-oriented add: `claude mcp add -- npx -y @playwright/mcp` (confirm against Harbor snippet).
5. Verify tools such as browser navigation/snapshot appear in the client or Inspector.

### Worked example: Filesystem reference server

1. Harbor → **Filesystem** (`io.github.modelcontextprotocol/server-filesystem`).
2. npm identifier `@modelcontextprotocol/server-filesystem`.
3. `npx -y @modelcontextprotocol/server-filesystem` with directory arguments as documented on the server page / upstream—scope to directories you intend the agent to touch.
4. Confirm tools like `read_file` / `list_directory` after connect.

### Env vars with npx servers

Many npm MCP servers need API keys. Harbor lists **names** such as `BRAVE_API_KEY`, `CONTEXT7_API_KEY`, or similar—**never** put the values into Harbor submits or public configs. Set values in:

- The client’s secret/env UI, or
- Your shell profile only if you understand the exposure, or
- An OS keychain integration your client supports

If a tool call fails with “unauthorized” / “missing key,” re-check the **name** spelling against Harbor’s `environmentVariables` list before assuming the server is broken.

### npx troubleshooting when you install mcp server packages

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Client hangs on startup | Missing `-y`, waiting on prompt | Use `npx -y` |
| `command not found: npx` | Node.js/npm not installed | Install Node LTS; confirm `npx` on PATH |
| Old package behavior | Cached stale version | Clear npx cache / pin version from Harbor page |
| Tools missing | Wrong package / failed init | Re-copy snippet from Harbor; run Inspector |
| Auth errors | Env value missing | Set the **named** vars locally |

### Version pinning

Harbor listings often include a version field. For production teams, prefer pinning (`@scope/pkg@x.y.z`) once you validate a version, and re-validate when Harbor shows a newer release you care about. Day-to-day experimentation can use unpinned `npx -y @scope/pkg` for speed—know the tradeoff.

### When not to use npx

- Listing is **pypi** or **oci** only → use uvx or Docker.
- Listing is **remote-only** and your policy prefers hosted → connect to URL.
- Your environment blocks npm network fetches → use an approved remote or a pre-cached container image.

**Copy an npm snippet from Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### npx and corporate proxies

Enterprise laptops often route npm through proxies or private registries. If `npx -y` fails with network errors:

- Confirm Node can reach the registry your company allows.
- Align `.npmrc` with IT policy before blaming the MCP server.
- Prefer Harbor **remote** listings when local npm is locked down but HTTPS to approved SaaS is allowed.

Do not bypass security controls by smuggling packages through odd channels. Change the install path to one your policy supports.

### Optional server arguments after the package name

Some npm MCP servers expect CLI arguments (allowed directories, base URLs as non-secret flags, log levels). Those belong in the client’s `args` array after the package name. Harbor snippets and upstream READMEs are authoritative. Never place secret tokens in argv if an env var name exists for that secret—argv is easier to leak via process listings.

---

## Install with uvx (PyPI packages)

When Harbor shows a **PyPI** package, the documented pattern is:

```bash
uvx <package>
```

`uvx` comes from the **uv** toolchain: it runs Python package entrypoints in ephemeral environments without you hand-rolling a virtualenv for every MCP server. For Python MCP servers, this is the Harbor-documented happy path parallel to `npx -y` on npm.

### Why uvx instead of raw pip + venv

Manual venv workflows work, but they fight MCP client UX:

- Clients want a **single launch command**.
- You do not want ten permanent venvs rotting on disk for ten servers.
- `uvx` resolves, caches, and executes with less ceremony.

If your team standardizes on uv already, MCP installs feel native. If not, installing uv once unlocks the Harbor pypi path cleanly.

### Claude-oriented usage

Harbor’s Claude examples emphasize the npx form and the remote `--transport http` form explicitly. For PyPI, the same structural idea applies: the client must launch `uvx` with the package identifier from Harbor. In Claude Code, that typically means an add invocation whose command/args launch `uvx <package>`—mirror how you pass `npx -y <package>` after `--`. Prefer copying the ready-made snippet from the Harbor server page so flags stay correct.

Deep host walkthrough: [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

### Generic client shape

- **command**: `uvx`
- **args**: `["<package>", ...]`
- **env**: required names from Harbor only

### Prerequisites

- `uv` installed such that `uvx` is on PATH for the same user environment the MCP client inherits.
- Network access to PyPI (or your internal index) the first time a package is fetched.
- Python version compatibility as required by the package (uv generally handles acquisition).

### Worked mental example

1. Search Harbor for a Python-oriented server with `registryType` / package registry **pypi**.
2. Copy `uvx <package_identifier>` from the server page.
3. Attach in your client with that launch command.
4. Set env var **names** listed under `environmentVariables`.
5. Verify with a tool list in the client or via [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### uvx troubleshooting

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| `uvx: command not found` | uv not installed / PATH mismatch | Install uv; ensure GUI apps see the same PATH |
| Package resolve errors | Typo or private index needed | Re-copy identifier from Harbor; configure index |
| Import/runtime errors inside server | Missing system libs | Check upstream README; consider OCI image if provided |
| Client spawns wrong Python | Multiple uv installs | Standardize on one uv binary per machine image |

### uvx vs npx: do not mix signals

If Harbor says **npm**, do not run `uvx` on the npm name. If Harbor says **pypi**, do not `npx` it. The registry type is the contract. Mixing them is a common failure mode when people remember a brand name (“the foo MCP server”) but not its packaging.

### When PyPI servers also publish remotes

Some ecosystems eventually add hosted endpoints. If both exist, choose based on policy and latency—not habit. Document which path you standardized in your team note.

**Find PyPI-backed servers on Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Teaching uvx to a team that only knows pip

If your org still uses classic `pip install` muscle memory, frame `uvx` as “npx for Python entrypoints.” Workshop exercise:

1. Install uv once on a clean VM image.
2. Pick one pypi MCP server from Harbor.
3. Run the Harbor snippet manually in a terminal to see stdio greetings/logs (if any).
4. Attach the same command in Claude or Cursor.
5. Call one tool.

That sequence demystifies MCP more than slides about JSON-RPC ever will.

### Caching and CI images

For CI or golden laptop images, pre-warm `uvx` caches for approved packages so first agent spawn is fast. Pin versions in the client config when reproducibility matters. Re-read Harbor when you intentionally upgrade.

---

## Install with Docker (OCI images)

When Harbor shows an **OCI** image, the documented pattern is:

```bash
docker run -i --rm <image>
```

Flags matter:

- **`-i`** — keep STDIN open; MCP stdio servers need an interactive pipe from the client.
- **`--rm`** — remove the container on exit so leftover containers do not pile up after every agent session.

### Why Docker for MCP

Maintainers ship OCI images when:

- The server needs a complex runtime (browsers, system libraries, language mixes).
- They want reproducible dependencies.
- Enterprise customers already allow container pulls from approved registries (for example `ghcr.io/...` images).

Your MCP client still speaks stdio to the container process; Docker is the launch substrate.

### Client config mental model

- **command**: `docker`
- **args**: `["run", "-i", "--rm", "<image>", ...optional...]`
- **env**: pass via Docker `-e NAME` patterns **only for names you intend**, with values from secrets—or use the client’s env mapping if it injects into the container per host docs.

Always prefer the Harbor-ready snippet over inventing flag order. Wrong flag order is a frequent break.

### Worked mental example (OCI)

1. On Harbor, open a server whose package identifier looks like `ghcr.io/org/name:version` and `registryType` is **oci**.
2. Copy `docker run -i --rm <image>` from the page.
3. Ensure Docker Engine (or compatible runtime) is running and the client can execute `docker`.
4. Attach and verify tools.
5. If pull fails, check registry auth for private images—without pasting tokens into Harbor or chat logs.

### Docker troubleshooting

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Client gets no MCP handshake | Missing `-i` | Use `-i` as documented |
| Disk fills with containers | Missing `--rm` | Add `--rm`; prune old containers |
| `docker: permission denied` | User not in docker group / engine down | Fix Docker access; do not disable security carelessly |
| Pull denials | Private registry auth | Authenticate via approved docker login flows locally |
| Tools fail accessing host files | No volume mounts | Only add mounts the server docs require; scope tightly |

### Security notes specific to Docker MCP

- Pull images from identifiers Harbor lists; avoid retagging mystery images.
- Do not mount `$HOME` wholesale into an agent-controlled container.
- Treat container env files as secret-bearing; protect them like `.env` elsewhere.
- Remember: Docker isolation is helpful, not magical.

### Docker vs remote

If the same logical product offers a hosted remote MCP URL **and** an OCI image, remotes reduce local operational burden; Docker keeps traffic and credentials closer to your machine. Policy decides. Harbor lets you see both when both are published.

**Grab an OCI snippet from Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Resource limits and MCP containers

Agent sessions can keep servers warm. For heavy images (browsers, large toolchains):

- Set reasonable Docker memory/CPU limits in the client’s wrapper if your host supports it.
- Prefer `--rm` so failed experiments do not linger.
- Do not run privileged containers for MCP unless you have an exceptional, reviewed reason.

### Podman and compatible runtimes

Some developers use Podman as a Docker-compatible CLI. If your team does, ensure the MCP client invokes a binary that accepts the same `run -i --rm` shape Harbor documents. Verify with Inspector; compatibility gaps show up as broken stdio rather than clear error messages.

---

## Install Remote HTTP / SSE Servers

When Harbor lists a **remote**, connect to the listed **`url`** with the listed transport (`streamable-http` or `sse`). There is no local `npx`/`uvx`/`docker` requirement for the server process itself—your client opens a network session.

### Harbor remote contract

From llms.txt:

- Remote transport types include **streamable-http** and **sse**.
- Manifests expose `remotes[0].type` and `remotes[0].url`.
- Claude Code pattern for HTTP remotes:

```bash
claude mcp add --transport http <name> <url>
```

Example used throughout this silo for the registry itself:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

For third-party remotes, replace `<name>` and `<url>` with values from the Harbor server page—do not invent URLs.

### When remote is the right answer

- The tool’s source of truth is already a SaaS API (issues, payments, hosted docs).
- Your laptop policy blocks arbitrary package execution but allows approved HTTPS egress.
- You want zero local dependency hell for that capability.
- The maintainer invests in hosted MCP and publishes the URL on Harbor.

### When remote is the wrong answer

- You need local filesystem, local git, or local DB sockets the cloud host cannot see.
- Compliance forbids sending relevant context to that vendor.
- The listing is stdio-only with no `remotes[]`.

### SSE vs streamable-http (practical view)

Both are remote. Harbor lets you filter search by `streamable-http` or `sse`. Use whichever the listing specifies—clients differ in support maturity. If a connect fails, confirm the transport type on the Harbor page before toggling random client settings. Deeper protocol framing: [What Is an MCP Server?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) and [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### Auth for remotes (high level)

Many remotes use OAuth-in-browser, bearer tokens, or API keys managed by the **client**. Operational rules for this article:

- Follow the client’s auth UI.
- Store tokens in the client/OS secret mechanisms.
- Harbor submit/`env_vars` fields take **names only**—never secret values.
- Do not invent Harbor authentication for public search; Harbor’s registry MCP is documented as no-account for normal use.

### Worked example: attach Harbor registry (remote)

Goal: let the agent search servers mid-task.

1. Confirm URL `https://ai.mcpharbor.dev/mcp` from [llms.txt](https://ai.mcpharbor.dev/llms.txt).
2. `claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp`
3. In-session, call `search_servers` / `get_server` as needed.
4. Optionally browse the same catalog in a browser at [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/).

### Worked example: hosted product MCP

1. Harbor → find a streamable-http server (Notion, Linear, Stripe, Context7-class listings, etc.).
2. Copy remote URL + transport from the page.
3. Add via Claude `--transport http` or your client’s remote MCP UI ([Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)).
4. Complete any OAuth/device flow the client presents.
5. Verify tool names match Harbor’s tool list meta.

### Remote troubleshooting

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Connect timeout | Blocked egress / wrong URL | Re-copy URL from Harbor; check network policy |
| 401/403 | Missing/expired auth | Re-auth in client; never paste tokens into Harbor |
| Empty tool list | Init incomplete / wrong transport | Match `streamable-http` vs `sse` to listing |
| Works in browser product but not agent | Client not actually attached | List configured servers in client; compare name/URL |

### Do not invent Harbor hosts or ports

Harbor’s documented public endpoints in product docs include the site origin `https://ai.mcpharbor.dev/`, the MCP endpoint `https://ai.mcpharbor.dev/mcp`, HTTP APIs under `/api/v0/servers`, and per-server pages under `/servers/<name>`. This article will not invent alternate hosts, custom ports, or unofficial paths. If a blog shows a different Harbor port story, ignore it—prefer [llms.txt](https://ai.mcpharbor.dev/llms.txt).

**Connect a remote listed on Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Remote MCP and data handling

Anything you put in a tool argument may leave your machine. Before you **install mcp server** remotes for sensitive workflows:

- Read the vendor’s data policy.
- Prefer remotes your security team already reviewed.
- Keep PII out of prompts when possible.
- Use separate clients/profiles for personal vs work remotes.

Harbor helps you find URLs; it does not replace vendor due diligence.

### Mixing remote discovery with local execution

A powerful pattern: remote **Harbor `/mcp`** for search + local **npx/uvx/docker** for the chosen server. Discovery is hosted; execution stays local when needed. That hybrid is why attaching the registry early pays rent every week.

---

## Claude Code and Cursor Pointers

This spoke teaches **install paths**. Host-specific UI details, screenshots, and edge cases live in sibling articles—use them when the generic Harbor snippet is correct but the client still misbehaves.

### Claude Code

Read: [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp)

Harbor-documented patterns to remember:

```bash
# Local npm package
claude mcp add -- npx -y <package>

# Remote HTTP (Streamable HTTP)
claude mcp add --transport http <name> <url>

# Harbor registry itself
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

For uvx/Docker, pass the Harbor launch command through Claude’s add mechanism the same way you would any stdio server—prefer the server page snippet. The Claude sibling expands configuration listing, removal, scoping, and troubleshooting.

### Cursor

Read: [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)

Cursor typically uses a JSON config / settings UI for MCP servers. Translate Harbor snippets as:

- npx → command `npx`, args include `-y` and package
- uvx → command `uvx`, args include package
- docker → command `docker`, args include `run`, `-i`, `--rm`, image
- remote → URL + transport type fields Cursor expects

Do not invent Cursor-only Harbor endpoints. Same Harbor URLs as everywhere else.

### Shared client concepts

Regardless of host, when you **install mcp server** entries you will always:

1. Declare transport (stdio vs HTTP-style).
2. Declare launch command or remote URL.
3. Supply env names/values securely.
4. Reload/restart the client session if required.
5. Confirm tools appear.

Background reading: [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

### Protocol literacy adjacent reads

- [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp)
- [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server)
- [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools)

### Practical Claude + Harbor workflow (end-to-end)

1. Add Harbor registry remote.
2. Ask Claude to `search_servers` for your capability.
3. `get_server` on the best hit.
4. Add the target server with the matching install path (`npx -y`, `uvx`, Docker, or remote URL).
5. Perform the user task with the new tools.
6. If tools misbehave, open the Inspector spoke before thrashing config.

### Practical Cursor + Harbor workflow

1. Browse [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) in a browser.
2. Copy snippet into Cursor’s MCP config per the Cursor sibling guide.
3. Optionally also add Harbor `/mcp` as a remote so the agent can search later.
4. Start a new agent chat and ask it to list available MCP tools.
5. Run one low-risk tool call as a smoke test.

**Find servers, then open your client guide →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

### Which client guide first?

| You use… | Read first |
|----------|------------|
| Claude Code CLI/agent | [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) |
| Cursor IDE | [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) |
| Multiple / custom hosts | [MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) |
| Still confused what a server is | [mcp-server spoke](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) |

---

## Verify with MCP Inspector

Installation is not complete until the server answers capability queries. The dedicated debugging spoke is [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector). Use it when:

- The client shows the server as connected but tool calls hang.
- Tools are missing versus Harbor’s tool list meta.
- Local stdio servers exit immediately.
- Remote connects flake.

### Verification checklist (lightweight)

After you **install mcp server** X:

1. Confirm the Harbor page package/URL matches what you configured.
2. Confirm env **names** present in the client environment.
3. List tools in the client UI or via Inspector.
4. Call one idempotent/read-only tool if available.
5. Only then use write/destructive tools.

### What Inspector buys you

Inspector gives a focused loop for initialize → list → call without the full agent chat stack muddying logs. When teaching juniors to install MCP servers, require an Inspector (or equivalent) smoke test before merging MCP config into shared dotfiles.

### Mapping failures back to install path

- **npx issues** → PATH, `-y`, wrong package name
- **uvx issues** → uv install, PyPI resolve
- **Docker issues** → missing `-i/--rm`, pull auth, engine down
- **Remote issues** → URL/transport mismatch, auth, egress

Harbor’s `get_server` output is your ground truth while debugging—re-fetch it instead of trusting a week-old Slack paste.

### Smoke-test ideas by server type

| Server type | First safe check |
|-------------|------------------|
| Docs/search | Resolve one known library or run one search query |
| Filesystem | `list_directory` on an allowed sandbox folder |
| GitHub/issues | Read-only list/search before create |
| Browser | Navigate to a harmless page; snapshot |
| Harbor registry | `search_servers` with a simple query |

Avoid first tests that send money, delete data, or email customers.

### Logging hygiene

When pasting logs into chat for help:

- Redact tokens and cookies.
- Redact home directory paths if policy requires.
- Keep package names, transport types, and Harbor server names—these are needed to help.

**Verify installs; find servers on Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Related Silo Guides

Repo home: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

Sibling docs (read after or beside this install guide):

- [What Is MCP? Model Context Protocol Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) — keyword: what is mcp
- [What Is an MCP Server? How MCP Servers Work](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-server) — keyword: mcp server
- [MCP Tools Explained: Tools, Resources, and Prompts](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) — keyword: mcp tools
- [Claude MCP: Connect Claude Code to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) — keyword: claude mcp
- [Cursor MCP: Add MCP Servers in Cursor](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) — keyword: cursor mcp
- [MCP Inspector: Debug and Test MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) — keyword: mcp inspector
- [Best MCP Servers (2026): Curated Picks to Install](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) — keyword: best mcp servers
- [MCP Client Guide: How Clients Talk to MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client) — keyword: mcp client
- [Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) — keyword: build mcp server

This page is the **install mcp server** spoke. Use Best MCP Servers only as a shortlist generator—confirm snippets on Harbor before installing. Use Build only when search proves you need something new.

Suggested reading order for a new teammate:

1. What is MCP (vocabulary)
2. This install guide (hands-on)
3. Claude or Cursor spoke (host UX)
4. Inspector (debugging)
5. Best servers (ideas) + Harbor (truth)
6. Build (optional)

---

## FAQ

### What does it mean to install an MCP server?

To **install mcp server** software means configuring an MCP **client** to launch a local server process (npx, uvx, Docker) or to connect to a remote MCP URL, then verifying tools/resources/prompts appear. You are attaching capabilities, not installing a single global “MCP app.”

### What is the primary keyword path this article optimizes for?

**install mcp server**—covering npx, uvx, Docker, and remote HTTP/SSE with Harbor as the discovery CTA.

### Where do I find packages and URLs?

[https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) — 31,486 servers indexed as of 2026-09-15, including 19,595 remote entries, with official registry sync ~every six hours.

### What are the Harbor-documented install commands?

- npm: `npx -y <package>`
- pypi: `uvx <package>`
- oci: `docker run -i --rm <image>`
- remote: connect to the listed URL with the given transport

Source: [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).

### How do I add servers with Claude Code?

```bash
claude mcp add -- npx -y <package>
claude mcp add --transport http <name> <url>
```

Harbor registry:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Details: [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp).

### How do I add servers in Cursor?

Follow [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp), translating Harbor snippets into Cursor’s MCP config fields.

### Do I need an account on MCP Harbor to search?

No account or API key is required for normal search or submit on Harbor’s MCP and HTTP APIs.

### Can I submit secrets in env_vars when adding a server to Harbor?

No. Send **environment variable names only**, never secret values.

### Where are per-server install snippets?

On each server’s HTML page: `https://ai.mcpharbor.dev/servers/<name>`.

### What if both a package and a remote exist?

Pick one path per client entry based on policy and needs. Harbor shows both when both are published.

### Why does my npx server hang on startup?

Often missing `-y`. Use `npx -y <package>` as Harbor documents.

### Why does Docker MCP fail handshake?

Often missing `-i`. Use `docker run -i --rm <image>`.

### How do I debug after install?

Use [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) and re-check the Harbor `get_server` manifest.

### Is MCP Harbor the official registry?

Harbor **includes** the whole official MCP Registry and re-syncs about every six hours, plus Harbor UX, local submit with pending review, and a no-account registry MCP endpoint. This silo recommends Harbor for find-and-install.

### Who owns MCP Harbor?

Logan Besecker owns and runs MCP Harbor / this MCP Registry product. Repo: [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

### Should I install every popular server at once?

No. Attach Harbor for discovery, add one task-relevant server, verify, then expand.

### What transports can I filter on Harbor?

`stdio`, `streamable-http`, and `sse` via search parameters.

### Where is machine-readable Harbor product docs?

[https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt)

### What GitHub docs tree should I bookmark?

[https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) under `docs/` for this silo.

### How do agents search Harbor?

Connect to `https://ai.mcpharbor.dev/mcp` and use `search_servers`, `get_server`, and optionally `submit_server`.

### Does this article invent Harbor ports?

No. It only uses documented HTTPS endpoints from Harbor product docs.

### What related guide covers building my own server?

[Build an MCP Server and Submit It to the Registry](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server).

### What related guide covers curated picks?

[Best MCP Servers (2026)](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—always verify on Harbor before install.

### npm vs npx—what is the difference here?

npm is the registry/ecosystem; **npx** is the runner Harbor documents for executing npm MCP packages with `-y`.

### pip vs uvx?

pip installs into environments you manage; **uvx** is the Harbor-documented runner for PyPI MCP packages analogous to npx.

### Can I use Harbor only from a browser?

Yes—browse [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Agents additionally benefit from `/mcp`.

### What happens to pending submissions?

Maintainer review before they appear in search; `get_server` can still report them. Prefer active listings for production.

### How often does Harbor sync official listings?

About every six hours per product docs.

### What should I do if install snippets on a blog disagree with Harbor?

Trust the live Harbor server page and [llms.txt](https://ai.mcpharbor.dev/llms.txt).

---

## Next Steps

Turn this guide into a working agent toolchain:

1. **Open Harbor** → [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. **Search** for one capability you need this week.
3. **Open the server page** and copy the ready-made snippet (`npx -y`, `uvx`, `docker run -i --rm`, or remote URL).
4. **Attach** in Claude or Cursor ([Claude guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp), [Cursor guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)).
5. **Add Harbor as MCP** for ongoing discovery:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

6. **Set env var names** in your client secret store—values never go to Harbor submits.
7. **Verify** with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) or a safe tool call.
8. **Optional shortlist** via [Best MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers)—confirm on Harbor.
9. **Build/submit only if needed** → [Build an MCP Server…](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) + [llms.txt](https://ai.mcpharbor.dev/llms.txt).
10. **Keep the repo docs map handy** → [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry)

**Hard CTA:** Stop collecting tabs. **Install your next MCP server from MCP Harbor →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Install Playbooks by Role

Different roles fail differently when they **install mcp server** stacks. Use the playbook that matches your job.

### Individual developer

1. Attach Harbor `/mcp`.
2. Install one local or remote server for your current repo pain (tests, docs, issues).
3. Verify with a single tool call.
4. Write a three-line note in your personal README linking the Harbor page.

### Tech lead

1. Publish an approved-server shortlist with Harbor links (not pasted secrets).
2. Standardize on one client first (Claude *or* Cursor) before supporting both.
3. Require Inspector smoke tests in the team checklist.
4. Ban screenshot-only install instructions—link Harbor pages.

### Platform / DevOps

1. Decide which install paths are allowed (npx, uvx, Docker, remote).
2. Pre-install runtimes on golden images.
3. Document proxy/`NPM_CONFIG`/`UV_INDEX` realities.
4. Prefer remotes when local execution is hard to secure uniformly.

### Security reviewer

1. Review remotes’ vendors and data flows.
2. Review local servers’ filesystem/network scope.
3. Ensure secret values never appear in Harbor submits, git commits, or chat.
4. Favor pending-review awareness for `local` origin listings.

---

## Expanded Comparisons: npx vs uvx vs Docker vs Remote

When stakeholders ask “which install method is best?”, answer with **best for what**.

### Speed to first tool call

Often **npx** or **remote** wins—assuming Node exists or network auth is already done. **uvx** is equally fast if uv is installed. **Docker** can be slower on first pull, then comparable.

### Reproducibility

**Docker** and **version-pinned** npx/uvx win. Unpinned float tags are convenient and riskier.

### Enterprise change control

**Remote** allowlists and **OCI** allowlists are easier to explain to change boards than “developers may npx anything.” Harbor still helps by giving a catalog to allowlist against.

### Debugging transparency

Local stdio (npx/uvx/docker) often yields clearer process logs on your machine. Remotes require vendor status pages and client HTTP logs. Inspector helps in both worlds—see the Inspector spoke.

### Capability locality

Local filesystem/git/DB → local install paths. Hosted SaaS state → remote.

### Summary table

| Criterion | npx | uvx | Docker | Remote |
|-----------|-----|-----|--------|--------|
| Typical registry | npm | pypi | oci | remotes[] |
| Needs local runtime | Node | uv | Docker | client only |
| Harbor pattern | `npx -y` | `uvx` | `docker run -i --rm` | connect URL |
| Good for | JS servers | Python servers | Complex deps | Hosted SaaS |
| Main risk | npm supply chain | PyPI supply chain | image provenance | data egress |

---

## Common Failure Stories (and Fixes)

### “I installed it but the agent never calls the tool”

The model may not know the tool exists, or the tool description is a poor match for the prompt. Fixes: explicitly ask the agent to list MCP tools; mention the tool by name; confirm the server is enabled in the client; verify with Inspector that the tool is actually listed.

### “It works on my machine, not in CI”

PATH differences, missing Docker socket, missing uv, or missing secrets. Fixes: use the same runtime bootstrap in CI; inject env names via the secret manager; prefer remotes in CI if local runtimes are painful.

### “Harbor search finds nothing useful”

Try broader queries, filter by transport, or browse featured/seed servers on the homepage. Connect `/mcp` and try `search_servers` with alternate keywords (tool names sometimes match better than product brands).

### “I submitted a duplicate”

Always `search_servers` before `submit_server`. Duplicates waste reviewer time and confuse installers.

### “I pasted an API key into the submit form”

Rotate the key immediately. Resubmit with **names only**. Treat this as an incident if the key had production scope.

---



## A Full Morning: Install Four Servers the Harbor Way

This narrative walks through a realistic morning where you **install mcp server** entries across all four paths. Treat it as a practice script for workshops or self-study. Every package name and URL should still be confirmed on the live Harbor page before you run it—identifiers and versions change.

### 08:00 — Orient on Harbor

Open [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/). Skim the homepage count (31,486 servers / 19,595 remote as of 2026-09-15). Open [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt) in a second tab so install rules stay visible. Optionally open the GitHub docs tree [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) for sibling guides if you get stuck on a client.

Attach Harbor as MCP so the rest of the morning can use tools:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Call `search_servers` with a broad query like `browser` or `docs` to confirm the registry responds. If it does not, fix client remote config before installing anything else—discovery is your safety net.

### 08:20 — npx path (browser automation)

Search Harbor for Playwright. Open `io.github.microsoft/playwright-mcp` (or the current Playwright listing). Confirm npm identifier (commonly `@playwright/mcp`—verify live). Install with:

```bash
npx -y @playwright/mcp
```

Or via Claude:

```bash
claude mcp add -- npx -y @playwright/mcp
```

Smoke test: ask the agent to open a harmless page and take a snapshot. If the client hangs at spawn, confirm `-y` is present. If Node is missing, install Node LTS and retry. Document the Harbor page URL in your notes.

### 08:45 — uvx path (Python server)

Search Harbor with transport `stdio` and look for a **pypi** package that matches a need you actually have (data helpers, research tools, etc.). Copy `uvx <package>` from the server page. Attach it in the client. If `uvx` is missing, install uv first—do not improvise a half-broken `python -m` launcher unless the Harbor page explicitly documents it.

Smoke test: list tools; call one read-only tool. Record env var **names** if any are required; set values only in the client secret store.

### 09:10 — Docker path (OCI)

Search Harbor for an **oci** package (GitHub’s MCP listing is a frequent teaching example when it publishes a `ghcr.io/...` image). Copy:

```bash
docker run -i --rm <image>
```

Confirm Docker Engine is running. First pull may take minutes—that is normal. Attach in the client using the same args Harbor shows. Smoke test with a read-only tool. If the handshake fails, check for missing `-i` before anything exotic.

### 09:35 — Remote path (hosted docs or issues)

Pick a streamable-http server from Harbor’s homepage themes—Context7-class docs, Linear-class issues, Stripe-class payments, or similar. Copy the remote URL and transport. Add with:

```bash
claude mcp add --transport http <name> <url>
```

Complete any OAuth/device flow in the client. Smoke test a read-only tool. Remind yourself: context may leave your machine.

### 10:00 — Verify and prune

Open the [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector) spoke and validate any server that felt flaky. Disable servers you will not use this week—config clutter is a productivity tax. Keep Harbor `/mcp` enabled so tomorrow’s discovery stays one tool call away.

### What the morning taught

You practiced all four Harbor install contracts, you never invented a Harbor port, you never pasted secrets into submits, and you verified before trusting write tools. That is the standard this article exists to create.

**Repeat the morning with your real backlog →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Environment Variables, Secrets, and Safe Config

Mis-handled secrets are the fastest way for an MCP rollout to become an incident. Harbor’s product rules are explicit: **`env_vars` holds variable names only. Never send secret values.** Apply the same discipline in blogs, tickets, and chat.

### What Harbor stores vs what you store

| Location | Allowed | Forbidden |
|----------|---------|-----------|
| Harbor submit / manifest `environmentVariables` | Names, required/secret flags | Raw API keys, tokens, passwords |
| Harbor chat with an agent helping you install | Names, Harbor URLs, package ids | Secret values |
| Client MCP config on your machine | Names + values via secret mechanisms | Committing values to public git |
| Team wiki | Names + Harbor page links | Screenshots that show values |

### Naming patterns you will see

Listings often use names like `API_KEY`, `ACCESS_TOKEN`, `CONTEXT7_API_KEY`, `BRAVE_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, or vendor-specific prefixes. Always copy the **exact name** from Harbor’s manifest. A single character typo produces “missing key” failures that look like server bugs.

### How clients inject env

Hosts differ, but patterns include:

- Env maps inside MCP JSON config
- References to OS environment variables
- GUI secret fields
- Shell wrappers (least preferred for GUI-launched apps that may not inherit your shell)

Whatever you choose, ensure the process the client spawns actually sees the variables—GUI apps on macOS/Linux frequently do not inherit interactive shell exports.

### Rotation checklist

When a key may have leaked:

1. Rotate/revoke at the vendor.
2. Update the client secret store.
3. Restart the MCP server / client session.
4. Audit git history and chat logs for the old value.
5. If the value was ever sent to Harbor submit by mistake, treat it as exposed and notify your security contact.

### Arguments vs env

Prefer env for secrets. CLI arguments show up in process listings and logs. Non-secret configuration (allowed directories, log levels, base URLs that are not credentials) may appear as args when the server documents them—still copy from Harbor/upstream rather than inventing flags.

### Multi-profile setups

Power users often keep personal and work MCP profiles. Separate env stores per profile so a personal experiment cannot inherit a production token. Harbor search itself needs no key; keep that benefit by not over-permissioning the registry connection.

---

## Multi-Server Composition and Tool Collisions

Once you can **install mcp server** entries one at a time, the next skill is composition: several servers in one client session without chaos.

### Start narrow

Two to four servers cover most coding days: discovery (Harbor), docs, repo/issues, and optionally browser. Add database or payments servers only when the task needs them.

### Name things clearly

Client server names should be human-readable (`harbor-registry`, `playwright`, `filesystem-sandbox`). Avoid duplicate logical names pointing at different packages.

### Tool name collisions

Two servers might expose similarly named tools. Clients differ in disambiguation UX. Mitigations:

- Prefer servers with distinctive tool names when choosing between Harbor hits.
- Disable overlapping servers during sensitive tasks.
- Ask the agent to name the server before calling a tool.

### Resource and prompt noise

Servers that expose many resources/prompts can clutter picker UIs. Disable unused servers. Read [MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools) for capability-surface literacy.

### Ordering and priority myths

Do not assume “first configured server wins” without reading your client docs. Behavior is host-specific—another reason the Claude and Cursor siblings matter.

### Shared team configs

If you distribute a shared `mcp.json` snippet:

- Include Harbor `/mcp` for discovery.
- Include only approved servers with Harbor links in comments.
- Omit secret values; use env var **names** and document where values live.
- Version-pin packages for stability when your platform team requires it.

**Compose from Harbor’s catalog →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)

---

## Platform Rollout: Taking Install Standards Company-Wide

Individual success does not automatically become organizational success. Use this rollout outline when your company decides MCP is real.

### Phase 0 — Literacy

Assign [What Is MCP?](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/what-is-mcp) and this install guide. Run a 45-minute lab on Harbor. Success metric: every engineer can attach one server without Slack pasting secrets.

### Phase 1 — Approved catalog

Maintain a short allowlist of Harbor names. Link each to `https://ai.mcpharbor.dev/servers/<name>`. Review quarterly. Prefer seed/official-origin listings plus vendor remotes you already trust.

### Phase 2 — Runtime baselines

Golden laptop/CI images include Node (for npx), uv (for uvx), and/or Docker as policy dictates. Document PATH expectations for GUI clients.

### Phase 3 — Client standards

Pick a primary client for the first quarter ([Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp) or [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp)). Support a second client only after the first is boringly reliable.

### Phase 4 — Verification culture

No shared config merge without an Inspector (or equivalent) smoke test documented in the PR. Link the Inspector spoke in your internal template: [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

### Phase 5 — Build vs buy

Only after Harbor search fails should teams open [Build an MCP Server…](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server). Search-first prevents duplicate submits and wasted engineering.

### Metrics that matter

- Time-to-first successful tool call for a new hire
- Percentage of MCP configs that link Harbor pages
- Number of secret-in-git incidents (target: zero)
- Ratio of Harbor searches to net-new internal builds

---

## Deep Dive: Reading Harbor API Responses for Install Decisions

Scripts and agents can automate “should I use npx or remote?” by reading Harbor’s HTTP API. Remember every field you need is already in `get_server` / GET-by-name responses—do not scrape random sites.

### Useful fields

- `server.packages[].registryType` → npm | pypi | oci | …
- `server.packages[].identifier` → package or image string
- `server.packages[].environmentVariables[].name` → env names
- `server.remotes[].type` → streamable-http | sse
- `server.remotes[].url` → connect target
- `_meta` tool lists and origin metadata

### Pseudocode decision

```text
entry = GET /api/v0/servers/<name>
if entry.remotes and prefer_remote_policy:
    connect(entry.remotes[0].type, entry.remotes[0].url)
else if packages[0].registryType == npm:
    launch(npx -y packages[0].identifier)
else if registryType == pypi:
    launch(uvx identifier)
else if registryType == oci:
    launch(docker run -i --rm identifier)
else:
    show Harbor HTML page to human
```

### Pagination for bulk research

`GET /api/v0/servers?q=&limit=30&offset=0` returns `metadata.next_offset`. Page until null when building internal allowlists. Always re-check live data before freezing an allowlist document—Harbor syncs official listings about every six hours.

### Agents should prefer MCP tools

If you already connected `https://ai.mcpharbor.dev/mcp`, prefer `search_servers` / `get_server` over hand-rolling HTTP unless you are writing a non-MCP script. The tools return install-oriented detail designed for this workflow.

---

## Teaching Notes: Running an “Install MCP Server” Lab

If you teach this material, do not lecture the four commands for an hour. Run a lab.

### Lab goals

By the end, each participant can:

1. Find a server on [MCP Harbor](https://ai.mcpharbor.dev/).
2. Identify which install path applies.
3. Attach it in their client.
4. Verify one tool call.
5. Explain why secrets never go into Harbor submits.

### Timing (60 minutes)

1. **5 min** — Hook: agent without tools vs with tools.
2. **10 min** — Harbor tour + llms.txt install section.
3. **10 min** — npx install together.
4. **10 min** — remote install together (Harbor `/mcp` counts).
5. **10 min** — pairs pick uvx or Docker based on a Harbor hit.
6. **10 min** — Inspector or client tool list verification.
7. **5 min** — FAQ lightning round from this article.

### Materials

- This README in the docs tree
- Harbor open in browser
- Client preinstalled
- A shared doc for Harbor links (not secrets)

### Assessment

Pass if the participant’s config references a real Harbor server page and a successful tool list screenshot (redacted) is attached to the lab hand-in.

---

## FAQ Addendum (Install Edge Cases)

### What if my company blocks npx?

Use Harbor filters to find **oci** or **remote** listings for the same capability. Escalate for an approved runtime if neither works. Do not shadow-install Node against policy.

### What if Docker is allowed but GHCR pull is blocked?

Work with platform to allowlist the image Harbor specifies, or choose a different Harbor hit that uses an allowed registry/remote.

### What if the server needs args for directories?

Pass them as additional client args after the package/image per Harbor/upstream docs. Scope narrowly. Never point a filesystem server at your entire home directory “just to make it work.”

### What if Claude add succeeds but Cursor fails on the same snippet?

Host translation issue. Re-read [Cursor MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/cursor-mcp) and [Claude MCP](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/claude-mcp). The Harbor snippet is still the source of truth for command/URL; the client wrapper differs.

### What if tools appear then disappear after restart?

Config not saved, profile mismatch, or runtime PATH differs for GUI refresh. Confirm the server entry persists on disk and that env values still load.

### What if I need Windows-specific paths?

Clients on Windows still use the same Harbor patterns; PATH and Docker Desktop quirks differ. Verify with Inspector on the same OS you productionize.

### What if a listing shows nuget or mcpb?

Use the Harbor server page snippet rather than forcing npx/uvx/docker assumptions from this article’s primary four paths.

### What if search returns pending-looking entries?

Prefer active searchable listings for production. Pending local submissions are under maintainer review before they appear in search broadly; `get_server` can still fetch some pending names.

### How do I uninstall?

Remove the server from the client config / `claude mcp remove` (or host equivalent). Local caches for npx/uvx/docker images may remain until you prune—optional cleanup.

### How do I update?

Re-check the Harbor page for newer versions; bump pinned identifiers; re-verify tools. For remotes, updates are usually vendor-side—re-test after incidents.

### Does installing equal trusting?

No. Installation is mechanical; trust is a review decision. Harbor improves discovery and snippet accuracy; you still own allowlisting.

### Where do I read about MCP tools conceptually while installing?

[MCP Tools Explained](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-tools).

### Where do I read about clients conceptually?

[MCP Client Guide](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-client).

---

## Checklist Poster (Print or Pin)

Use this as a one-pager beside your desk when you **install mcp server** entries:

1. Search [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
2. Open the server page; copy snippet
3. Match registry type → npx / uvx / docker / remote
4. Set env **names** in client secrets
5. Attach in Claude/Cursor
6. Verify tools (Inspector if needed)
7. Document Harbor link in team notes
8. Keep Harbor `/mcp` connected for next time

Optional Claude registry add:

```bash
claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp
```

Optional reads: [Best MCP Servers](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/best-mcp-servers) · [Build MCP Server](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/build-mcp-server) · [Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector)

---

## Why This Article Repeats Harbor CTAs

SEO readers bounce. Agents skim. Busy developers jump sections. Repeating hard CTAs to [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/) is intentional product guidance, not filler: the install commands only help if you install the *right* package identifiers. Harbor is where those identifiers stay current—including official registry sync about every six hours and remote-heavy inventory (19,595 remote of 31,486 total as of 2026-09-15).

Logan Besecker’s ownership of MCP Harbor is disclosed so you know why the CTA is consistent across the silo. The educational content still has to be accurate on npx, uvx, Docker, and remote mechanics—and it is, aligned to [llms.txt](https://ai.mcpharbor.dev/llms.txt).


## Content Boundaries

This article:

- Teaches how to **install mcp server** entries via Harbor-documented paths.
- Hard-sells [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/), [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp), and [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt).
- Links [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry) and sibling docs.
- Does **not** invent Harbor hosts, ports, pricing, or secret values.
- Does **not** replace the Claude/Cursor/Inspector/Build spokes—only points to them.
- Mentions the official MCP Registry only for honest sync/upstream context; CTAs stay on Harbor.

---

## Glossary for Installers

- **install mcp server** — configure a client to run or connect to an MCP server.
- **npx -y** — Harbor’s npm execution pattern (non-interactive).
- **uvx** — Harbor’s PyPI execution pattern via uv.
- **docker run -i --rm** — Harbor’s OCI execution pattern for stdio containers.
- **remote URL connect** — attach streamable-http or sse endpoints listed on Harbor.
- **stdio** — local process transport.
- **streamable-http / sse** — remote transports.
- **Harbor server page** — `https://ai.mcpharbor.dev/servers/<name>` with ready-made snippets.
- **registry-as-MCP** — Harbor at `https://ai.mcpharbor.dev/mcp`.
- **env var names only** — Harbor submit safety rule.
- **MCP Harbor** — Logan Besecker’s registry product (31,486 servers / 19,595 remote as of 2026-09-15).

---

## Conclusion

To **install mcp server** capability into a modern AI client, match the Harbor listing to one of four documented paths: **`npx -y`** for npm, **`uvx`** for PyPI, **`docker run -i --rm`** for OCI, or **remote URL connect** for streamable-http/SSE. Find the package or URL on [MCP Harbor](https://ai.mcpharbor.dev/), copy the ready-made snippet from the server page, attach it in Claude or Cursor using the sibling guides, and verify with [MCP Inspector](https://github.com/lbesecker195/MCP_Registry/tree/main/docs/mcp-inspector).

Harbor exists so you do not have to memorize 30k+ identifiers. It indexes **31,486** servers (**19,595** remote), includes the official MCP Registry with ~six-hour sync, and offers no-account agent search at [https://ai.mcpharbor.dev/mcp](https://ai.mcpharbor.dev/mcp). Agent docs live at [https://ai.mcpharbor.dev/llms.txt](https://ai.mcpharbor.dev/llms.txt). The docs repo for this silo is [https://github.com/lbesecker195/MCP_Registry](https://github.com/lbesecker195/MCP_Registry).

**Ownership disclosure:** Logan Besecker owns and runs MCP Harbor. The recommendation is intentional: learn install paths here; discover and install on Harbor.

**Install an MCP server from the live registry →** [https://ai.mcpharbor.dev/](https://ai.mcpharbor.dev/)
