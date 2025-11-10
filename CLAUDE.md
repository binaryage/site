# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Agent Guidelines

**Temporary Files and Testing:**
- When AI agents need to create temporary files, run tests, or create proof-of-concept code, use the `_adhoc/` directory in the repository root instead of `/tmp`
- You can create subdirectories within `_adhoc/` as needed for organization
- The `_adhoc/` directory is gitignored and safe for experimentation
- Example: `_adhoc/worktree-test/`, `_adhoc/proof-of-concept/`, etc.

**mise Environment Activation:**
- Always execute Ruby/Rake commands through mise's activated environment
- **Recommended setup**: Enable automatic mise activation via shell integration or direnv (see README.md "Automated mise Activation" section)
- **Without activation**: Use `mise exec -- bundle exec rake status` explicitly
- **Why**: macOS's system Bundler is too old and will raise "You must use Bundler 2" otherwise
- Shell activation eliminates the need for `mise exec --` prefix on every command

**Working with Site Submodules - NEVER use hardcoded lists:**
- **DO NOT hardcode** site names in scripts, documentation, or code examples
- **DO NOT use** lists like `www blog totalfinder-web totalspaces-web ...`
- **DO NOT hardcode** site counts like "12 sites" or "all 12 submodules"
  - Site count can change over time as sites are added/removed/archived
  - Use generic language: "multiple sites", "all sites", "each site"
  - Let dynamic discovery determine the actual count at runtime
- **Always discover dynamically** - see detailed comparison below

**Why we parse `.gitmodules` instead of `git submodule foreach`:**

This codebase uses `git config --file .gitmodules` for getting submodule lists, NOT `git submodule foreach`. This is intentional and optimal for our use case:

**Use `git config --file .gitmodules` for:**
- ✅ **Getting list of all submodules** (including uninitialized)
- ✅ **Configuration and setup** (`rake init`, `SITES` array initialization)
- ✅ **Validation** (checking if site name exists)
- ✅ **Performance-critical operations** (22x faster: 6ms vs 132ms)
- ✅ **Ruby integration** (clean functional processing)
- ✅ **Deterministic ordering** (file order, critical for port assignments)

```ruby
# Correct approach used in _ruby/tasks/config.rb:
DIRS = `git config --file .gitmodules --get-regexp path`
         .lines.map { |line| line.split[1] }
# Works with uninitialized submodules, fast, deterministic order
```

**Use `git submodule foreach` for:**
- ✅ **Running commands INSIDE each submodule directory**
- ✅ **Batch operations on initialized submodules**
- ✅ **Accessing runtime state** (current branch, commit)
- ✅ **Shell-based iteration workflows**

```bash
# Good use case for foreach:
git submodule foreach 'git status'
git submodule foreach 'git checkout web'
git submodule foreach 'bundle install'
```

**Key differences:**
- `git config` works with **uninitialized** submodules (critical for `rake init`)
- `git submodule foreach` only iterates **initialized** submodules
- `git config` is **22x faster** (important for operations that run frequently)
- Order matters: `git config` preserves file order (needed for port assignments)

**Why this matters:**
- The root repository contains only site submodules (no other types)
- Dynamic discovery ensures code/docs stay in sync when sites are added/removed
- Using the right tool for each job eliminates maintenance burden

---

## Essential Information

This document (CLAUDE.md) extends README.md with detailed technical information specifically for AI agents working with this codebase.

@README.md

---

## Project Overview

BinaryAge Site is an umbrella project that manages multiple subdomain sites under *.binaryage.com as git submodules. Each subdomain (www, blog, totalfinder-web, totalspaces-web, etc.) is a separate git repository tracked as a submodule. All submodains share common resources through the `shared` submodule (layouts, includes, CSS, JavaScript).

### Git Submodules Architecture

The repository contains multiple subdomain sites as git submodules:
- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site
- **Product sites**: totalfinder-web, totalspaces-web, asepsis-web, totalterminal-web, visor
- **Tool sites**: firequery, firerainbow, firelogger, xrefresh

