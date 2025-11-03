# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BinaryAge Site is an umbrella project that manages multiple subdomain sites under *.binaryage.com as git submodules. Each subdomain (www, blog, totalfinder-web, totalspaces-web, etc.) is a separate git repository tracked as a submodule. All submodains share common resources through the `shared` submodule (layouts, includes, CSS, JavaScript).

### Git Submodules Architecture

The repository contains 17 subdomain sites as git submodules:
- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site
- **Product sites**: totalfinder-web, totalspaces-web, asepsis-web, totalterminal-web, visor, hodlwallet
- **Tool sites**: firequery, firerainbow, firelogger, xrefresh, drydrop, hints, restatic-web, test-web

Each submodule has a `shared` subdirectory (also a git submodule) containing common layouts, includes, CSS (Stylus), and JavaScript (CoffeeScript) resources.

## Prerequisites

### Ruby Environment (rbenv + direnv)

This project uses **rbenv** (a simple Ruby version manager) with **direnv** for automatic environment management.

**Ruby Version**: 3.4.7 (specified in `.ruby-version`)

**Setup Instructions:**

1. **Install rbenv and ruby-build**:
   ```bash
   brew install rbenv ruby-build
   ```

2. **Install direnv**:
   ```bash
   brew install direnv
   ```

3. **Configure direnv for fish shell**:
   ```bash
   # Add to ~/.config/fish/config.fish
   echo 'direnv hook fish | source' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

4. **Initialize rbenv in your shell**:
   ```bash
   # For fish shell, add to ~/.config/fish/config.fish
   echo 'rbenv init - fish | source' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

5. **Allow direnv in this project**:
   ```bash
   cd /path/to/site
   direnv allow
   ```

6. **Install Ruby 3.4.7**:
   ```bash
   rbenv install 3.4.7
   ```
   This happens automatically when you `cd` into the project if direnv is configured.

7. **Install bundler and gems**:
   ```bash
   gem install bundler
   bundle install
   ```

**Why rbenv?**
- Simple and lightweight
- Excellent IDE integration (RubyMine, VS Code, etc.)
- Works seamlessly with direnv
- Does not override shell commands or use shims in an intrusive way
- Well-maintained and widely adopted in the Ruby community

### Node.js Environment
- **Node.js**: Required for browser-sync and asset processing
- **Yarn**: Minimum version **0.24.4**
  - Install: https://yarnpkg.com

### Other Requirements
- **nginx**: Required for proxy server (`rake proxy`)

## Common Development Commands

### Initial Setup
```bash
rake init                    # First-time setup: installs gems, yarn deps, and inits/updates all git submodules
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

The development server uses browser-sync for live reloading and CSS watching.

### Building Sites
```bash
rake build                   # Build all sites for production
rake build what=www,blog     # Build specific sites
```

### Git Submodule Management
```bash
rake pin                     # Pin all submodules to latest branch tips
rake reset                   # DESTRUCTIVE: Reset workspace to remote state (destroys local changes)
```

### Publishing
```bash
rake publish                 # Publish all dirty sites
rake publish force=1         # Force publish all sites
rake publish dont_push=1     # Build but don't push
```

### Dependency Management
```bash
rake upgrade                 # Upgrade both Ruby (bundler) and Node (yarn) dependencies
rake upgrade:ruby            # Upgrade Ruby dependencies only
rake upgrade:node            # Upgrade Node dependencies only
```

### Other Utilities
```bash
rake clean                   # Clean staging directories
rake inspect                 # List all registered sites
rake store                   # Generate FastSpring store template zip
```

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
  - `cdnizer.rb` - CDN integration
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
- Production mode: Uses binaryage.com, compression enabled, cache busting, CDN integration

### Deployment Flow
1. Make changes in a subsite repository
2. Push changes to the `web` branch
3. Post-receive hook (`hookgun`) builds the site
4. Static files pushed to `gh-pages` branch
5. GitHub Pages deploys automatically
6. Submodule pointer updated in this `site` repo

**Important**: Always push the `shared` submodule changes first if you modified shared resources.

## Configuration Files

- `rakefile` - Main entry point, imports `_lib/tasks.rake`
- `_lib/tasks.rake` - All rake task definitions and site configuration
- `_lib/build.rb` - Jekyll build logic and configuration generation
- `_lib/workspace.rb` - Git submodule management functions
- `_lib/site.rb` - Site class definition
- `_lib/utils.rb` - Utility functions
- `_lib/store.rb` - FastSpring store template generation
- `Gemfile` - Ruby dependencies (Jekyll, Stylus, CoffeeScript, compression tools)
- `_node/package.json` - Node dependencies (browser-sync)

## Working with Submodules

When making changes:
1. Navigate into the submodule directory (e.g., `cd totalfinder-web`)
2. Work on the `web` branch
3. Commit and push changes
4. If shared resources changed, commit and push `shared` first
5. Return to parent repo and commit the submodule pointer update if needed

Use `git submodule foreach` for batch operations across all submodules.

## Local Development Domains

- Development uses `binaryage.org` (configured in `/etc/hosts`)
- Production uses `binaryage.com`
- Nginx proxy runs on port 80, individual Jekyll servers on ports 4101+
- Each site is accessible at `http://{subdomain}.binaryage.org`

## Troubleshooting

### rbenv + direnv issues

