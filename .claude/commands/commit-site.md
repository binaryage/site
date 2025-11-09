---
description: Intelligently commit changes in site submodule(s)
argument-hint: '[site-name(s)] (optional - shows interactive picker if omitted)'
---

You are executing the /commit-site command to commit changes in one or more site submodules.

**Arguments provided:** $ARGUMENTS

**IMPORTANT RULES:**
- DO NOT use echo or bash output to communicate - output your thoughts as regular text
- Use git commands directly with proper heredoc syntax for commit messages
- Auto-stage all changes before committing
- Include Claude Code footer in all commits
- Be concise in shared submodule summaries (5-10 words)
- Process each site independently

Follow these steps carefully:

## Step 0: Interactive Site Selection (if no arguments provided)

**IF `$ARGUMENTS` is empty or contains only whitespace:**

You need to detect which sites have uncommitted changes and offer an interactive selection.

1. **Get all available sites:**
   ```bash
   grep "path = " .gitmodules | awk '{print $3}'
   ```

2. **Check each site for changes:**
   For each site, run `git status --short` to check if it has uncommitted changes.
   Create a list of sites with changes, along with a count of changed files.

   Example check:
   ```bash
   cd www && git status --short | wc -l
   ```

   Store sites where the count is > 0 (has changes).

3. **Handle different scenarios:**

   - **0 sites with changes:**
     Output: "✓ No changes to commit in any site" and exit successfully.

   - **1 site with changes:**
     Automatically use that site (no need to ask). Set it as `$ARGUMENTS` and proceed to Step 1.
     Output: "Auto-selecting <site-name> (only site with changes)"

   - **2-4 sites with changes:**
     Use `AskUserQuestion` tool to let the user select which site to commit:
     - Question: "Which site would you like to commit?"
     - Header: "Site"
     - multiSelect: false
     - Options: List each site with changed file count in description
       Example: label="www", description="Main site (3 files changed)"

     After user selects, use the selected site as `$ARGUMENTS` and proceed to Step 1.

   - **5+ sites with changes:**
     Use `AskUserQuestion` tool with the first 4 sites (sorted by most changes):
     - Question: "Which site would you like to commit?"
     - Header: "Site"
     - multiSelect: false
     - Options: Top 4 sites by change count + "Other" (automatically added)

     If user selects "Other", ask them to type the site name.
     After selection, use the selected site as `$ARGUMENTS` and proceed to Step 1.

**IF `$ARGUMENTS` has a value:**

Skip this step and proceed directly to Step 1 (backward compatibility with existing usage).

---

## Step 1: Parse Sites

Split the arguments into individual site names. The user may provide one or more sites separated by spaces.

**Special argument "all":** If the user provides `all` as the argument, expand it to include all sites from `.gitmodules`:

```bash
if [[ "$ARGUMENTS" == "all" ]]; then
  SITES=$(grep "path = " .gitmodules | awk '{print $3}')
else
  SITES="$ARGUMENTS"
fi
```

**Flexible name matching:** The user can provide names with or without the `-web` suffix:
- `totalfinder` → will match `totalfinder-web`
- `totalfinder-web` → will match `totalfinder-web`
- `totalspaces` → will match `totalspaces-web`
- `www`, `blog`, `visor` → work as-is (no suffix needed)

For example:
- `$ARGUMENTS = "www"` → process only www
- `$ARGUMENTS = "www blog"` → process www and blog
- `$ARGUMENTS = "totalfinder totalspaces"` → process totalfinder-web and totalspaces-web
- `$ARGUMENTS = "www blog totalfinder"` → process www, blog, and totalfinder-web
- `$ARGUMENTS = "all"` → process ALL sites from .gitmodules

Create a list of sites to process.

## Step 2: Get Available Sites

Before processing, read `.gitmodules` to get the list of available site submodules dynamically:

```bash
grep "path = " .gitmodules | awk '{print $3}'
```

This will list all submodule directories. Store this list for reference.

## Step 3: Process Each Site

For each site in the user-provided list, follow steps 4-6 below. Keep track of which sites were processed and what actions were taken.

---

## Step 4: Validate Site

For the current site being processed, normalize and validate the site name:

**Normalization logic:**
1. Try the name as-is first: `cd [SITE_NAME] 2>/dev/null`
2. If that fails and the name doesn't end with `-web`, try with `-web` suffix: `cd [SITE_NAME]-web 2>/dev/null`
3. Use whichever version exists as the actual site directory