Each submodule has a `shared` subdirectory (also a git submodule) containing common layouts, includes, CSS (plain CSS with modern nesting), and JavaScript (modern ES builds) resources.

### CRITICAL: Shared Submodule Architecture

**All `shared/` directories across all submodules are clones of the SAME git repository.**

This is the most important architectural concept to understand:

- **Single source of truth**: There is ONE shared repository (github.com/binaryage/shared) that contains layouts, includes, CSS, and JavaScript
- **Make changes once**: When you need to modify shared resources (layouts, CSS, JS), you only need to edit them in ONE place
- **Update submodule pointers**: After pushing changes to the shared repository, update the submodule pointer in each site that needs the changes
- **DO NOT edit multiple times**: Never make the same change in multiple `shared/` directories - they all point to the same repo
- **Recommended workflow**: Make shared changes via `www/shared`, then update pointers in other sites

### Manual Shared Synchronization

When you make changes to the shared repository, use the **manual sync command** to propagate commits across all sites.

**Sync command:**
```bash
rake shared:sync          # Sync from www/shared (default)
rake shared:sync from=blog  # Sync from specific site's shared directory
```

**How it works:**
- Fetches the HEAD commit from source shared directory
- Uses local filesystem paths (no network required)
- Updates all other shared directories to the same commit
- **Syncs remote tracking branch state** - keeps `origin/master` refs in sync across all shared directories
- Keeps HEAD pointing to `master` branch (not detached)
- Skips directories with uncommitted changes
- Fast and reliable (~1 second for all 11 sites)
- **Does NOT push** - all remote pushes are manual and controlled by you

**Example workflow:**

```bash
# 1. Make changes in ANY shared directory (typically www/shared)
cd www/shared
# ... edit files ...
git add .
git commit -m "Update shared layout"

# 2. Manually sync to all other shared directories
cd ../..  # Back to site root
rake shared:sync

# Output:
# Syncing from www/shared (abc1234)
#   ✅ blog/shared → abc1234
#   ✅ totalfinder-web/shared → abc1234
#   ... (all 11 other sites)
# ✨ Synced 11 site(s)

# 3. (OPTIONAL) Push shared changes to remote when ready
# cd www/shared
# git push origin master

# 4. (OPTIONAL) Update the submodule pointer in sites that need the changes
cd totalfinder-web
git add shared  # Update pointer to new shared commit
git commit -m "Update shared submodule"
# git push origin web  # (OPTIONAL) Push to web branch when ready to deploy

# Repeat step 4 for other sites as needed
```

**Why manual sync?**
- Git's submodule architecture prevents reliable automatic synchronization from post-commit hooks
- Manual sync is fast, explicit, and always works correctly
- Gives you control over when synchronization happens

**Important note about submodule pointers:**
- ✅ **DO commit** `shared` submodule pointer updates in each website (as shown above)
- ❌ **DON'T commit** root-level submodule pointers (www, blog, etc.) in the main `site` repo
- The hookgun deployment system handles root-level pointers automatically

**For AI agents**: This architecture means you should NEVER iterate through all sites making identical changes to shared resources. Always work with the shared repository directly and then update submodule pointers.

## Detailed Rake Task Reference

See [README.md](README.md) for common usage. This section provides additional technical details.

### Complete Task List

**Setup & Initialization:**
- `rake init` - First-time setup: installs gems, Node deps, inits/updates all git submodules
- `rake hosts` - Show required /etc/hosts entries

**Development:**
- `rake proxy` - Start nginx proxy (requires sudo for port 80)
- `rake serve` - Start Jekyll dev server with LiveReload for all sites (default, port 35729+)
- `rake serve what=www,blog` - Start Jekyll dev server for specific sites only
- `rake serve:build` - Serve production builds (port 8080)

**Building:**
- `rake build` - Build all sites for production
- `rake build what=www,blog` - Build specific sites
- `rake clean` - Clean staging directories

