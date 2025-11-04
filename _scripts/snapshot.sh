#!/bin/bash

# snapshot.sh - Build all sites and save snapshot for comparison
# Usage: ./_scripts/snapshot.sh <snapshot-name> [description]

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# Usage message
usage() {
    echo -e "${BOLD}Usage:${RESET} $0 <snapshot-name> [description]"
    echo ""
    echo "Creates a snapshot of the build output for later comparison."
    echo ""
    echo "${BOLD}Arguments:${RESET}"
    echo "  snapshot-name    Name for this snapshot (e.g., 'before-refactor')"
    echo "  description      Optional description of what this snapshot represents"
    echo ""
    echo "${BOLD}Examples:${RESET}"
    echo "  $0 baseline"
    echo "  $0 before-cdn-removal 'Before removing CDN code'"
    exit 1
}

# Check if we're in the right directory
if [[ ! -f "rakefile" ]] || [[ ! -d "_lib" ]]; then
    echo -e "${RED}Error: This script must be run from the site repository root${RESET}"
    exit 1
fi

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Snapshot name is required${RESET}\n"
    usage
fi

SNAPSHOT_NAME="$1"
DESCRIPTION="${2:-}"

# Validate snapshot name (alphanumeric, dashes, underscores only)
if [[ ! "$SNAPSHOT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Error: Snapshot name must contain only letters, numbers, dashes, and underscores${RESET}"
    exit 1
fi

SNAPSHOTS_DIR=".snapshots"
SNAPSHOT_PATH="$SNAPSHOTS_DIR/$SNAPSHOT_NAME"
BUILD_DIR=".stage/build"

# Check if snapshot already exists
if [[ -d "$SNAPSHOT_PATH" ]]; then
    echo -e "${YELLOW}Warning: Snapshot '$SNAPSHOT_NAME' already exists${RESET}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GRAY}Cancelled${RESET}"
        exit 0
    fi
    echo -e "${YELLOW}Removing existing snapshot...${RESET}"
    rm -rf "$SNAPSHOT_PATH"
fi

# Create snapshots directory if it doesn't exist
mkdir -p "$SNAPSHOTS_DIR"

echo -e "${BOLD}${CYAN}=== Creating Snapshot: $SNAPSHOT_NAME ===${RESET}\n"

# Step 1: Build all sites
echo -e "${BLUE}→${RESET} Building all sites..."
echo -e "${GRAY}  Running: rake build${RESET}"
if ! rake build > /tmp/snapshot-build.log 2>&1; then
    echo -e "${RED}✗ Build failed!${RESET}"
    echo -e "${GRAY}  See log: /tmp/snapshot-build.log${RESET}"
    tail -n 20 /tmp/snapshot-build.log
    exit 1
fi
echo -e "${GREEN}✓${RESET} Build completed successfully"
echo ""

# Check if build directory exists
if [[ ! -d "$BUILD_DIR" ]]; then
    echo -e "${RED}✗ Build directory not found: $BUILD_DIR${RESET}"
    exit 1
fi

# Step 2: Create snapshot
echo -e "${BLUE}→${RESET} Creating snapshot..."
mkdir -p "$SNAPSHOT_PATH"

# Copy build output, excluding volatile directories
echo -e "${GRAY}  Copying build output (excluding volatile files)...${RESET}"
rsync -a \
    --exclude='_cache' \
    --exclude='.configs' \
    "$BUILD_DIR/" "$SNAPSHOT_PATH/"

echo -e "${GREEN}✓${RESET} Snapshot created"
echo ""

# Step 3: Save metadata
METADATA_FILE="$SNAPSHOT_PATH/.snapshot-meta.txt"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

cat > "$METADATA_FILE" <<EOF
Snapshot Name: $SNAPSHOT_NAME
Created: $TIMESTAMP
Git Branch: $GIT_BRANCH
Git Commit: $GIT_HASH
Description: ${DESCRIPTION:-N/A}
Build Command: rake build
Exclusions: _cache/, .configs/
EOF

echo -e "${BLUE}→${RESET} Snapshot metadata saved"
echo ""

# Step 4: Calculate and display statistics
SNAPSHOT_SIZE=$(du -sh "$SNAPSHOT_PATH" | cut -f1)
SITE_COUNT=$(find "$SNAPSHOT_PATH" -maxdepth 1 -type d | wc -l | xargs)
SITE_COUNT=$((SITE_COUNT - 1)) # Subtract 1 for the snapshot directory itself

echo -e "${BOLD}${CYAN}=== Snapshot Summary ===${RESET}"
echo -e "Name:         ${BOLD}$SNAPSHOT_NAME${RESET}"
echo -e "Location:     ${GRAY}$SNAPSHOT_PATH${RESET}"
echo -e "Size:         ${GREEN}$SNAPSHOT_SIZE${RESET}"
echo -e "Sites:        $SITE_COUNT"
echo -e "Git commit:   ${GRAY}$GIT_HASH${RESET} on ${GRAY}$GIT_BRANCH${RESET}"
if [[ -n "$DESCRIPTION" ]]; then
    echo -e "Description:  $DESCRIPTION"
fi
echo ""

# List all snapshots
echo -e "${BOLD}Available snapshots:${RESET}"
if [[ -d "$SNAPSHOTS_DIR" ]]; then
    for snapshot in "$SNAPSHOTS_DIR"/*; do
        if [[ -d "$snapshot" ]]; then
            name=$(basename "$snapshot")
            size=$(du -sh "$snapshot" 2>/dev/null | cut -f1)
            meta_file="$snapshot/.snapshot-meta.txt"
            created="unknown"
            if [[ -f "$meta_file" ]]; then
                created=$(grep "^Created:" "$meta_file" | cut -d: -f2- | xargs || echo "unknown")
            fi
            if [[ "$name" == "$SNAPSHOT_NAME" ]]; then
                echo -e "  ${GREEN}●${RESET} ${BOLD}$name${RESET} - $size - $created"
            else
                echo -e "  ${GRAY}○${RESET} $name - $size - $created"
            fi
        fi
    done
else
    echo -e "  ${GRAY}(none)${RESET}"
fi
echo ""

echo -e "${GREEN}✓ Snapshot created successfully${RESET}"
echo -e "${GRAY}Compare with: ./_scripts/diff-build.sh $SNAPSHOT_NAME${RESET}"
