# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Agent Guidelines

**Temporary Files and Testing:**
- When AI agents need to create temporary files, run tests, or create proof-of-concept code, use the `_adhoc/` directory in the repository root instead of `/tmp`
- You can create subdirectories within `_adhoc/` as needed for organization
- The `_adhoc/` directory is gitignored and safe for experimentation
- Example: `_adhoc/worktree-test/`, `_adhoc/proof-of-concept/`, etc.

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

## Prerequisites

### Development Environment (mise)

This project uses **mise** (a modern polyglot version manager) for managing Ruby and Node.js versions.

**Versions**: Ruby 3.4.7, Node.js 22.21.1 (specified in `.tool-versions`)

**Setup Instructions:**

1. **Install mise**:
   ```bash
   brew install mise
   ```

2. **Activate mise in fish shell**:
   ```bash
   # Add to ~/.config/fish/config.fish
   echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

   Or mise may be automatically activated by Homebrew.

3. **Install direnv** (optional, for project-specific env vars):
   ```bash
   brew install direnv
   echo 'direnv hook fish | source' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

4. **Install project tools**:
   ```bash
   cd /path/to/site
   mise install  # Reads .tool-versions and installs Ruby + Node.js
   ```

5. **Install bundler and gems**:
   ```bash
   gem install bundler
   bundle install
   ```

**Why mise?**
- **Polyglot**: Manages Ruby, Node.js, and 500+ other tools with one unified interface
- **Fast**: Written in Rust for performance
- **Simple**: rbenv-style philosophy - directory-based auto-switching
- **Compatible**: Reads multiple version file formats (.ruby-version, .nvmrc, .tool-versions)
- **Excellent IDE integration**: RubyMine, WebStorm, VS Code all work seamlessly
- **Active development**: Modern tool with strong 2025+ momentum

**How it works:**
- Versions are defined in `.tool-versions` file
- mise automatically switches versions when you `cd` into the project
- No need for manual version switching or shims
- Compatible with direnv for additional environment variables

### Other Requirements
- **nginx**: Required for proxy server (`rake proxy`)

### Node.js Package Manager

The project uses **npm** by default (ships with Node.js), but you can optionally use **yarn** or **bun** by setting the `NODE_PKG_MANAGER` environment variable.

**Default (npm):**
```bash
rake init                    # Uses npm automatically
rake upgrade:node            # Uses npm update
```

**Using yarn:**
```bash
# Install yarn first
npm install -g yarn

# Use yarn for this project
export NODE_PKG_MANAGER=yarn
rake init                    # Uses yarn install
rake upgrade:node            # Uses yarn upgrade
```

**Using bun (fastest):**
```bash
# Install bun via mise
mise use bun@latest

# Use bun for this project
export NODE_PKG_MANAGER=bun
rake init                    # Uses bun install
rake upgrade:node            # Uses bun update
```

**Why npm is the default:**
- Already available (ships with Node.js, no installation needed)
- Universally compatible
- More than fast enough for this project's minimal dependencies (3 packages)
- Simplifies onboarding

**When to use alternatives:**
- **bun**: If you want maximum speed (6-16x faster than npm)
- **yarn**: If you prefer yarn's CLI or have it installed already

## Common Development Commands

### Initial Setup
```bash
rake init                    # First-time setup: installs gems, Node deps, and inits/updates all git submodules
```

### Development Server
```bash
# Terminal 1: Start nginx proxy server (requires sudo for port 80)
rake proxy

# Terminal 2: Start Jekyll development server with live reload
rake serve what=www,totalfinder,blog    # Serve specific sites
rake serve what=all                      # Serve all sites

# Make sure /etc/hosts is configured first:
rake hosts                   # Show required /etc/hosts entries
```

The development server uses Jekyll's native LiveReload feature for automatic browser refresh when files change. Each site gets a dedicated LiveReload port (35729+).

### Testing Production Builds Locally
```bash
# Build sites for production first
rake build what=www,blog     # Build specific sites

# Serve the built static files via nginx proxy (no live reload)
rake serve:build             # Default port 8080
rake serve:build PORT=9000   # Custom port

# Access sites at http://localhost:8080 (or custom port)
```

This is useful for testing production builds locally before deployment, including compression and cache busting.

### Smoke Testing

After building sites, you can run automated smoke tests to verify all sites load correctly without errors:

```bash
# Build sites first
rake build what=all

# Terminal 1: Start the build server (if not already running)
rake serve:build             # Default port 8080
rake serve:build PORT=9000   # Custom port

# Terminal 2: Run smoke tests
rake test:smoke              # Uses port 8080 by default
PORT=9000 rake test:smoke    # Custom port

# Or run without server already running (auto-starts and stops)
rake test:smoke              # Starts server, tests, then stops
```