**Git Submodule Management:**
- `rake status` - Check submodule status (issues only)
- `rake status verbose=1` - Full status for all submodules
- `rake pin` - Pin all submodules to latest branch tips
- `rake shared:sync` - Sync shared commits across all sites
- `rake shared:sync from=blog` - Sync from specific site
- `rake hooks:install` - Install pre-push hooks to all submodules
- `rake hooks:uninstall` - Remove pre-push hooks from all submodules
- `rake hooks:status` - Show git hook installation status
- `rake remotes:list` - Show current remote URLs for all sites
- `rake remotes:ssh` - Fix remote URLs to use SSH format

**Testing:**
- `rake test:smoke` - Run automated smoke tests (Playwright)
- `rake snapshot:create name=X desc="..."` - Create build snapshot
- `rake snapshot:diff name=X` - Compare with snapshot
- `rake snapshot:list` - List all snapshots
- `rake screenshot:create name=X desc="..."` - Create screenshot baseline
- `rake screenshot:diff name=X` - Compare screenshots with visual diff
- `rake screenshot:list` - List all screenshot sets

**Publishing:**
- `rake publish` - Publish all dirty sites
- `rake publish force=1` - Force publish all sites
- `rake publish dont_push=1` - Build but don't push

**Maintenance:**
- `rake upgrade` - Upgrade Ruby + Node dependencies
- `rake upgrade:ruby` - Upgrade Ruby gems only
- `rake upgrade:node` - Upgrade Node packages only
- `rake inspect` - List all registered sites with details
- `rake inspect verbose=1` - Show additional configuration details
- `rake store` - Generate FastSpring store template zip

### Advanced Testing System Details

#### Smoke Testing (`rake test:smoke`)
- Uses Playwright for headless browser testing
- Auto-detects all built sites from `.stage/build/`
- Tests HTTP status codes, JavaScript console errors, page load success
- Auto-installs Playwright on first run (~210 MB Chromium)
- Exit codes: 0 (all passed), 1 (failures)
- Filters non-critical console warnings

#### Snapshot System (`rake snapshot:*`)
- Captures full build output to `.snapshots/<name>/`
- Excludes volatile artifacts: `_cache/`, `.configs/`, `atom.xml`
- Stores metadata: timestamp, git commit, description
- Diff compares file trees excluding volatile directories
- Exit codes: 0 (identical), 1 (differences), 2 (error)
- Use for verifying refactoring doesn't change build output

#### Screenshot System (`rake screenshot:*`)
- Captures full-page PNG screenshots (viewport: 1920x1080)
- Uses ODiff for visual comparison (6-7x faster than pixelmatch)
- Generates HTML report with side-by-side comparison
- Magenta highlighting for pixel differences
- Auto-starts/stops build server as needed
- Storage: `.screenshots/` (~60-120 MB per set)
- Excludes sites via SCREENSHOT_EXCLUDES config
- Use for visual regression testing during CSS changes

### Git Submodule Status Command

The `rake status` command provides comprehensive overview of all git submodules.

**What it checks:**
- Current branch (main submodules: `web`, shared: `master`)
- Working directory cleanliness
- Ahead/behind status relative to remote
- Shared submodule commit hashes

**Visual indicators:**
- ✓ (green) - Clean, no issues
- ● (yellow) - Has issues (uncommitted changes, wrong branch)
- ✗ (red) - Missing or critical error
- ↑N (green) - N commits ahead
- ↓N (red) - N commits behind
- ⚠ (yellow) - Uncommitted changes (non-shared files)
- ↻ (blue) - Only shared submodule pointer updated (normal after `rake shared:sync`)
- ↔ (blue) - Remote status

**Exit codes:** 0 (all clean), 1 (issues found)

### Pinning Submodules to Branch Tips (`rake pin`)

Git submodules naturally end up in "detached HEAD" state after various operations. The `rake pin` task fixes this by checking out the correct tracking branch in each submodule.

**When submodules become detached:**
- After `git pull` in the root repository
- After `git submodule update`
- After pulling/fetching changes in individual submodules
- After cloning the repository

