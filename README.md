# BinaryAge Site

This is an umbrella project that manages multiple subdomain sites under [*.binaryage.com](http://www.binaryage.com). It provides:

  * Local development server with live reload
  * Maintenance utilities for managing git submodules
  * Build and deployment tools

## The Idea

The architecture uses one repository with all subdomains as separate repositories, each tracked as an individual git submodule. Individual sites typically depend on [shared](https://github.com/binaryage/shared) resources (layouts, CSS, JavaScript) - also tracked as a git submodule.

This design allows us to:
- Reconstruct the entire site to any point in history
- Maintain granular commit control for individual subdomains
- Benefit from GitHub's transparency and collaboration features

```
.
├── www                    # Main binaryage.com site
│   ├── shared             # Shared resources (submodule)
│   ├── index.md
│   ...
├── totalfinder-web        # TotalFinder product site
│   ├── shared
│   ├── index.md
│   ...
├── totalspaces-web        # TotalSpaces product site
│   ├── shared
│   ├── index.md
│   ...
├── blog                   # Blog subdomain
│   ├── shared
│   ...
...
```

### Project Scale

The repository contains **12 subdomain sites** as git submodules:
- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site
- **Product sites**: totalfinder-web, totalspaces-web, totalterminal-web, asepsis-web, visor
- **Tool sites**: firequery, firerainbow, firelogger, xrefresh

## Shared Resources

### Understanding the Shared Submodule Architecture

**CRITICAL**: All 12 `shared/` directories across all submodules point to the SAME git repository ([binaryage/shared](https://github.com/binaryage/shared)).

This means:
- **Single source of truth**: One shared repository contains all layouts, includes, CSS, and JavaScript
- **Edit once**: Changes to shared resources only need to be made in ONE place
- **Sync across sites**: Use `rake shared:sync` to propagate commits to all sites

**Shared repository structure:**
  * [layouts](https://github.com/binaryage/shared/tree/master/layouts) - Jekyll layout files (not included in generated sites)
  * [includes](https://github.com/binaryage/shared/tree/master/includes) - Includes for layout files
  * [root](https://github.com/binaryage/shared/tree/master/root) - Files moved to site root after generation (e.g., 404.html)
  * [img](https://github.com/binaryage/shared/tree/master/img) - Shared images
  * [css](https://github.com/binaryage/shared/tree/master/css) - Shared CSS files (Stylus preprocessing, Lightning CSS minification)
  * [js](https://github.com/binaryage/shared/tree/master/js) - Shared JavaScript files (concatenated via [.list files](https://github.com/binaryage/shared/blob/master/js/code.list), minified with Terser)

### Working with Shared Resources

**Typical workflow:**

```bash
# 1. Make changes in ANY shared directory (typically www/shared)
cd www/shared
# ... edit files ...
git add .
git commit -m "Update shared layout"

# 2. Sync to all other shared directories
cd ../..  # Back to site root
rake shared:sync

# 3. (Optional) Push shared changes to remote when ready
cd www/shared
git push origin master

# 4. (Optional) Update submodule pointer in sites that need the changes
cd ../totalfinder-web
git add shared  # Update pointer to new shared commit
git commit -m "Update shared submodule"
git push origin web  # Deploy when ready
```

## Prerequisites

### Version Management (mise)

This project uses **[mise](https://mise.jdx.dev)** (a modern polyglot version manager) to manage Ruby and Node.js versions.

**Required versions** (specified in `.tool-versions`):
  * **Ruby 3.4.7**
  * **Node.js 22.21.1**

**Setup instructions:**

1. **Install mise**:
   ```bash
   brew install mise
   ```

2. **Activate mise in your shell** (fish example):
   ```bash
   echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

   Or if installed via Homebrew, it may be automatically activated.

3. **Install project tools**:
   ```bash
   cd site
   mise install  # Installs Ruby 3.4.7 and Node.js 22.21.1
   ```

4. **Install Ruby dependencies**:
   ```bash
   gem install bundler
   bundle install
   ```

**Why mise?**
- Manages Ruby, Node.js, and 500+ other tools with one interface
- Fast (written in Rust)
- Simple directory-based auto-switching
- Excellent IDE integration (RubyMine, WebStorm, VS Code)

### Other Requirements

  * **[nginx](http://nginx.org)** - Proxy server for local development routing
  * **npm** - Node.js package manager (ships with Node.js, no separate installation needed)
    * **Alternative**: Optionally use **yarn** or **bun** by setting `NODE_PKG_MANAGER` environment variable

**Technology Stack:**
  * **Jekyll** - Static site generator
  * **Stylus** - CSS preprocessing
  * **Lightning CSS** - CSS minification
  * **Terser** - JavaScript minification
  * **browser-sync** - Live reloading during development
  * **Playwright** - Automated browser testing

## Bootstrap Local Development

```bash
git clone git@github.com:binaryage/site.git
cd site
rake init
```

The `init` task does [several things](https://github.com/binaryage/site/blob/master/rakefile):
  * Initializes and updates all git submodules
  * Pins all submodules to latest branch tips (web branch for sites, master for shared)
  * Installs Ruby gems (`bundle install`)
  * Installs Node.js dependencies (npm/yarn/bun based on `NODE_PKG_MANAGER`)

## Development Workflow

### Launch Development Server

Make sure `/etc/hosts` is properly configured (see `rake hosts` for required entries).

**To run the full development server:**

In terminal 1, run the nginx proxy:
```bash
rake proxy
```

In terminal 2, run the Jekyll development server:
```bash
rake serve what=www,totalspaces,blog    # Serve specific sites
rake serve what=all                      # Serve all sites
```

The development server includes:
- Live reloading (via [browser-sync](https://browsersync.io))
- Automatic CSS/JavaScript rebuilding
- Hot module replacement

Sites are accessible at:
- `http://www.binaryage.org`
- `http://blog.binaryage.org`
- `http://totalfinder.binaryage.org`
- etc.

### Building Sites

```bash
rake build                   # Build all sites for production
rake build what=www,blog     # Build specific sites
```

Production builds include:
- CSS minification (Lightning CSS)
- JavaScript minification (Terser)
- Asset compression
- Cache busting

### Testing Production Builds Locally

```bash
# Build sites first
rake build what=www,blog

# Serve the built static files (no live reload)
rake serve:build             # Default port 8080
rake serve:build PORT=9000   # Custom port
```

Access at `http://localhost:8080` (or custom port). This tests production builds with compression and cache busting enabled.

## Testing

### Automated Smoke Testing

Run automated browser tests to verify all sites load correctly:

```bash
# Build sites first
rake build what=all

# Terminal 1: Start the build server
rake serve:build

# Terminal 2: Run smoke tests
rake test:smoke              # Uses port 8080 by default
PORT=9000 rake test:smoke    # Custom port
```

**What it tests:**
- HTTP status codes (accepts 2xx-3xx, fails on 4xx-5xx)
- JavaScript console errors
- Page loads without timeouts
- Redirect handling (e.g., support → discuss.binaryage.com)

Uses **Playwright** for headless browser testing with Chromium.

### Build Verification (Snapshot/Diff System)

Verify that code changes don't unexpectedly alter build output:

```bash
# 1. Create baseline snapshot before making changes
rake snapshot:create name=baseline desc="Before refactoring"

# 2. Make your code changes

# 3. Rebuild all sites
rake build

# 4. Compare current build with snapshot
rake snapshot:diff name=baseline           # Summary view
rake snapshot:diff name=baseline verbose=1 # Detailed file-level changes
```

**Snapshot management:**
```bash
rake snapshot:list           # List all snapshots
```

Snapshots are stored in `.snapshots/<name>/` with metadata (timestamp, git commit, description).

## Git Submodule Management

### Understanding Two Levels of Submodules

**Level 1 - Root-level submodules** (www, blog, totalfinder-web, etc. in main `site` repo):
- **DO NOT manually commit** pointer updates in the `site` repository
- The `hookgun` post-receive hook automatically updates these pointers when you push to a submodule's `web` branch
- Ignore "modified: www (new commits)" messages in the root repo's git status

**Level 2 - Shared submodule** (the `shared/` directory inside each website):
- **DO manually commit** pointer updates in each website repository
- Each website tracks which version of shared it uses
- After updating shared resources: `git add shared && git commit -m "Update shared submodule"`

### Common Submodule Commands

```bash
rake status                  # Check status of all submodules (shows issues only)
rake status verbose=1        # Check status with full details for all submodules
rake pin                     # Pin all submodules to latest branch tips
rake reset                   # DESTRUCTIVE: Reset workspace to remote state (destroys local changes)
```

**Status command indicators:**
- ✓ (green) - Clean, no issues
- ● (yellow) - Has issues (uncommitted changes, wrong branch, etc.)
- ✗ (red) - Missing or critical error
- ↑N (green) - N commits ahead of remote
- ↓N (red) - N commits behind remote

The status command checks:
- Current branch (should be `web` for sites, `master` for shared)
- Working directory cleanliness
- Ahead/behind status relative to remote
- Shared submodule commit hashes and status

### Syncing Shared Across All Sites

After making changes to the shared repository, propagate the commit to all sites:

```bash
rake shared:sync          # Sync from www/shared (default)
rake shared:sync from=blog  # Sync from specific site's shared directory
```

This updates all 11 other shared directories to the same commit (fast, ~1 second, no network required).

## Deployment

### Standard Deployment Flow

1. Make changes in a subsite repository
2. Commit and push changes to the `web` branch
3. The `hookgun` post-receive hook automatically:
   - Builds the site
   - Pushes static files to the `gh-pages` branch
   - Updates the root-level submodule pointer in the `site` repo
4. GitHub Pages deploys automatically

### Publishing Commands

```bash
rake publish                 # Publish all dirty sites
rake publish force=1         # Force publish all sites
rake publish dont_push=1     # Build but don't push
```

### Important: Shared Resources First

When you modify shared resources, **always push shared changes first** before pushing website changes:

```bash
# 1. Push shared changes
cd www/shared
git push origin master

# 2. Then push website changes
cd ..
git push origin web
```

This ensures the shared repository is available before websites reference the new commit.

## Dependency Management

```bash
rake upgrade                 # Upgrade both Ruby and Node.js dependencies
rake upgrade:ruby            # Upgrade Ruby dependencies only (bundler)
rake upgrade:node            # Upgrade Node.js dependencies only (npm/yarn/bun)
```

## Other Utilities

```bash
rake clean                   # Clean staging directories (.stage/)
rake inspect                 # List all registered sites with details
rake store                   # Generate FastSpring store template zip
rake hosts                   # Show required /etc/hosts entries
```

## Architecture Details

### Site Structure

Each site is defined in `_lib/tasks.rake` with:
- Directory path
- Port number (base 4101 + index)
- Name
- Subdomain (extracted by stripping `-web` suffix)
- Domain

Example: `totalfinder-web` → subdomain `totalfinder`, accessible at `totalfinder.binaryage.org`

### Build System

The build system (`_lib/build.rb`) uses Jekyll with custom plugins:
- **Jekyll plugins** (in `_plugins/`):
  - `stylus_converter.rb` - Stylus CSS preprocessing
  - `js_combinator.rb` - JavaScript concatenation from .list files
  - `compressor.rb` - Asset compression (Lightning CSS for CSS, Terser for JavaScript)
  - `pruner.rb`, `reshaper.rb`, `inline_styles.rb`, etc.

**Configuration:**
- Dynamically generated per-site
- Dev mode: `binaryage.org` domain, no compression, debug enabled
- Production mode: `binaryage.com` domain, compression enabled, cache busting

**Build artifacts:**
- Stored in `.stage/` directory (gitignored)
- Organized by site and build type

### Task Organization

Rake tasks are modular, organized in `_lib/tasks/`:
- `config.rb` - Site and task configuration
- `init.rb` - Initial setup tasks
- `workspace.rb` - Git submodule management
- `server.rb` - Development server tasks
- `build.rb` - Build system tasks
- `publish.rb` - Publishing and deployment tasks
- `upgrade.rb` - Dependency upgrade tasks
- `shared.rb` - Shared submodule sync tasks
- `snapshot.rb` - Build snapshot/diff tasks
- `test.rb` - Testing tasks

## Local Development Domains

- **Development**: Uses `binaryage.org` (configured in `/etc/hosts`)
- **Production**: Uses `binaryage.com`
- **Nginx proxy**: Runs on port 80
- **Individual Jekyll servers**: Run on ports 4101+ (one per site)

## Troubleshooting

### mise Issues

**Problem**: mise not activating Ruby/Node or showing wrong versions

**Solution**:
```bash
mise --version              # Check mise is installed
mise list                   # Check tools are installed
mise install                # Install missing tools
mise current                # Check active versions
ruby --version              # Should show 3.4.7
node --version              # Should show 22.21.1
```

**Problem**: Tools not auto-switching when cd'ing into project

**Solution**:
```bash
cat .tool-versions          # Verify file exists
mise install                # Ensure all tools installed
cd .. && cd site            # Re-enter directory
mise current                # Check active versions
```

### Ruby Issues

**Problem**: `bundle install` fails with permission errors

**Solution**: mise installs gems in user space. Never use `sudo`.
```bash
gem install bundler
bundle install
```

**Problem**: Jekyll fails with "cannot load such file -- csv (LoadError)" or similar errors

**Solution**: Ruby 3.0+ extracted several standard library gems from core. The Gemfile includes necessary stdlib gems (base64, bigdecimal, csv, logger, stringio). If you encounter similar errors for other gems, they may need to be added to the Gemfile.

### CSS Minification Issues

**Problem**: Build shows warning "Lightning CSS binary not found" or CSS is not minified

**Solution**: The build system uses `lightningcss-cli` (npm package). Install it:
```bash
rake init                   # Installs all dependencies
# OR
cd _node && npm install     # Just install Node dependencies
```

**Verification**:
```bash
ls -la _node/node_modules/.bin/lightningcss
# Should show a symlink to ../lightningcss-cli/lightningcss
```

### Submodule Issues

**Problem**: Submodules are in detached HEAD state

**Solution**:
```bash
rake pin                    # Pin all submodules to latest branch tips
```

**Problem**: "modified: www (new commits)" shown in root repo git status

**Solution**: This is normal for root-level submodules. The hookgun deployment system manages these pointers automatically. **Do not commit** these changes in the root `site` repository.

### Server Issues

**Problem**: nginx proxy fails to start

**Solution**: nginx requires sudo for port 80:
```bash
sudo rake proxy
```

Make sure `/etc/hosts` is configured:
```bash
rake hosts                  # Show required entries
```

**Problem**: Port already in use

**Solution**: Check for running processes:
```bash
lsof -i :80                 # Check port 80 (nginx)
lsof -i :4101               # Check Jekyll ports
```

## Additional Documentation

For more detailed documentation on:
- IDE setup (RubyMine, WebStorm)
- Advanced workflows
- Detailed architecture
- AI agent guidelines

See [CLAUDE.md](CLAUDE.md) in the repository root.
