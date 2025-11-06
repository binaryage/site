#!/bin/bash
# Universal post-commit hook for shared submodule synchronization
# This hook can be installed in ANY shared submodule directory
# When a commit is made, it automatically syncs to all other shared directories

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the commit that was just created
NEW_COMMIT=$(git rev-parse HEAD)
SHORT_COMMIT=$(git rev-parse --short HEAD)

# Detect which site's shared directory this hook is running in
SOURCE_SITE=$(basename "$(git rev-parse --show-superproject-working-tree)")

# Calculate the site root (parent of all website directories)
# Hook is in: .git/modules/SITE/modules/shared/hooks/post-commit
# We need to go: ../../../../.. to reach site root
GIT_DIR=$(git rev-parse --git-dir)
SITE_ROOT=$(cd "$GIT_DIR/../../../../.." && pwd)

# Check if auto-sync is enabled
if [ ! -f "$SITE_ROOT/.shared-autosync-enabled" ]; then
    exit 0
fi

# Get list of all website directories (excluding hidden dirs and _* dirs)
cd "$SITE_ROOT"
ALL_SITES=($(ls -d */ 2>/dev/null | sed 's|/||' | grep -v '^\.' | grep -v '^_' || true))

# Filter to only sites that have a shared submodule
TARGET_SITES=()
for site in "${ALL_SITES[@]}"; do
    if [ -d "$site/shared" ] && [ "$site" != "$SOURCE_SITE" ]; then
        TARGET_SITES+=("$site")
    fi
done

# If no targets, exit
if [ ${#TARGET_SITES[@]} -eq 0 ]; then
    exit 0
fi

# Header
echo -e "${BLUE}🔄 Syncing from ${YELLOW}${SOURCE_SITE}/shared${NC} ${BLUE}(${SHORT_COMMIT})${NC}"

# Counters
SYNCED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

# Sync to each target
for target_site in "${TARGET_SITES[@]}"; do
    TARGET_DIR="$SITE_ROOT/$target_site/shared"

    # Verify target directory exists
    if [ ! -d "$TARGET_DIR" ]; then
        continue
    fi

    # Verify it's actually a git repository
    if ! (cd "$TARGET_DIR" && git rev-parse --git-dir >/dev/null 2>&1); then
        continue
    fi

    # Safety check: ensure no uncommitted changes
    if ! (cd "$TARGET_DIR" && git diff-index --quiet HEAD 2>/dev/null); then
        echo -e "  ${YELLOW}⚠️  ${target_site}/shared${NC} - has uncommitted changes, skipping"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Calculate relative path from target to source
    # Since all shared dirs are at same level: ../../source/shared
    FETCH_PATH="../../${SOURCE_SITE}/shared"

    # Attempt to fetch and checkout
    if (cd "$TARGET_DIR" && \
        git fetch "$FETCH_PATH" master >/dev/null 2>&1 && \
        git checkout FETCH_HEAD --quiet 2>/dev/null); then
        echo -e "  ${GREEN}✅ ${target_site}/shared${NC}"
        ((SYNCED_COUNT++))
    else
        echo -e "  ${RED}❌ ${target_site}/shared${NC} - failed to sync"
        ((FAILED_COUNT++))
    fi
done

# Summary
if [ $SYNCED_COUNT -gt 0 ]; then
    echo -e "${GREEN}✨ Synced ${SYNCED_COUNT} site(s)${NC}"
fi

if [ $SKIPPED_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⏭️  Skipped ${SKIPPED_COUNT} site(s) with uncommitted changes${NC}"
fi

if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}⚠️  Failed to sync ${FAILED_COUNT} site(s)${NC}"
    exit 1
fi

exit 0
