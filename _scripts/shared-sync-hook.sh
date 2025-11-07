#!/bin/bash
# Universal post-commit hook for shared submodule synchronization
#
# NOTE: Automatic synchronization from post-commit hooks is unreliable due to
# git's internal submodule state management. Updates appear to work but are
# reverted by git immediately after. Use manual sync instead: rake shared:sync
#
# This hook is kept for reference but should not be enabled.

set -e

# Get the commit that was just created
NEW_COMMIT=$(git rev-parse HEAD)

# Detect which site's shared directory this hook is running in
SOURCE_SITE=$(basename "$(git rev-parse --show-superproject-working-tree)")

# Calculate the site root (parent of all website directories)
# Hook is in: .git/modules/SITE/modules/shared/hooks/post-commit
# We need to go: ../../../../.. to reach site root
GIT_DIR=$(git rev-parse --absolute-git-dir)
SITE_ROOT=$(cd "$GIT_DIR/../../../../.." && pwd)

# Check if auto-sync is enabled
if [ ! -f "$SITE_ROOT/.shared-autosync-enabled" ]; then
    exit 0
fi

# Run worker script completely detached from hook process
# This ensures git doesn't interfere with submodule updates
nohup bash -c "sleep 1 && cd '$SITE_ROOT' && bash '$SITE_ROOT/_scripts/shared-sync-worker.sh' '$NEW_COMMIT' '$SOURCE_SITE'" >> "$SITE_ROOT/.shared-sync.log" 2>&1 < /dev/null &
disown

exit 0
