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

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires empty string after -i
    sed_inplace() {
        sed -i '' "$@"
    }
else
    # Linux doesn't need empty string
    sed_inplace() {
        sed -i "$@"
    }
fi

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
    echo -e "${YELLOW}Attempting automatic conflict resolution...${NC}"

    # Get list of conflicted files
    CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)

    if [ -z "$CONFLICTED_FILES" ]; then
        echo -e "${GREEN}✓ No conflicts to resolve${NC}"
    else
        echo -e "${BLUE}Conflicted files:${NC}"
        echo "$CONFLICTED_FILES"
        echo ""

        # Auto-resolve common conflicts
        AUTO_RESOLVED=0
        MANUAL_NEEDED=0

        for file in $CONFLICTED_FILES; do
            case "$file" in
                pyproject.toml)
                    echo -e "${BLUE}Resolving pyproject.toml...${NC}"
                    # Extract upstream version
                    UPSTREAM_VERSION=$(git show upstream/main:pyproject.toml | grep '^version = ' | head -1 | cut -d'"' -f2)
                    if [ ! -z "$UPSTREAM_VERSION" ]; then
                        # Use ours as base, then fix package name and version
                        git checkout --ours pyproject.toml
                        sed_inplace "s/^version = .*/version = \"$UPSTREAM_VERSION\"/" pyproject.toml
                        sed_inplace 's/^name = .*/name = "martin-mcp-server"/' pyproject.toml
                        git add pyproject.toml
                        echo -e "${GREEN}  ✓ Resolved (martin-mcp-server v$UPSTREAM_VERSION)${NC}"
                        AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    else
                        echo -e "${YELLOW}  ⚠ Could not extract version${NC}"
                        MANUAL_NEEDED=$((MANUAL_NEEDED + 1))
                    fi
                    ;;

                config.py)
                    echo -e "${BLUE}Resolving config.py...${NC}"
                    # Extract upstream version and date
                    UPSTREAM_VERSION=$(git show upstream/main:config.py | grep '^__version__ = ' | cut -d'"' -f2)
                    UPSTREAM_DATE=$(git show upstream/main:config.py | grep '^__updated__ = ' | cut -d'"' -f2)
                    if [ ! -z "$UPSTREAM_VERSION" ] && [ ! -z "$UPSTREAM_DATE" ]; then
                        # Use ours as base, then update version and date
                        git checkout --ours config.py
                        sed_inplace "s/^__version__ = .*/__version__ = \"$UPSTREAM_VERSION\"/" config.py
                        sed_inplace "s/^__updated__ = .*/__updated__ = \"$UPSTREAM_DATE\"/" config.py
                        git add config.py
                        echo -e "${GREEN}  ✓ Resolved (v$UPSTREAM_VERSION, $UPSTREAM_DATE)${NC}"
                        AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    else
                        echo -e "${YELLOW}  ⚠ Could not extract version/date${NC}"
                        MANUAL_NEEDED=$((MANUAL_NEEDED + 1))
                    fi
                    ;;

                CHANGELOG.md)
                    echo -e "${BLUE}Resolving CHANGELOG.md...${NC}"
                    # Use upstream version (they maintain the official changelog)
                    git checkout --theirs CHANGELOG.md
                    git add CHANGELOG.md
                    echo -e "${GREEN}  ✓ Resolved (using upstream)${NC}"
                    AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    ;;

                README.md)
                    echo -e "${BLUE}Resolving README.md...${NC}"
                    # Keep fork's README, but update version badges
                    UPSTREAM_VERSION=$(git show upstream/main:config.py | grep '^__version__ = ' | cut -d'"' -f2)
                    if [ ! -z "$UPSTREAM_VERSION" ]; then
                        git checkout --ours README.md
                        # Update version badges
                        sed_inplace "s/version-[0-9.]*-green/version-$UPSTREAM_VERSION-green/" README.md
                        sed_inplace "s/upstream-v[0-9.]*-blue/upstream-v$UPSTREAM_VERSION-blue/" README.md
                        git add README.md
                        echo -e "${GREEN}  ✓ Resolved (updated badges to v$UPSTREAM_VERSION)${NC}"
                        AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    else
                        echo -e "${YELLOW}  ⚠ Could not extract version${NC}"
                        MANUAL_NEEDED=$((MANUAL_NEEDED + 1))
                    fi
                    ;;

                README_ZH.md)
                    echo -e "${BLUE}Resolving README_ZH.md...${NC}"
                    # Keep fork's Chinese README, update version badges
                    UPSTREAM_VERSION=$(git show upstream/main:config.py | grep '^__version__ = ' | cut -d'"' -f2)
                    if [ ! -z "$UPSTREAM_VERSION" ]; then
                        git checkout --ours README_ZH.md
                        sed_inplace "s/version-[0-9.]*-green/version-$UPSTREAM_VERSION-green/" README_ZH.md
                        sed_inplace "s/upstream-v[0-9.]*-blue/upstream-v$UPSTREAM_VERSION-blue/" README_ZH.md
                        git add README_ZH.md
                        echo -e "${GREEN}  ✓ Resolved (updated badges to v$UPSTREAM_VERSION)${NC}"
                        AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    else
                        echo -e "${YELLOW}  ⚠ Could not extract version${NC}"
                        MANUAL_NEEDED=$((MANUAL_NEEDED + 1))
                    fi
                    ;;

                tests/test_uvx_support.py)
                    echo -e "${BLUE}Resolving tests/test_uvx_support.py...${NC}"
                    # Use upstream version, then fix package name assertions
                    git checkout --theirs tests/test_uvx_support.py
                    sed_inplace 's/"pal-mcp-server"/"martin-mcp-server"/g' tests/test_uvx_support.py
                    git add tests/test_uvx_support.py
                    echo -e "${GREEN}  ✓ Resolved (using upstream, fixed package name)${NC}"
                    AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    ;;

                run-server.sh|run-server.ps1)
                    echo -e "${BLUE}Resolving $file...${NC}"
                    # Use upstream version (they maintain these scripts)
                    git checkout --theirs "$file"
                    git add "$file"
                    echo -e "${GREEN}  ✓ Resolved (using upstream)${NC}"
                    AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
                    ;;

                *)
                    echo -e "${YELLOW}  ⚠ $file requires manual resolution${NC}"
                    MANUAL_NEEDED=$((MANUAL_NEEDED + 1))
                    ;;
            esac
        done

        echo ""
        echo -e "${BLUE}Auto-resolution summary:${NC}"
        echo -e "  ${GREEN}✓ Resolved: $AUTO_RESOLVED${NC}"
        if [ $MANUAL_NEEDED -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ Manual: $MANUAL_NEEDED${NC}"
        fi

        # Check if all conflicts are resolved
        REMAINING_CONFLICTS=$(git diff --name-only --diff-filter=U)
        if [ -z "$REMAINING_CONFLICTS" ]; then
            echo ""
            echo -e "${GREEN}✓ All conflicts resolved automatically!${NC}"
            echo -e "${BLUE}Committing merge...${NC}"

            # Create a detailed commit message
            UPSTREAM_VERSION=$(git show upstream/main:config.py | grep '^__version__ = ' | cut -d'"' -f2)
            git commit --no-edit

            echo -e "${GREEN}✓ Merge committed successfully${NC}"
        else
            echo ""
            echo -e "${RED}✗ Some conflicts still need manual resolution:${NC}"
            git status --short | grep "^UU\|^AA\|^DD"
            echo ""
            echo "After resolving:"
            echo "   git add <resolved-files>"
            echo "   git merge --continue"
            echo ""
            echo "Or to abort:"
            echo "   git merge --abort"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${BLUE}Sync Summary:${NC}"
git log HEAD~${UPSTREAM_COMMITS}..HEAD --oneline
echo ""
echo -e "${GREEN}Done! Your fork is now up-to-date with upstream.${NC}"