**Example:**
- Input: `totalfinder` → Tries `totalfinder` (fails) → Tries `totalfinder-web` (succeeds) → Use `totalfinder-web`
- Input: `totalfinder-web` → Tries `totalfinder-web` (succeeds) → Use `totalfinder-web`
- Input: `www` → Tries `www` (succeeds) → Use `www`

```bash
# Try as-is first
if [ -d "[SITE_NAME]" ]; then
  ACTUAL_SITE="[SITE_NAME]"
# Try with -web suffix if not already present
elif [[ "[SITE_NAME]" != *-web ]] && [ -d "[SITE_NAME]-web" ]; then
  ACTUAL_SITE="[SITE_NAME]-web"
else
  echo "INVALID"
fi
```

If neither directory exists, inform the user with the dynamic list:
"⚠️  Skipping '[SITE_NAME]': directory not found. Available sites: [list from .gitmodules]"

Then move to the next site. Do NOT exit completely - continue processing remaining sites.

**Use `ACTUAL_SITE` for all subsequent operations** (not the original input name).

## Step 5: Check Git Status

Navigate to the current site directory (using the normalized `ACTUAL_SITE` name) and check status:

```bash
cd $ACTUAL_SITE
git status --short
```

If there's no output (clean working copy), inform the user:
"✓ $ACTUAL_SITE: No changes to commit"

Then move to the next site.

## Step 6: Determine What's Modified

Analyze what files are modified. You need to distinguish between:
- **Shared submodule pointer only**: Only line showing ` M shared` in git status
- **Other files**: Any files other than shared

Check the status output:
- If ONLY ` M shared` appears → Go to **Scenario A**
- If other files appear (with or without shared) → Go to **Scenario B**

---

## Scenario A: Only Shared Submodule Pointer Modified

The shared submodule pointer has been updated. Create a commit describing what changed in shared.

### Get the commit range:

```bash
cd $ACTUAL_SITE

# Get old and new commit hashes
OLD_COMMIT=$(git diff shared | grep '^-Subproject commit' | awk '{print $3}')
NEW_COMMIT=$(git diff shared | grep '^+Subproject commit' | awk '{print $3}')

# Navigate to shared and get the commit log
cd shared
git log --oneline $OLD_COMMIT..$NEW_COMMIT
cd ..
```

### Create the commit:

1. Analyze the commit log output from shared
2. Create a **very brief** 5-10 word summary (e.g., "layout improvements and bug fixes", "updated footer styles", "fixed mobile navigation")
3. Stage the shared pointer: `git add shared`
4. Commit with this format:

```bash
git commit -m "$(cat <<'EOF'
Updated shared ([your brief 5-10 word summary])

Shared submodule commits:
[paste the git log output here, each commit on its own line]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Tell the user what you committed for this site, then move to the next site.

---

## Scenario B: Other Files Modified (with or without shared)

Non-shared files have been modified. Handle them first, then handle shared if it's also modified.

### Step B1: Stage all changes

```bash
cd $ACTUAL_SITE
git add .
```

### Step B2: Check what's staged

```bash
git diff --cached --name-only
```

### Step B3: Determine if shared is also modified

Look at the staged files list:
- If `shared` appears in the list → Shared is also modified
- Otherwise → Only non-shared files

### Step B4: Commit non-shared files first

If shared is in the staged files:

```bash
# Unstage shared temporarily
git reset HEAD shared

# Check what remains staged
git diff --cached
```

Analyze the remaining diff and generate an appropriate commit message based on what changed.

Then commit:

```bash
git commit -m "$(cat <<'EOF'
[Your auto-generated commit message describing the changes]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Step B5: Handle shared pointer if it was modified

If shared was in the staged files list from Step B3, now handle it using the same process as **Scenario A** above:
- Get old/new commit hashes
- Get commit log from shared directory
- Create brief summary
- Commit the shared pointer

If shared was NOT in the staged files, you're done with this site. Move to the next site.

---

## Step 7: Final Summary

After processing all sites, provide a comprehensive summary of all actions taken.

Example output format:

```
✓ Processed 3 site(s):

www:
  ✓ Committed: Updated shared (layout improvements)

blog:
  ✓ Committed: Add new blog post about macOS
  ✓ Committed: Updated shared (layout improvements)

totalfinder-web:
  ✓ No changes to commit
```

Or if there were issues:

```
✓ Processed 2 site(s):

www:
  ✓ Committed: Updated shared (footer fixes)

invalid-site:
  ⚠️  Skipped: directory not found
```

Be concise but clear about what happened with each site.