**What `rake pin` does:**
- Checks out `web` branch in all site submodules
- Checks out `master` branch in all shared submodules
- Non-destructive - preserves uncommitted changes (will fail if conflicts exist)

**Typical workflow:**

```bash
# Scenario 1: After pulling changes in the root repo
git pull                    # Updates submodule pointers → detached HEAD
rake pin                    # Moves submodules back to branch tips

# Scenario 2: Getting latest changes
cd www
git fetch origin            # Get latest commits
cd ..
rake pin                    # Checkout latest origin/web

# Scenario 3: After git submodule update
git submodule update        # Updates to specific commits → detached HEAD
rake pin                    # Return to branch tips
```

**Important distinctions:**

| Task | Purpose | Destructive? | When to use |
|------|---------|--------------|-------------|
| `rake pin` | Checkout tracking branches | No | Fix detached HEAD, get to latest branch tip |
| `rake shared:sync` | Sync shared commits across sites | No | After updating shared repository |

**Note:** The pre-push hook and hookgun serve different purposes - they don't replace `rake pin`. The hook prevents bad pushes, hookgun updates remote pointers, but only `rake pin` manages local branch state.

### Managing Git Remote URLs (`rake remotes:*`)

These tasks help manage and verify git remote URLs across all submodules.

#### Listing Remote URLs (`rake remotes:list`)

Shows the current remote URL for each site's `origin` remote:

```bash
rake remotes:list
```

**Output format:**
- Green URL with "(SSH)" indicator - Using SSH format (recommended)
- Yellow URL with "(HTTPS)" indicator - Using HTTPS format
- Red "no origin remote" - No origin configured

**Example output:**
```
  www: git@github.com:binaryage/www.git (SSH)
  blog: https://github.com/binaryage/blog.git (HTTPS)
  totalfinder-web: git@github.com:binaryage/totalfinder-web.git (SSH)
```

#### Fixing URLs to SSH (`rake remotes:ssh`)

Automatically converts all submodule remote URLs from HTTPS to SSH format:

```bash
rake remotes:ssh
```

**What it does:**
- Scans all site submodules
- Identifies HTTPS URLs (github.com)
- Converts to SSH format: `git@github.com:binaryage/REPO.git`
- Preserves repository names from existing URLs
- Skips sites already using SSH

**Use case:** After cloning with HTTPS URLs, quickly convert all submodules to SSH for easier authenticated pushes.

**Exit codes:** 0 (success), 1 (failures occurred)

### Inspecting Registered Sites (`rake inspect`)

Displays a comprehensive table of all registered sites with their configuration.

```bash
rake inspect              # Standard table view
rake inspect verbose=1    # Include additional details
```

**Information shown:**
- Site directory name
- Subdomain (extracted from directory name)
- Port number (for Jekyll development server)
- Full domain (subdomain + binaryage.com/org)

**Example output:**
```
=== Registered Sites (12) ===

Site               Subdomain      Port   Domain
─────────────────────────────────────────────────────────────
www                www            4101   www.binaryage.com
blog               blog           4102   blog.binaryage.com
totalfinder-web    totalfinder    4103   totalfinder.binaryage.com
...
```

**Use case:** Verify site configuration, check port assignments, or understand subdomain mapping.

## Architecture Details

### Site Structure (_ruby/lib/site.rb)
- Each site has: directory path, port (base 4101+index), name, subdomain, and domain
- Subdomain is extracted by stripping `-web` suffix from directory name (e.g., `totalfinder-web` → `totalfinder`)
- Sites are defined in `_ruby/tasks.rake` in the `DIRS` array

### Build System (_ruby/lib/build.rb)
- Uses Jekyll as the static site generator
- Custom Jekyll plugins in `_ruby/jekyll-plugins/`:
  - `css_bundler.rb` - CSS bundling via Jekyll Hook + Lightning CSS processing
  - `js_combinator.rb` - JavaScript concatenation from .list files
  - `compressor.rb` - Asset compression
  - `pruner.rb`, `reshaper.rb`, `inline_styles.rb`, etc.