**What it tests:**
- HTTP status codes (accepts 2xx-3xx, fails on 4xx-5xx)
- JavaScript console errors (filters out non-critical warnings)
- Page loads successfully without timeouts
- Handles redirects gracefully (e.g., support → discuss.binaryage.com)

**Features:**
- Automatically detects all built sites from `.stage/build/` directory
- Uses Playwright for headless browser testing
- Auto-installs Playwright on first run
- Can start/stop `rake serve:build` automatically if needed
- Exits with status code 0 (all passed) or 1 (failures)
- Provides detailed error output for failed tests

**Dependencies:**
- Playwright (`@playwright/test`) - installed via `_node/package.json`
- Chromium browser (~210 MB, auto-downloaded on first run)

**Use cases:**
- CI/CD pipeline integration
- Pre-deployment verification
- Regression testing after build system changes
- Quick sanity check after major changes

### Visual Screenshot Testing

The screenshot testing system captures full-page screenshots of all sites and provides visual diff comparison with highlighted changes.

**Create a screenshot set:**
```bash
# Build sites first
rake build

# Create baseline screenshot set
rake screenshot:create name=baseline desc="Before CSS refactoring"

# Screenshots saved to: .screenshots/baseline/
```

**Compare with baseline:**
```bash
# Make changes and rebuild
rake build

# Compare current build with baseline
rake screenshot:diff name=baseline

# Auto-open HTML report in browser
rake screenshot:diff name=baseline open=1
```

**List screenshot sets:**
```bash
rake screenshot:list
```

**How it works:**
- Uses Playwright to capture full-page PNG screenshots (viewport: 1920x1080)
- Uses ODiff for fast visual comparison (6-7x faster than alternatives)
- Generates interactive HTML report with side-by-side comparison
- Highlights pixel differences in magenta
- Auto-starts/stops build server as needed
- Stores metadata (git commit, timestamp, description)
- Automatically excludes sites from SCREENSHOT_EXCLUDES config (e.g., redirects)

**HTML Report Features:**
- Side-by-side view (Baseline | Current | Diff)
- Jump navigation to changed sites
- Percentage diff per site
- Color-coded highlighting of changes
- Git metadata display

**Use cases:**
- Visual regression testing during CSS refactoring
- Verifying build system changes don't affect output
- Before/after comparison for major updates
- Detecting unintended visual changes

**Dependencies:**
- Playwright (`@playwright/test`) - browser automation
- ODiff (`odiff-bin`) - visual diff tool
- Chromium browser (auto-downloaded on first run)

**Storage:**
- Screenshot sets stored in `.screenshots/` directory
- ~60-120 MB per set (12 sites × 5-10 MB each)
- Diff reports in `.screenshots/.diff-{name}/`

**Configuration:**
- Excluded sites: Configured in `_lib/tasks/config.rb` via `SCREENSHOT_EXCLUDES`
- Default excludes: `['support']` (redirect-only site)
- Add sites to exclude list to skip them entirely during capture/diff

**Note:** Sites configured in SCREENSHOT_EXCLUDES are automatically skipped during both capture and comparison operations.

### Building Sites
```bash
rake build                   # Build all sites for production
rake build what=www,blog     # Build specific sites
```

### Git Submodule Management
```bash
rake status                  # Check status of all submodules (shows issues only)
rake status verbose=1        # Check status with full details for all submodules
rake pin                     # Pin all submodules to latest branch tips
rake reset                   # DESTRUCTIVE: Reset workspace to remote state (destroys local changes)
```

**Status Command Details:**

The `rake status` command provides a comprehensive overview of all git submodules and their `shared/` submodules:

**What it checks:**
- Current branch (main submodules should be on `web`, shared should be on `master`)
- Working directory cleanliness (uncommitted changes)
- Ahead/behind status relative to remote
- Shared submodule commit hashes and status

**Output modes:**
- **Default** (`rake status`): Shows only submodules with issues, plus ahead/behind info
- **Verbose** (`rake status verbose=1`): Shows detailed status for all submodules

**Visual indicators:**
- ✓ (green) - Clean, no issues
- ● (yellow) - Has issues (uncommitted changes, wrong branch, etc.)
- ✗ (red) - Missing or critical error
- ↑N (green) - N commits ahead of remote
- ↓N (red) - N commits behind remote
- ⚠ (yellow) - Uncommitted changes warning
- ↔ (blue) - Remote status indicator

**Exit codes:**
- 0 - All clean
- 1 - Issues found (behind remote or shared issues)

### Publishing
```bash
rake publish                 # Publish all dirty sites
rake publish force=1         # Force publish all sites
rake publish dont_push=1     # Build but don't push
```

