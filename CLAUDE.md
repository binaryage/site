# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Agent Guidelines

**Temporary Files and Testing:**
- When AI agents need to create temporary files, run tests, or create proof-of-concept code, use the `_adhoc/` directory in the repository root instead of `/tmp`
- You can create subdirectories within `_adhoc/` as needed for organization
- The `_adhoc/` directory is gitignored and safe for experimentation
- Example: `_adhoc/worktree-test/`, `_adhoc/proof-of-concept/`, etc.

---

## Essential Information

This document (CLAUDE.md) extends README.md with detailed technical information specifically for AI agents working with this codebase.

@README.md

---

## Project Overview

BinaryAge Site is an umbrella project that manages multiple subdomain sites under *.binaryage.com as git submodules. Each subdomain (www, blog, totalfinder-web, totalspaces-web, etc.) is a separate git repository tracked as a submodule. All submodains share common resources through the `shared` submodule (layouts, includes, CSS, JavaScript).

### Git Submodules Architecture

The repository contains 12 subdomain sites as git submodules:
- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site
- **Product sites**: totalfinder-web, totalspaces-web, asepsis-web, totalterminal-web, visor
- **Tool sites**: firequery, firerainbow, firelogger, xrefresh

Each submodule has a `shared` subdirectory (also a git submodule) containing common layouts, includes, CSS (Stylus), and JavaScript (CoffeeScript) resources.

### CRITICAL: Shared Submodule Architecture

**All 12 `shared/` directories across all submodules are clones of the SAME git repository.**

This is the most important architectural concept to understand:

- **Single source of truth**: There is ONE shared repository (github.com/binaryage/shared) that contains layouts, includes, CSS, and JavaScript
- **Make changes once**: When you need to modify shared resources (layouts, CSS, JS), you only need to edit them in ONE place
- **Update submodule pointers**: After pushing changes to the shared repository, update the submodule pointer in each site that needs the changes
- **DO NOT edit 12 times**: Never make the same change in multiple `shared/` directories - they all point to the same repo
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

**For AI agents**: This architecture means you should NEVER iterate through all 12 sites making identical changes to shared resources. Always work with the shared repository directly and then update submodule pointers.

## Detailed Rake Task Reference

See [README.md](README.md) for common usage. This section provides additional technical details.

### Complete Task List

**Setup & Initialization:**
- `rake init` - First-time setup: installs gems, Node deps, inits/updates all git submodules
- `rake hosts` - Show required /etc/hosts entries

**Development:**
- `rake proxy` - Start nginx proxy (requires sudo for port 80)
- `rake serve what=www,blog` - Start Jekyll dev server with LiveReload (port 35729+)
- `rake serve what=all` - Serve all sites
- `rake serve:build` - Serve production builds (port 8080)

**Building:**
- `rake build` - Build all sites for production
- `rake build what=www,blog` - Build specific sites
- `rake clean` - Clean staging directories

**Git Submodule Management:**
- `rake status` - Check submodule status (issues only)
- `rake status verbose=1` - Full status for all submodules
- `rake pin` - Pin all submodules to latest branch tips
- `rake reset` - DESTRUCTIVE: Reset workspace to remote state
- `rake shared:sync` - Sync shared commits across all sites
- `rake shared:sync from=blog` - Sync from specific site

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
- `rake inspect` - List all registered sites
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
- ⚠ (yellow) - Uncommitted changes
- ↔ (blue) - Remote status

**Exit codes:** 0 (all clean), 1 (issues found)

## Architecture Details

### Site Structure (_lib/site.rb)
- Each site has: directory path, port (base 4101+index), name, subdomain, and domain
- Subdomain is extracted by stripping `-web` suffix from directory name (e.g., `totalfinder-web` → `totalfinder`)
- Sites are defined in `_lib/tasks.rake` in the `DIRS` array

### Build System (_lib/build.rb)
- Uses Jekyll as the static site generator
- Custom Jekyll plugins in `_plugins/`:
  - `stylus_converter.rb` - Stylus CSS preprocessing
  - `js_combinator.rb` - JavaScript concatenation from .list files
  - `compressor.rb` - Asset compression
  - `pruner.rb`, `reshaper.rb`, `inline_styles.rb`, etc.
- Configuration is dynamically generated per-site with dev/production modes
- Build artifacts go to `.stage/` directory (gitignored)

### Jekyll Configuration
- Layouts: `shared/layouts/`
- Includes: `shared/includes/`
- Plugins: `../_plugins/` (relative to submodule)
- CSS: Stylus files in `shared/css/`, main file: `site.styl`
- JavaScript: CoffeeScript files in `shared/js/`, concatenated via `.list` files (e.g., `code.list`, `changelog.list`)

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

- `rakefile` - Main entry point, imports `_lib/tasks.rake`
- `_lib/tasks.rake` - All rake task definitions and site configuration
- `_lib/tasks/*.rb` - Organized rake task files (config, build, server, test, workspace, etc.)
- `_lib/build.rb` - Jekyll build logic and configuration generation
- `_lib/workspace.rb` - Git submodule management functions
- `_lib/site.rb` - Site class definition
- `_lib/utils.rb` - Utility functions
- `_lib/store.rb` - FastSpring store template generation
- `Gemfile` - Ruby dependencies (Jekyll, Stylus, CoffeeScript, compression tools)
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