- Configuration is dynamically generated per-site with dev/production modes
- Build artifacts go to `.stage/` directory (gitignored)

### Jekyll Configuration
- Layouts: `shared/layouts/`
- Includes: `shared/includes/`
- Plugins: `../_ruby/jekyll-plugins/` (relative to submodule)
- CSS: Plain CSS files in `shared/css/`, bundle entry point: `site.bundle.css`
- JavaScript: Plain `.js` sources in `shared/js/`, concatenated via `.list` files (e.g., `code.list`, `changelog.list`)

### Development vs Production
- Dev mode (`dev: true`): Uses binaryage.org domain, no compression, debug enabled
- Production mode: Uses binaryage.com, compression enabled, cache busting

### Deployment Flow
1. Make changes in a subsite repository
2. Push changes to the `web` branch
3. Post-receive hook (`hookgun`) builds the site
4. Static files pushed to `gh-pages` branch
5. GitHub Pages deploys automatically
6. **Root-level submodule pointer AUTOMATICALLY updated in this `site` repo by hookgun**

`hookgun` lives in BinaryAge's deployment infrastructure (outside this repository). When you need to troubleshoot or update it, contact maintainers rather than searching inside `site/`.

**IMPORTANT - Understanding Submodule Pointer Updates:**

There are **two levels** of submodules in this project, each handled differently:

1. **Root-level submodules** (www, blog, totalfinder-web, etc. in main `site` repo):
   - **DO NOT manually commit** pointer updates in the `site` repository
   - The `hookgun` post-receive hook automatically updates these pointers when you push to a submodule's `web` branch
   - You will see "modified: www (new commits)" in git status - this is normal, **ignore and don't commit**

2. **Shared submodule** (the `shared/` directory inside each website):
   - **DO manually commit** pointer updates in each website repository
   - Each website tracks which version of `shared` it uses
   - When you update shared resources, commit the pointer update: `git add shared && git commit -m "Update shared submodule"`
   - Push is OPTIONAL and should only be done when ready to deploy