### Dependency Management
```bash
rake upgrade                 # Upgrade both Ruby (bundler) and Node dependencies
rake upgrade:ruby            # Upgrade Ruby dependencies only
rake upgrade:node            # Upgrade Node dependencies only
```

### Other Utilities
```bash
rake clean                   # Clean staging directories
rake inspect                 # List all registered sites
rake store                   # Generate FastSpring store template zip
```

### Testing Build Changes

When making significant changes to the build system, use the snapshot/diff system to verify that changes don't unexpectedly alter build output:

```bash
# 1. Create a baseline snapshot before making changes
rake snapshot:create name=baseline desc="Before refactoring"

# 2. Make your code changes

# 3. Rebuild all sites
rake build

# 4. Compare current build with snapshot
rake snapshot:diff name=baseline

# 5. For detailed file-level differences
rake snapshot:diff name=baseline verbose=1
```

**Snapshot Management:**

```bash
# Create a snapshot with description
rake snapshot:create name=<name> desc="<description>"

# List all snapshots
rake snapshot:list

# Compare snapshot with current build
rake snapshot:diff name=<name>           # Summary view
rake snapshot:diff name=<name> verbose=1 # Detailed file-level changes
```

**How it works:**
- `snapshot:create` builds all sites and copies `.stage/build/` to `.snapshots/<name>/`
- Volatile artifacts (`_cache/`, `.configs/`) are excluded to save space
- Metadata is saved (timestamp, git commit hash, description)
- `snapshot:diff` compares snapshots excluding volatile directories
- Exit codes: 0 (identical), 1 (differences found), 2 (error)

**Use cases:**
- Verifying refactoring doesn't change output
- Testing build system modifications
- Ensuring reproducible builds
- Comparing output before/after dependency upgrades

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

## Troubleshooting

### mise issues

**Problem**: mise not activating Ruby/Node or showing wrong versions

**Solution**:
1. Check mise is installed: `mise --version`
2. Check tools are installed: `mise list`
3. Install tools if needed: `mise install`
4. Check mise is activated in shell: `mise current`
5. Verify: `ruby --version` (should show 3.4.7) and `node --version` (should show 22.21.1)

**Problem**: mise shell integration not working

**Solution**: Make sure mise is activated in your shell config:
```bash
# For fish shell
echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

Or if installed via Homebrew, check if it's automatically activated:
```bash
mise doctor  # Shows mise configuration and any issues
```

**Problem**: Tools not auto-switching when cd'ing into project

**Solution**:
1. Check `.tool-versions` file exists: `cat .tool-versions`
2. Run `mise install` to ensure all tools are installed
3. Exit and re-enter the directory: `cd .. && cd site`
4. Check active versions: `mise current`

### General Ruby issues

**Problem**: `bundle install` fails with permission errors

**Solution**: mise installs gems in user space. Never use `sudo`. If you still have issues:
```bash
gem install bundler
bundle install
```

**Problem**: Wrong Ruby version active

**Solution**:
1. Check `.tool-versions` file exists and contains `ruby 3.4.7`
2. Run `mise current` to see active versions
3. Run `mise install` to ensure Ruby 3.4.7 is installed
4. Exit and re-enter directory: `cd .. && cd site`
5. Check Ruby version: `ruby --version`

**Problem**: Jekyll fails with "cannot load such file -- csv (LoadError)" or similar errors

**Solution**: Ruby 3.0+ extracted several standard library gems from core. The Gemfile already includes the necessary stdlib gems (base64, bigdecimal, csv, logger). If you encounter similar errors for other gems, they may need to be added to the Gemfile.

Common Ruby 3.x stdlib gems that may be needed:
- `csv` - CSV file handling
- `base64` - Base64 encoding/decoding
- `bigdecimal` - Arbitrary precision decimal arithmetic
- `logger` - Logging functionality
- `mutex_m` - Mixin to extend objects with synchronization
- `ostruct` - OpenStruct class

### CSS Minification Issues

**Problem**: Build shows warning "Lightning CSS binary not found" or CSS is not minified

**Solution**: The build system uses `lightningcss-cli` (npm package) for CSS minification. Make sure it's installed:

```bash
# Option 1: Run rake init (recommended for new setup)
rake init

# Option 2: Just install node dependencies
cd _node
npm install

# Option 3: Install globally (not recommended, but works)
npm install -g lightningcss-cli
```

**Verification**: Check that lightningcss-cli is available:
```bash
ls -la _node/node_modules/.bin/lightningcss
# Should show a symlink to ../lightningcss-cli/lightningcss
```

**How it works**: The build system uses the local `_node/node_modules/.bin/lightningcss` binary for CSS compression. If the binary is not found, a warning is shown and uncompressed CSS is used as a fallback.

## RubyMine IDE Setup

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
