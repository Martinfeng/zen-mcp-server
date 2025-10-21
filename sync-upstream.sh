#!/bin/bash
# Sync Upstream Updates Script
# This script automatically syncs updates from upstream while preserving custom modifications
#
# Author: Martin (Feng)
# Date: 2025-10-21

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Zen MCP Server - Upstream Sync Tool${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check if upstream remote exists
if ! git remote get-url upstream > /dev/null 2>&1; then
    echo -e "${RED}Error: 'upstream' remote not configured${NC}"
    echo "Run: git remote add upstream https://github.com/BeehiveInnovations/zen-mcp-server.git"
    exit 1
fi

# Store current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}Current branch:${NC} $CURRENT_BRANCH"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    echo "Please commit or stash your changes before syncing."
    git status --short
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Fetching upstream updates...${NC}"
git fetch upstream

# Check if there are new commits
UPSTREAM_COMMITS=$(git rev-list HEAD..upstream/main --count 2>/dev/null || echo "0")
if [ "$UPSTREAM_COMMITS" = "0" ]; then
    echo -e "${GREEN}✓ Already up-to-date with upstream${NC}"
    exit 0
fi

echo -e "${YELLOW}Found $UPSTREAM_COMMITS new commit(s) from upstream${NC}"
echo ""

# Show what's new
echo -e "${BLUE}Recent upstream commits:${NC}"
git log HEAD..upstream/main --oneline --max-count=5
echo ""

# Ask for confirmation
read -p "Continue with merge? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Sync cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Step 2: Merging upstream changes...${NC}"

# Attempt automatic merge
if git merge upstream/main --no-edit; then
    echo -e "${GREEN}✓ Automatic merge successful!${NC}"
    echo ""
    echo -e "${BLUE}Verifying custom modifications...${NC}"

    # Verify critical custom files
    ISSUES=0

    # Check martin_patches.py exists
    if [ ! -f "martin_patches.py" ]; then
        echo -e "${RED}✗ martin_patches.py is missing!${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✓ martin_patches.py preserved${NC}"
    fi

    # Check server.py has the import
    if ! grep -q "import martin_patches" server.py; then
        echo -e "${YELLOW}⚠ server.py is missing martin_patches import${NC}"
        echo "  Re-adding import..."

        # Create a backup
        cp server.py server.py.backup

        # Re-add the import after the docstring
        python3 << 'EOF'
import re

with open('server.py', 'r') as f:
    content = f.read()

# Check if already has the import
if 'import martin_patches' not in content:
    # Find the position after the module docstring (support both single and double quotes)
    pattern = r'(?:(""".*?""")|(\'\'\'.*?\'\'\'))\s*\n'
    match = re.search(pattern, content, re.DOTALL)

    if match:
        # Insert after docstring
        insert_pos = match.end()
        patch_import = """
# Apply Martin's custom patches (must be first, before any provider imports)
try:
    import martin_patches  # noqa: F401
except ImportError:
    pass  # Patches not available, continue with default behavior

"""
        content = content[:insert_pos] + patch_import + content[insert_pos:]

        with open('server.py', 'w') as f:
            f.write(content)

        print("✓ Import added successfully")
    else:
        print("✗ Could not find insertion point")
        exit(1)
EOF

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ server.py import restored${NC}"
            rm server.py.backup  # Clean up the backup file
            git add server.py
        else
            echo -e "${RED}✗ Failed to restore server.py import${NC}"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo -e "${GREEN}✓ server.py import preserved${NC}"
    fi

    # Check pyproject.toml has martin-mcp-server
    if ! grep -q "martin-mcp-server" pyproject.toml; then
        echo -e "${YELLOW}⚠ pyproject.toml package name was reset${NC}"
        echo "  Please manually restore package name to 'martin-mcp-server'"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✓ pyproject.toml package name preserved${NC}"
    fi

    # Check NOTICE file exists
    if [ ! -f "NOTICE" ]; then
        echo -e "${YELLOW}⚠ NOTICE file is missing${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}✓ NOTICE file preserved${NC}"
    fi

    echo ""
    if [ $ISSUES -eq 0 ]; then
        echo -e "${GREEN}✓ All custom modifications verified!${NC}"
        echo -e "${GREEN}✓ Sync completed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Sync completed with $ISSUES warning(s)${NC}"
        echo "  Please review the issues above and fix manually if needed."
    fi

else
    echo -e "${RED}✗ Automatic merge failed - conflicts detected${NC}"
    echo ""
    echo -e "${YELLOW}Conflicted files:${NC}"
    git status --short | grep "^UU\|^AA\|^DD"
    echo ""
    echo -e "${BLUE}Manual conflict resolution required:${NC}"
    echo ""
    echo "Common conflict resolution steps:"
    echo ""
    echo "1. For server.py:"
    echo "   - Keep both changes (upstream + martin_patches import)"
    echo "   - Ensure the import is at the top, before other imports"
    echo ""
    echo "2. For .env.example:"
    echo "   - Keep upstream changes"
    echo "   - Re-add the Martin's Custom Patches section"
    echo ""
    echo "3. For pyproject.toml:"
    echo "   - Keep upstream version/dependencies"
    echo "   - Change package name back to 'martin-mcp-server'"
    echo "   - Keep .martin_venv in exclusions"
    echo ""
    echo "After resolving conflicts:"
    echo "   git add <resolved-files>"
    echo "   git merge --continue"
    echo ""
    echo "Or to abort the merge:"
    echo "   git merge --abort"

    exit 1
fi

echo ""
echo -e "${BLUE}Sync Summary:${NC}"
git log HEAD~${UPSTREAM_COMMITS}..HEAD --oneline
echo ""
echo -e "${GREEN}Done! Your fork is now up-to-date with upstream.${NC}"