**Important**: When pushing, always push the `shared` submodule changes to origin (master branch) first before pushing website changes, if you modified shared resources. (See [CRITICAL: Shared Submodule Architecture](#critical-shared-submodule-architecture) above for details on how the shared repository works.)

## Configuration Files

- `rakefile` - Main entry point, imports `_ruby/tasks.rake`
- `_ruby/tasks.rake` - All rake task definitions and site configuration
- `_ruby/tasks/*.rb` - Organized rake task files (config, build, server, test, workspace, etc.)
- `_ruby/lib/build.rb` - Jekyll build logic and configuration generation
- `_ruby/lib/workspace.rb` - Git submodule management functions
- `_ruby/lib/site.rb` - Site class definition
- `_ruby/lib/utils.rb` - Utility functions
- `_ruby/lib/store.rb` - FastSpring store template generation
- `_ruby/Gemfile` - Ruby dependencies (Jekyll, Terser, Tilt, HTML helpers)
- `_node/package.json` - Node dependencies (lightningcss-cli for CSS minification, Playwright for testing, ODiff for visual diffs)
- `_node/smoke-test.mjs` - Playwright-based smoke test script
- `_node/screenshot-capture.mjs` - Screenshot capture script for visual testing
- `_node/screenshot-diff.mjs` - Visual diff comparison script using ODiff

## Working with Submodules

### Making Changes to Website Content

When making changes to a website (e.g., totalfinder-web):

1. Navigate into the website submodule: `cd totalfinder-web`
2. Make sure you're on the `web` branch
3. Make your changes and commit them
4. **If you modified shared resources** (layouts, CSS, JS):
   - First: `cd shared`, commit and push changes to shared repo
   - Then: `cd ..`, `git add shared`, commit the pointer update
5. Push changes to the website's `web` branch
6. The `hookgun` hook will automatically build and update the root-level pointer

### Using the /commit-site Slash Command

The `/commit-site` command provides an intelligent, automated way to commit changes in site submodules. It handles both shared submodule pointer updates and regular file changes with appropriate commit messages.

**Usage:**

```bash
/commit-site                    # Interactive picker - shows only sites with changes
/commit-site www                # Commit changes in www
/commit-site www blog           # Commit changes in multiple sites
/commit-site totalfinder        # Works with or without -web suffix
/commit-site all                # Commit changes in all sites
```

**What it does:**

1. **Interactive site selection** (when called without arguments):
   - Detects which sites have uncommitted changes
   - Shows interactive picker with change counts
   - Auto-selects if only one site has changes

2. **Smart change detection**:
   - Distinguishes between shared submodule pointer updates and other file changes
   - Creates appropriate commit messages for each type

3. **Shared pointer updates** (when only `shared` is modified):
   - Analyzes commits in shared submodule
   - Generates concise summary (5-10 words)
   - Includes full commit log in commit message body

4. **Regular file changes**:
   - Auto-stages all changes
   - Generates descriptive commit message based on diff
   - Handles shared pointer separately if also modified

5. **Flexible naming**:
   - Accepts both `totalfinder` and `totalfinder-web`
   - Works with all site names from `.gitmodules`

**Example workflow:**

```bash
# After running rake shared:sync, multiple sites have shared pointer updates
/commit-site
# → Shows: "www (shared pointer)", "blog (shared pointer)", "totalfinder-web (shared pointer)"
# → Select which sites to commit
# → Each gets a commit like: "Updated shared (layout improvements)"

# Or commit specific sites directly
/commit-site www blog
# → Commits both sites automatically
```

**Important notes:**
- All commits include Claude Code footer automatically
- Does NOT push to remote - pushing is always manual
- Validates site names against `.gitmodules`
- Processes multiple sites independently
- Shows summary of all actions taken

### Understanding the Two Levels of Submodules

**Level 1 - Root-level submodules** (in main `site` repo):
- **DO NOT manually commit** these pointer updates
- Hookgun automatically updates them when you push to `web` branch
- Example: When you see "modified: www (new commits)" in the root repo, **ignore it**

**Level 2 - Shared submodule** (inside each website):
- **DO manually commit** these pointer updates in each website
- Each website tracks its own version of shared
- Example: After updating shared: `git add shared && git commit -m "Update shared"`

**Tip**: Use `git submodule foreach` for batch operations across all submodules.

### Git Hooks for Shared Submodule Safety

To prevent accidentally pushing website changes that depend on unpushed shared submodule commits, the repository includes a pre-push git hook.

**What it does:**
- Automatically checks when pushing to `web` branch
- Verifies that shared submodule commits are pushed to GitHub before allowing website push
- Performs auto-fetch of `origin/master` in shared/ to ensure refs are up-to-date
- Shows clear error messages with guidance when blocking a push
- Can be bypassed with `git push --no-verify` if needed (not recommended)

**Installation:**

The hook is automatically installed when you run:
```bash
rake init
```

**Manual management:**

```bash
rake hooks:install    # Install hooks to all submodules
rake hooks:uninstall  # Remove hooks from all submodules
rake hooks:status     # Show installation status
```

**Example workflow with the hook:**

```bash
# 1. Make changes in shared
cd www/shared
git commit -m "Update layout"

# 2. Try to push website changes (will be blocked)
cd ..
git add shared
git commit -m "Update shared submodule"
git push origin web
# ❌ ERROR: Cannot push - shared submodule has unpushed commits

# 3. Push shared first
cd shared
git push origin master

# 4. Now push website changes (will succeed)
cd ..
git push origin web
# ✓ Shared submodule is up to date
```

**Technical details:**
- Hook location: `.git/modules/<site>/hooks/pre-push`
- Template: `_ruby/tasks/hooks/pre-push.template`
- Only checks `web` branch (deployment branch)
- Respects standard git `--no-verify` bypass flag

## Local Development Domains

- Development uses `binaryage.org` (configured in `/etc/hosts`)
- Production uses `binaryage.com`
- Nginx proxy runs on port 80, individual Jekyll servers on ports 4101+
- Each site is accessible at `http://{subdomain}.binaryage.org`

## Advanced Troubleshooting & IDE Setup

See [README.md](README.md) for basic troubleshooting (mise, Ruby, bundle install, etc.).

### RubyMine IDE Setup

### Setting up Ruby SDK from mise

RubyMine has excellent support for mise. The IDE can detect mise-installed Ruby versions and use them directly.

**Ruby interpreter path**: Find it with: `mise where ruby@3.4.7`
Typically: `/Users/darwin/.local/share/mise/installs/ruby/3.4.7/bin/ruby`

**Method 1: Using RubyMine UI (Recommended)**

For RubyMine 2025.2+:

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Languages & Frameworks → Ruby Interpreters**
3. Click **+** → **Add Local Interpreter...**
4. Browse to the Ruby interpreter path (use `mise where ruby@3.4.7` to find it)
5. The path should be: `$(mise where ruby@3.4.7)/bin/ruby`
6. Click **OK** to add the interpreter
7. Select the newly added `ruby-3.4.7` as the project interpreter
8. Click **Apply** and **OK**

For older RubyMine versions (pre-2025.2):

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Languages & Frameworks → Ruby SDK and Gems**
3. Click the **+** button → **New local...**
4. Browse to: `$(mise where ruby@3.4.7)/bin/ruby`
5. Click **OK** to add the SDK
6. Select the newly added SDK as the project SDK
7. Click **Apply** and **OK**

**Method 2: Manual configuration**

Edit `.idea/site.iml` and change the SDK line:
```xml
<orderEntry type="jdk" jdkName="ruby-3.4.7" jdkType="RUBY_SDK" />
```

Then restart RubyMine.

### Setting Environment Variables (Optional)

If you need environment variables from `.envrc`, you can use the direnv plugin:

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Plugins**
3. Search for **"direnv integration"**
4. Install the plugin
5. Restart RubyMine
6. The plugin will automatically detect `.envrc` and load environment variables

**Note**: mise handles Ruby environment setup automatically, so this is only needed if you have custom environment variables in `.envrc`.

### Verifying Setup

After configuration, verify the setup:

1. Open the **Terminal** tool window in RubyMine (⌥F12)
2. Run: `ruby --version`
   - Should show: `ruby 3.4.7 (2025-07-16 revision 20cda200d3)`
3. Run: `which ruby`
   - Should show mise shim or direct path to mise Ruby
4. Run: `mise current`
   - Should show: `ruby 3.4.7` and `node 22.21.1`
5. Run: `bundle exec jekyll --version`
   - Should work without errors

### Run Configurations

When creating Run/Debug configurations for Rake tasks:

1. Go to **Run → Edit Configurations**
2. For any Rake task configuration:
   - **Ruby SDK**: Select the mise-installed `ruby-3.4.7`
   - **Working directory**: `/Users/darwin/x/site`
   - RubyMine will automatically use the correct Ruby and gems

Common Rake tasks to configure:
- `rake build what=www`
- `rake serve what=www,totalfinder`
- `rake clean`

## WebStorm IDE Setup (for Node.js)

### Setting up Node.js from mise

WebStorm can use mise-installed Node.js for running JavaScript/TypeScript tools.

**Node.js path**: Find it with: `mise where node@22`
Typically: `/Users/darwin/.local/share/mise/installs/node/22.21.1/bin/node`

**Setup Instructions:**

1. Open **WebStorm → Settings/Preferences** (⌘,)
2. Navigate to **Languages & Frameworks → Node.js**
3. For **Node interpreter**, click **...** button
4. Click **+** → **Add...**
5. Browse to: `$(mise where node@22)/bin/node`
6. Click **OK**
7. Select the newly added Node.js interpreter
8. Click **Apply** and **OK**

WebStorm will now use the mise-installed Node.js for all JavaScript tooling (npm, or your configured package manager).
