#!/bin/bash

# Save an article for an MCP server via the REST API
# Usage: ./scripts/save_article.sh <server_name> <article_file> [--prod]

set -e

SERVER_NAME="$1"
ARTICLE_FILE="$2"
PROD="${3:-}"

if [ -z "$SERVER_NAME" ] || [ -z "$ARTICLE_FILE" ]; then
  echo "Usage: $0 <server_name> <article_file> [--prod]"
  echo ""
  echo "Examples:"
  echo "  $0 io.github.microsoft/playwright-mcp /tmp/article.md"
  echo "  $0 io.github.microsoft/playwright-mcp /tmp/article.md --prod"
  exit 1
fi

if [ ! -f "$ARTICLE_FILE" ]; then
  echo "✗ Article file not found: $ARTICLE_FILE"
  exit 1
fi

# Determine target
if [ "$PROD" = "--prod" ]; then
  TARGET="https://ai.mcpharbor.dev"
  TOKEN="${REGISTRY_PUBLISH_TOKEN}"
  echo "🌐 Saving to PRODUCTION: $TARGET"
else
  TARGET="http://localhost:4000"
  TOKEN="${REGISTRY_PUBLISH_TOKEN:-dev-token}"
  echo "🔧 Saving to LOCAL: $TARGET"
fi

if [ -z "$TOKEN" ]; then
  echo "✗ REGISTRY_PUBLISH_TOKEN not set"
  exit 1
fi

# Read article content
ARTICLE=$(cat "$ARTICLE_FILE")
ARTICLE_SIZE=${#ARTICLE}

echo "✓ Loaded article ($ARTICLE_SIZE bytes)"
echo "✓ Server: $SERVER_NAME"

# Escape server name for URL
ENCODED_NAME=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SERVER_NAME', safe=''))")

# Send request
echo "Saving..."

RESPONSE=$(curl -s -X POST "$TARGET/api/v0/articles/$ENCODED_NAME" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"content\": $(echo "$ARTICLE" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")}")

# Check response
if echo "$RESPONSE" | grep -q '"name"'; then
  echo "✓ Successfully saved!"
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | grep -E '"name"|article_generated_at' || true
else
  echo "✗ Failed to save:"
  echo "$RESPONSE" | head -20
  exit 1
fi
