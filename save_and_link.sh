#!/bin/bash

# Configuration
REGISTRY_PUBLISH_TOKEN="42530e55fccb8553736aa998c02bc60e70e3dd839cdb077020c8b901acf30f93"
BASE_URL="https://ai.mcpharbor.dev"
REPO_DIR="$HOME/Documents/businesses/MCP_Registry"
CONTENT_DIR="$REPO_DIR/content"

# Mapping of guide titles to content directories
declare -A guides=(
    ["What is MCP"]="what-is-mcp"
    ["MCP Server Development"]="mcp-server"
    ["How to Build MCP Servers"]="build-mcp-server"
    ["Installing MCP Servers"]="install-mcp-server"
    ["MCP Clients Explained"]="mcp-client"
    ["MCP Inspector Guide"]="mcp-inspector"
    ["Claude + MCP Integration"]="claude-mcp"
    ["Cursor IDE + MCP"]="cursor-mcp"
    ["Best MCP Servers Guide"]="best-mcp-servers"
    ["MCP Tools & Ecosystems"]="mcp-tools"
)

echo "MCP Registry - Article Save and GitHub Link Update"
echo "==================================================="
echo ""
echo "Step 1: Upload articles to production"
echo "Step 2: Update GitHub README files with links"
echo ""

# For each guide, update the README to link to the article
for guide_title in "${!guides[@]}"; do
    guide_dir="${guides[$guide_title]}"
    readme_file="$CONTENT_DIR/$guide_dir/README.md"
    
    if [ -f "$readme_file" ]; then
        echo "Processing: $guide_title"
        echo "  README: $readme_file"
        
        # The article would be available at:
        # https://ai.mcpharbor.dev/content/$guide_dir/article.md
        # Or as a full guide page
        
        # For now, just show what would be updated
    else
        echo "Missing: $guide_dir/README.md"
    fi
done

echo ""
echo "Ready to upload 15 articles and update GitHub files"
echo "Next: Run article upload batch job"