**Problem**: direnv not activating Ruby or showing wrong version

**Solution**:
1. Check rbenv is installed: `rbenv --version`
2. Check Ruby is installed: `rbenv versions`
3. Install Ruby if needed: `rbenv install 3.4.7`
4. Check direnv is working: `direnv status`
5. Re-allow direnv: `direnv allow`
6. Verify: `ruby --version` (should show 3.4.7)

**Problem**: rbenv init not working

**Solution**: Make sure rbenv is initialized in your shell config:
```bash
# For fish shell
echo 'rbenv init - fish | source' >> ~/.config/fish/config.fish
```

### General Ruby issues

**Problem**: `bundle install` fails with permission errors

**Solution**: rbenv installs gems in user space. Never use `sudo`. If you still have issues:
```bash
gem install bundler
bundle install
```

**Problem**: Wrong Ruby version active

**Solution**:
1. Check `.ruby-version` file exists and contains `3.4.7`
2. Check direnv is allowed: `direnv status`
3. Re-enter directory: `cd .`
4. Check Ruby version: `ruby --version`

**Problem**: Jekyll fails with "cannot load such file -- csv (LoadError)" or similar errors

**Solution**: Ruby 3.0+ extracted several standard library gems from core. The Gemfile already includes the necessary stdlib gems (base64, bigdecimal, csv, logger). If you encounter similar errors for other gems, they may need to be added to the Gemfile.

Common Ruby 3.x stdlib gems that may be needed:
- `csv` - CSV file handling
- `base64` - Base64 encoding/decoding
- `bigdecimal` - Arbitrary precision decimal arithmetic
- `logger` - Logging functionality
- `mutex_m` - Mixin to extend objects with synchronization
- `ostruct` - OpenStruct class

**Problem**: Build fails with "undefined method 'exists?' for class File" in html_press gem

**Solution**: Ruby 3.2+ removed `File.exists?` (use `File.exist?` instead). The html_press gem in bundler cache needs to be patched:

```bash
# Fix html_press uglifier.rb
sed -i '' 's/File\.exists?/File.exist?/g' ~/.rbenv/versions/3.4.7/lib/ruby/gems/3.4.0/bundler/gems/html_press-*/lib/html_press/uglifier.rb

# Fix html_press css_press.rb
sed -i '' 's/File\.exists?/File.exist?/g' ~/.rbenv/versions/3.4.7/lib/ruby/gems/3.4.0/bundler/gems/html_press-*/lib/html_press/css_press.rb
```

**Note**: This fix is temporary and will be lost if you reinstall Ruby. A permanent solution would be to fork the html_press repository and update the Gemfile reference.

## RubyMine IDE Setup

### Setting up Ruby SDK from rbenv

RubyMine has excellent support for rbenv. The IDE will automatically detect rbenv-installed Ruby versions.

**Ruby interpreter path**: `/Users/darwin/.rbenv/versions/3.4.7/bin/ruby`

**Method 1: Using RubyMine UI (Recommended)**

For RubyMine 2025.2+:

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Languages & Frameworks → Ruby Interpreters**
3. RubyMine should automatically detect rbenv Ruby versions
4. If not, click **+** → **Add Local Interpreter...**
5. Choose **rbenv** tab (if available) or **System Interpreter**
6. Select Ruby 3.4.7 from the list or browse to: `/Users/darwin/.rbenv/versions/3.4.7/bin/ruby`
7. Click **OK** to add the interpreter
8. Select `ruby-3.4.7` as the project interpreter
9. Click **Apply** and **OK**

For older RubyMine versions (pre-2025.2):

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Languages & Frameworks → Ruby SDK and Gems**
3. RubyMine should automatically detect rbenv versions
4. Select `rbenv: 3.4.7` from the list
5. Click **Apply** and **OK**

**Method 2: Manual configuration**

Edit `.idea/site.iml` and change the SDK line:
```xml
<orderEntry type="jdk" jdkName="rbenv: 3.4.7" jdkType="RUBY_SDK" />
```

Then restart RubyMine.

### Using direnv Plugin

RubyMine has a direnv plugin that can automatically load environment variables from `.envrc`:

1. Open **RubyMine → Settings/Preferences** (⌘,)
2. Navigate to **Plugins**
3. Search for **"direnv integration"**
4. Install the plugin
5. Restart RubyMine
6. The plugin will automatically detect `.envrc` and load environment variables

**Note**: With rbenv, the direnv plugin should work perfectly since rbenv is well-supported.

### Verifying Setup

After configuration, verify the setup:

1. Open the **Terminal** tool window in RubyMine (⌥F12)
2. Run: `ruby --version`
   - Should show: `ruby 3.4.7 (2025-10-08 revision 7a5688e2a2)`
3. Run: `which ruby`
   - Should show: `/Users/darwin/.rbenv/shims/ruby`
4. Run: `bundle exec jekyll --version`
   - Should work without errors

### Run Configurations

When creating Run/Debug configurations for Rake tasks:

1. Go to **Run → Edit Configurations**
2. For any Rake task configuration:
   - **Ruby SDK**: Select `rbenv: 3.4.7`
   - **Working directory**: `/Users/darwin/x/site`
   - RubyMine will automatically use the correct Ruby and gems

Common Rake tasks to configure:
- `rake build what=www`
- `rake serve what=www,totalfinder`
- `rake clean`
