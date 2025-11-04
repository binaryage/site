#!/bin/bash

# diff-build.sh - Compare snapshot with current build output
# Usage: ./_scripts/diff-build.sh <snapshot-name> [--verbose]

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

# Configuration
VERBOSE=false

# Usage message
usage() {
    echo -e "${BOLD}Usage:${RESET} $0 <snapshot-name> [--verbose]"
    echo ""
    echo "Compares a snapshot with the current build output."
    echo ""
    echo "${BOLD}Arguments:${RESET}"
    echo "  snapshot-name    Name of the snapshot to compare against"
    echo "  --verbose        Show detailed file-level differences"
    echo ""
    echo "${BOLD}Examples:${RESET}"
    echo "  $0 baseline"
    echo "  $0 before-refactor --verbose"
    echo ""
    echo "${BOLD}Exit codes:${RESET}"
    echo "  0    No differences found"
    echo "  1    Differences found"
    echo "  2    Error (snapshot not found, build missing, etc.)"
    exit 1
}

# Check if we're in the right directory
if [[ ! -f "rakefile" ]] || [[ ! -d "_lib" ]]; then
    echo -e "${RED}Error: This script must be run from the site repository root${RESET}"
    exit 2
fi

# Parse arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Snapshot name is required${RESET}\n"
    usage
fi

