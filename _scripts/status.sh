#!/bin/bash

# status.sh - Check status of all git submodules and their shared submodules
# Usage: ./_scripts/status.sh [--verbose]

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
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

# Detect all submodules dynamically from .gitmodules
SUBMODULES=()
while IFS= read -r submodule; do
    SUBMODULES+=("$submodule")
done < <(git config --file .gitmodules --get-regexp path | awk '{print $2}')

# Counters for summary
TOTAL_SUBMODULES=${#SUBMODULES[@]}
CLEAN_COUNT=0
DIRTY_COUNT=0
AHEAD_COUNT=0
BEHIND_COUNT=0
WRONG_BRANCH_COUNT=0
SHARED_ISSUES=0

# Check if we're in the right directory
if [[ ! -f "rakefile" ]] || [[ ! -d "_lib" ]]; then
    echo -e "${RED}Error: This script must be run from the site repository root${RESET}"
    exit 1
fi

echo -e "${BOLD}${CYAN}=== Git Submodules Status ===${RESET}\n"

check_submodule() {
    local submodule=$1
    local has_issues=false

    # Check if submodule directory exists
    if [[ ! -d "$submodule" ]]; then
        echo -e "${RED}✗ $submodule${RESET} - ${RED}MISSING${RESET}"
        ((DIRTY_COUNT++))
        return
    fi

    pushd "$submodule" > /dev/null

    # Get current branch
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "DETACHED")

    # Check if on expected branch (should be 'web' for main submodules)
    local branch_status="$branch"
    if [[ "$branch" != "web" ]]; then
        branch_status="${YELLOW}$branch${RESET} ${GRAY}(expected: web)${RESET}"
        has_issues=true
        ((WRONG_BRANCH_COUNT++))
    else
        branch_status="${GREEN}$branch${RESET}"
    fi

    # Check working directory status
    local status
    status=$(git status --porcelain 2>/dev/null || echo "ERROR")
    local is_dirty=false
    if [[ -n "$status" ]]; then
        is_dirty=true
        has_issues=true
        ((DIRTY_COUNT++))
    fi

    # Check ahead/behind status
    local ahead_behind=""
    local is_ahead=false
    local is_behind=false
    if git rev-parse --verify "origin/$branch" &>/dev/null; then
        local ahead
        local behind
        ahead=$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo "0")
        behind=$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo "0")

        if [[ "$ahead" -gt 0 ]]; then
            ahead_behind="${ahead_behind}${GREEN}↑$ahead${RESET}"
            is_ahead=true
            ((AHEAD_COUNT++))
        fi
        if [[ "$behind" -gt 0 ]]; then
            ahead_behind="${ahead_behind}${RED}↓$behind${RESET}"
            is_behind=true
            has_issues=true
            ((BEHIND_COUNT++))
        fi
    fi

    # Print main status line
    local status_icon
    if [[ "$has_issues" == true ]]; then
        status_icon="${YELLOW}●${RESET}"
    else
        status_icon="${GREEN}✓${RESET}"
        ((CLEAN_COUNT++))
    fi

    echo -e "${status_icon} ${BOLD}$submodule${RESET} [${branch_status}]"

    # Show details if verbose or if there are issues
    if [[ "$VERBOSE" == true ]] || [[ "$has_issues" == true ]]; then
        if [[ "$is_dirty" == true ]]; then
            echo -e "  ${YELLOW}⚠${RESET}  Working directory has uncommitted changes"
        fi
    fi

    # Always show ahead/behind if present (even in non-verbose mode)
    if [[ -n "$ahead_behind" ]]; then
        echo -e "  ${BLUE}↔${RESET}  Remote: $ahead_behind"
    fi

    # Check shared submodule
    if [[ -d "shared" ]]; then
        check_shared_submodule "shared"
    else
        echo -e "  ${RED}✗${RESET}  ${RED}shared/ directory missing${RESET}"
        ((SHARED_ISSUES++))
    fi

    popd > /dev/null
    echo ""
}

