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

6. **Install Yarn** (for Node.js dependencies):
   ```bash
   npm install -g yarn  # Minimum version 0.24.4
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

**Problem**: Build fails with "undefined method 'exists?' for class File" in html_press gem

**Solution**: Ruby 3.2+ removed `File.exists?` (use `File.exist?` instead). The html_press gem in bundler cache needs to be patched:

```bash
# Find mise Ruby gems directory
MISE_RUBY_GEMS=$(mise where ruby@3.4.7)/lib/ruby/gems/3.4.0

# Fix html_press uglifier.rb
sed -i '' 's/File\.exists?/File.exist?/g' "$MISE_RUBY_GEMS"/bundler/gems/html_press-*/lib/html_press/uglifier.rb

# Fix html_press css_press.rb
sed -i '' 's/File\.exists?/File.exist?/g' "$MISE_RUBY_GEMS"/bundler/gems/html_press-*/lib/html_press/css_press.rb
```

**Note**: This fix is temporary and will be lost if you reinstall Ruby. A permanent solution would be to fork the html_press repository and update the Gemfile reference.

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

WebStorm will now use the mise-installed Node.js for all JavaScript tooling (npm, yarn, etc.).
