# AGENT.md — MCP Registry Agent Guide

This document outlines how to use Claude agents and Claude Code with the MCP Registry project.

## Overview

The MCP Registry is a Phoenix application that indexes and presents MCP (Model Context Protocol) servers. Agents assist with:
- **Content generation**: Creating technical articles for MCP servers (20,000+ words for top 500, 500 words for remainder)
- **Batch operations**: Processing multiple servers efficiently
- **API integration**: Saving generated content directly to production

## Article Generation Pipeline

### Setup

1. **Environment**: Point to canonical repo at `~/Documents/businesses/MCP_Registry`
2. **Token**: Export `REGISTRY_PUBLISH_TOKEN` for production saves
3. **Data**: Fetch server list from MCP Registry API

```bash
cd ~/Documents/businesses/MCP_Registry
export REGISTRY_PUBLISH_TOKEN="your-token-here"
```

### Single Article Generation

For a single server, use Claude to:
1. Research the MCP server (GitHub repo, documentation, features)
2. Generate comprehensive technical article in markdown
3. Save via API:

```bash
./scripts/save_article.sh server-name /path/to/article.md --prod
```

**Example:**
```bash
./scripts/save_article.sh io.github.microsoft/playwright-mcp article.md --prod
```

### Batch Generation (Recommended)

For multiple servers, spawn agents in parallel:

1. **Research Agent**: Fetch server metadata and documentation
2. **Content Agent**: Generate markdown articles (per server)
3. **Save Agent**: Batch upload to production

Use a workflow or multi-agent approach:
- Each server gets its own content generation task
- Articles are validated before saving
- Failed saves are logged for retry

### Article Requirements

**First 500 servers**: 20,000+ words
- Deep technical dive
- Architecture and design patterns
- Use cases and examples
- Integration guide with Claude/Cursor
- Link to registry page: `https://ai.mcpharbor.dev/servers/:name`

**Remaining ~31k servers**: 500 words
- Overview and key features
- Primary use case
- Quick setup
- Link to registry page

## API Reference

### Save Article Endpoint

**POST** `/api/v0/articles/:name`

Requires: `Authorization: Bearer REGISTRY_PUBLISH_TOKEN`

```bash
curl -X POST "https://ai.mcpharbor.dev/api/v0/articles/io.github.microsoft%2Fplaywright-mcp" \
  -H "Authorization: Bearer $REGISTRY_PUBLISH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "# Article markdown here..."}'
```

Returns: Updated server object with `article_generated_at` timestamp.

### Retrieve Server

**GET** `/api/v0/servers/:name`

```bash
curl "https://ai.mcpharbor.dev/api/v0/servers/io.github.microsoft%2Fplaywright-mcp"
```

## Content Quality Guidelines

### Technical Articles (20,000+ words)

1. **Introduction** (500 words)
   - What is this MCP server?
   - Why developers care
   - Integration points with Claude/Cursor

2. **Architecture** (2,000 words)
   - How it works internally
   - Protocol implementation
   - Design decisions

3. **Features Deep-Dive** (5,000 words)
   - Each major feature
   - Capabilities and limitations
   - Real-world examples

4. **Integration Guide** (5,000 words)
   - Setup and installation
   - Configuration options
   - Authentication (if applicable)
   - Common workflows

5. **Use Cases** (3,000 words)
   - Real scenarios where this helps
   - Code examples
   - Performance characteristics

6. **Troubleshooting** (1,500 words)
   - Common issues
   - Solutions
   - Support resources

7. **Comparison** (1,500 words)
   - How it compares to alternatives
   - Unique advantages
   - When to use vs. alternatives

8. **Advanced Topics** (1,500 words)
   - Custom extensions
   - Performance tuning
   - Security considerations

### Short Articles (500 words)

1. **Overview** (200 words): What it is, why useful
2. **Quick Start** (200 words): Setup and basic use
3. **Key Features** (100 words): Main capabilities
4. **Link**: To registry page and repository

## Workflow Example

```bash
# 1. Start content generation agent
# Agent should:
#   - Fetch server info from https://registry.modelcontextprotocol.io/v0.1/servers
#   - Read GitHub repo and docs
#   - Generate comprehensive markdown article
#   - Return article content

# 2. Save article
REGISTRY_PUBLISH_TOKEN="..." ./scripts/save_article.sh server-name article.md --prod

# 3. Verify on production
curl "https://ai.mcpharbor.dev/api/v0/servers/server-name" | jq '.server.article_generated_at'

# 4. Visit page to confirm rendering
# https://ai.mcpharbor.dev/servers/server-name
```

## Database Schema

Articles are stored in the `servers` table:

```sql
article_content TEXT          -- Markdown content
article_generated_at TIMESTAMP -- When article was saved
```

The LiveView renders markdown to HTML using Earmark library.

## Performance Notes

- **Batch saves**: Use ContentGenerator.save_articles_batch/1 for bulk operations
- **API rate limits**: Respect production API limits when saving
- **Article size**: Large articles (50KB+) are acceptable; no hard limit

## Troubleshooting

### Token Errors
```
✗ REGISTRY_PUBLISH_TOKEN not set
```
**Fix**: Export token before running script
```bash
export REGISTRY_PUBLISH_TOKEN="..."
```

### Server Not Found
```
✗ Server not found
```
**Fix**: Verify server name matches registry exactly (lowercase, full path)

### 404 on Endpoint
**Fix**: Ensure DNS and app deployment are complete

## Production Checklist

- [ ] Token is valid
- [ ] DNS points to new server
- [ ] App is deployed and running
- [ ] Database migrations applied
- [ ] Article content is markdown format
- [ ] Server name matches registry exactly
- [ ] Verify article renders on production page

## Links

- **Registry**: https://ai.mcpharbor.dev
- **API Docs**: https://ai.mcpharbor.dev/api/v0/servers
- **GitHub**: https://github.com/lbesecker195/MCP_Registry
- **Official Registry**: https://registry.modelcontextprotocol.io/v0.1/servers