check_shared_submodule() {
    local shared_path=$1

    if [[ ! -d "$shared_path/.git" ]] && [[ ! -f "$shared_path/.git" ]]; then
        echo -e "  ${RED}✗${RESET}  shared: ${RED}Not initialized as git submodule${RESET}"
        ((SHARED_ISSUES++))
        return
    fi

    pushd "$shared_path" > /dev/null

    # Get current branch
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "DETACHED")

    # Get current commit hash (short)
    local commit
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "UNKNOWN")

    # Check if on expected branch (should be 'master' for shared)
    local has_shared_issues=false
    if [[ "$branch" != "master" ]]; then
        has_shared_issues=true
        ((SHARED_ISSUES++))
    fi

    # Check working directory status
    local status
    status=$(git status --porcelain 2>/dev/null || echo "ERROR")
    if [[ -n "$status" ]]; then
        has_shared_issues=true
        ((SHARED_ISSUES++))
    fi

    # Check ahead/behind status
    local ahead_behind=""
    if git rev-parse --verify "origin/$branch" &>/dev/null; then
        local ahead
        local behind
        ahead=$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo "0")
        behind=$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo "0")

        if [[ "$ahead" -gt 0 ]]; then
            ahead_behind="${ahead_behind}${GREEN}↑$ahead${RESET} "
            has_shared_issues=true
        fi
        if [[ "$behind" -gt 0 ]]; then
            ahead_behind="${ahead_behind}${RED}↓$behind${RESET} "
            has_shared_issues=true
        fi
    fi

    # Print shared status
    local shared_icon
    if [[ "$has_shared_issues" == true ]]; then
        shared_icon="${YELLOW}●${RESET}"
    else
        shared_icon="${GREEN}✓${RESET}"
    fi

    local branch_display
    if [[ "$branch" != "master" ]]; then
        branch_display="${YELLOW}$branch${RESET}"
    else
        branch_display="$branch"
    fi

    echo -e "  ${shared_icon} shared/ [$branch_display @ ${GRAY}$commit${RESET}]"

    if [[ "$VERBOSE" == true ]] || [[ "$has_shared_issues" == true ]]; then
        if [[ -n "$status" ]]; then
            echo -e "     ${YELLOW}⚠${RESET}  Working directory has uncommitted changes"
        fi
    fi

    # Always show ahead/behind if present (even in non-verbose mode)
    if [[ -n "$ahead_behind" ]]; then
        echo -e "     ${BLUE}↔${RESET}  Remote: $ahead_behind"
    fi

    popd > /dev/null
}

# Main execution
for submodule in "${SUBMODULES[@]}"; do
    check_submodule "$submodule"
done

# Print summary
echo -e "${BOLD}${CYAN}=== Summary ===${RESET}"
echo -e "Total submodules:     ${BOLD}$TOTAL_SUBMODULES${RESET}"
echo -e "Clean:                ${GREEN}$CLEAN_COUNT${RESET}"
echo -e "With local changes:   ${YELLOW}$DIRTY_COUNT${RESET}"
echo -e "Ahead of remote:      ${GREEN}$AHEAD_COUNT${RESET}"
echo -e "Behind remote:        ${RED}$BEHIND_COUNT${RESET}"
if [[ "$WRONG_BRANCH_COUNT" -gt 0 ]]; then
    echo -e "Wrong branch:         ${YELLOW}$WRONG_BRANCH_COUNT${RESET}"
fi
if [[ "$SHARED_ISSUES" -gt 0 ]]; then
    echo -e "Shared/ issues:       ${YELLOW}$SHARED_ISSUES${RESET}"
fi

# Exit code based on issues
if [[ "$BEHIND_COUNT" -gt 0 ]] || [[ "$SHARED_ISSUES" -gt 0 ]]; then
    exit 1
fi