SNAPSHOT_NAME="$1"
if [[ "${2:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

SNAPSHOTS_DIR=".snapshots"
SNAPSHOT_PATH="$SNAPSHOTS_DIR/$SNAPSHOT_NAME"
BUILD_DIR=".stage/build"

# Validate snapshot exists
if [[ ! -d "$SNAPSHOT_PATH" ]]; then
    echo -e "${RED}Error: Snapshot '$SNAPSHOT_NAME' not found${RESET}"
    echo -e "${GRAY}Available snapshots:${RESET}"
    if [[ -d "$SNAPSHOTS_DIR" ]]; then
        for snapshot in "$SNAPSHOTS_DIR"/*; do
            if [[ -d "$snapshot" ]]; then
                name=$(basename "$snapshot")
                echo -e "  - $name"
            fi
        done
    else
        echo -e "  ${GRAY}(none)${RESET}"
    fi
    exit 2
fi

# Validate current build exists
if [[ ! -d "$BUILD_DIR" ]]; then
    echo -e "${RED}Error: Current build not found: $BUILD_DIR${RESET}"
    echo -e "${GRAY}Run 'rake build' first${RESET}"
    exit 2
fi

# Display snapshot metadata
METADATA_FILE="$SNAPSHOT_PATH/.snapshot-meta.txt"
echo -e "${BOLD}${CYAN}=== Comparing Build Output ===${RESET}\n"
echo -e "${BOLD}Snapshot:${RESET} $SNAPSHOT_NAME"
if [[ -f "$METADATA_FILE" ]]; then
    CREATED=$(grep "^Created:" "$METADATA_FILE" | cut -d: -f2- | xargs || echo "unknown")
    GIT_COMMIT=$(grep "^Git Commit:" "$METADATA_FILE" | cut -d: -f2- | xargs || echo "unknown")
    DESCRIPTION=$(grep "^Description:" "$METADATA_FILE" | cut -d: -f2- | xargs || echo "N/A")
    echo -e "${GRAY}Created: $CREATED${RESET}"
    echo -e "${GRAY}Git commit: $GIT_COMMIT${RESET}"
    if [[ "$DESCRIPTION" != "N/A" ]]; then
        echo -e "${GRAY}Description: $DESCRIPTION${RESET}"
    fi
fi
echo ""

# Get list of sites (directories in build output, excluding volatile dirs)
SITES=()
for dir in "$BUILD_DIR"/*; do
    if [[ -d "$dir" ]]; then
        name=$(basename "$dir")
        # Skip volatile directories
        if [[ "$name" != "_cache" && "$name" != ".configs" ]]; then
            SITES+=("$name")
        fi
    fi
done

# Compare each site
CHANGED_SITES=()
UNCHANGED_SITES=()
NEW_SITES=()
MISSING_SITES=()

echo -e "${BLUE}→${RESET} Comparing sites..."
echo ""

for site in "${SITES[@]}"; do
    snapshot_site="$SNAPSHOT_PATH/$site"
    current_site="$BUILD_DIR/$site"

    # Check if site exists in snapshot
    if [[ ! -d "$snapshot_site" ]]; then
        NEW_SITES+=("$site")
        echo -e "  ${CYAN}+${RESET} ${BOLD}$site${RESET} - ${CYAN}NEW${RESET} (not in snapshot)"
        continue
    fi

    # Compare site directories
    if diff -rq \
        --exclude='_cache' \
        --exclude='.configs' \
        "$snapshot_site" "$current_site" > /dev/null 2>&1; then
        UNCHANGED_SITES+=("$site")
        echo -e "  ${GREEN}✓${RESET} $site - ${GRAY}unchanged${RESET}"
    else
        CHANGED_SITES+=("$site")
        echo -e "  ${YELLOW}●${RESET} ${BOLD}$site${RESET} - ${YELLOW}CHANGED${RESET}"

        # Show file-level changes in verbose mode
        if [[ "$VERBOSE" == true ]]; then
            diff -rq \
                --exclude='_cache' \
                --exclude='.configs' \
                "$snapshot_site" "$current_site" 2>/dev/null | \
                sed 's/^/     /' || true
        fi
    fi
done

# Check for sites that exist in snapshot but not in current build
for snapshot_site_path in "$SNAPSHOT_PATH"/*; do
    if [[ -d "$snapshot_site_path" ]]; then
        site=$(basename "$snapshot_site_path")
        # Skip metadata and volatile directories
        if [[ "$site" != ".snapshot-meta.txt" && "$site" != "_cache" && "$site" != ".configs" ]]; then
            current_site="$BUILD_DIR/$site"
            if [[ ! -d "$current_site" ]]; then
                MISSING_SITES+=("$site")
                echo -e "  ${RED}-${RESET} ${BOLD}$site${RESET} - ${RED}MISSING${RESET} (was in snapshot)"
            fi
        fi
    fi
done

echo ""

# Print summary
echo -e "${BOLD}${CYAN}=== Summary ===${RESET}"
echo -e "Total sites:     ${BOLD}${#SITES[@]}${RESET}"
echo -e "Unchanged:       ${GREEN}${#UNCHANGED_SITES[@]}${RESET}"
if [[ ${#CHANGED_SITES[@]} -gt 0 ]]; then
    echo -e "Changed:         ${YELLOW}${#CHANGED_SITES[@]}${RESET}"
fi
if [[ ${#NEW_SITES[@]} -gt 0 ]]; then
    echo -e "New sites:       ${CYAN}${#NEW_SITES[@]}${RESET}"
fi
if [[ ${#MISSING_SITES[@]} -gt 0 ]]; then
    echo -e "Missing sites:   ${RED}${#MISSING_SITES[@]}${RESET}"
fi
echo ""

# Show instructions for detailed diff
if [[ ${#CHANGED_SITES[@]} -gt 0 ]] || [[ ${#NEW_SITES[@]} -gt 0 ]] || [[ ${#MISSING_SITES[@]} -gt 0 ]]; then
    echo -e "${BOLD}For detailed file-level differences:${RESET}"
    if [[ "$VERBOSE" != true ]]; then
        echo -e "  ${GRAY}./_scripts/diff-build.sh $SNAPSHOT_NAME --verbose${RESET}"
    fi
    echo -e "  ${GRAY}diff -ru --exclude='_cache' --exclude='.configs' $SNAPSHOT_PATH/ $BUILD_DIR/${RESET}"
    echo ""

    # List changed sites
    if [[ ${#CHANGED_SITES[@]} -gt 0 ]]; then
        echo -e "${BOLD}Changed sites:${RESET}"
        for site in "${CHANGED_SITES[@]}"; do
            echo -e "  - $site"
            echo -e "    ${GRAY}diff -ru $SNAPSHOT_PATH/$site/ $BUILD_DIR/$site/${RESET}"
        done
        echo ""
    fi

    echo -e "${YELLOW}⚠ Build output differs from snapshot${RESET}"
    exit 1
else
    echo -e "${GREEN}✓ Build output matches snapshot exactly${RESET}"
    exit 0
fi
