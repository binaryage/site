# BinaryAge Site

Umbrella project that manages multiple subdomain sites under [*.binaryage.com](http://www.binaryage.com) as git submodules.

**For detailed technical documentation, AI agent guidelines, and advanced workflows, see [CLAUDE.md](CLAUDE.md)**

## Quick Start

### Prerequisites

- **[mise](https://mise.jdx.dev)** - Version manager for Ruby and Node.js
  - Ruby 3.4.7
  - Node.js 22.21.1
- **nginx** - Proxy server for local development
- **npm** - Node.js package manager (ships with Node.js)

### Setup

```bash
git clone git@github.com:binaryage/site.git
cd site
mise install      # Install Ruby & Node.js versions
rake init         # Initialize submodules, install dependencies
```

## Essential Commands

### Development Server

```bash
# Terminal 1: Start nginx proxy (requires sudo for port 80)
rake proxy

# Terminal 2: Start Jekyll development server with live reload
rake serve                   # Serve all sites (default)
rake serve what=www,blog     # Serve only specific sites
```

Make sure `/etc/hosts` is configured first: `rake hosts`

Access sites at:
- http://www.binaryage.org
- http://blog.binaryage.org
- http://totalfinder.binaryage.org
- etc.

### Build & Test

```bash
rake build                  # Build all sites for production
rake build what=www,blog     # Build specific sites

rake test:smoke             # Run automated smoke tests
```

### Common Tasks

```bash
rake status                 # Check git submodule status
rake shared:sync            # Sync shared resources across all sites
rake screenshot:create name=X  # Create screenshot baseline
rake screenshot:diff name=X    # Compare screenshots
```

## Architecture Overview

### 12 Subdomain Sites (Git Submodules)

- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site (redirects to discuss.binaryage.com)
- **Products**: totalfinder-web, totalspaces-web, totalterminal-web, asepsis-web, visor
- **Tools**: firequery, firerainbow, firelogger, xrefresh

Each site is a separate git repository tracked as a submodule.

### Shared Resources Architecture

⚠️ **CRITICAL CONCEPT**: All 12 `shared/` directories across all submodules point to the **SAME** git repository ([binaryage/shared](https://github.com/binaryage/shared)).

This means:
- **Single source of truth**: One repository contains all shared layouts, CSS, and JavaScript
- **Edit once**: Changes to shared resources only need to be made in ONE place
- **Sync across sites**: Use `rake shared:sync` to propagate commits to all sites

**Shared repository contains:**
- `layouts/` - Jekyll layout files
- `includes/` - Includes for layouts
- `css/` - Shared CSS (Stylus preprocessing)
- `js/` - Shared JavaScript (concatenated and minified)
- `img/` - Shared images

**Typical workflow:**

```bash
# 1. Make changes in any shared directory (typically www/shared)
cd www/shared
# ... edit files ...
git commit -m "Update layout"

# 2. Sync to all other sites
cd ../..
rake shared:sync

# 3. (Optional) Push shared changes when ready
cd www/shared
git push origin master
```

## Git Submodule Management

### Two Levels of Submodules

**Level 1 - Root-level submodules** (www, blog, totalfinder-web, etc.):
- ❌ **DO NOT manually commit** pointer updates in the main `site` repository
- The `hookgun` deployment hook automatically updates these
- Ignore "modified: www (new commits)" messages in git status

**Level 2 - Shared submodule** (`shared/` inside each website):
- ✅ **DO manually commit** pointer updates in each website repository
- Each website tracks which version of shared it uses
- After updating shared: `git add shared && git commit -m "Update shared"`

### Common Commands

```bash
rake status                  # Check all submodules (shows issues only)
rake status verbose=1        # Full details for all submodules
rake pin                     # Pin all submodules to latest branch tips
rake shared:sync            # Sync shared commits across all sites
```

## Deployment

Standard deployment flow:
1. Make changes in a subsite repository
2. Push to the `web` branch
3. The `hookgun` hook automatically builds and deploys to GitHub Pages
4. Root-level submodule pointer automatically updated

**Important**: When modifying shared resources, always push shared changes **before** pushing website changes.

## Basic Troubleshooting

### mise Issues

```bash
mise --version              # Verify mise is installed
mise install                # Install Ruby & Node.js
mise current                # Check active versions
ruby --version              # Should show 3.4.7
node --version              # Should show 22.21.1
```

### Bundle Install Fails

```bash
gem install bundler
bundle install
```

Never use `sudo` - mise installs gems in user space.

### nginx Proxy Fails

```bash
sudo rake proxy             # nginx requires sudo for port 80
rake hosts                  # Show required /etc/hosts entries
```

### Port Already in Use

```bash
lsof -i :80                 # Check nginx port
lsof -i :4101               # Check Jekyll ports
```

## Testing

### Smoke Tests
Automated browser tests verify all sites load correctly:

```bash
rake build
rake serve:build            # Start static server on port 8080
rake test:smoke             # Run tests
```

### Screenshot Testing
Visual regression testing with full-page screenshots:

```bash
rake screenshot:create name=baseline desc="Before changes"
# ... make changes ...
rake build
rake screenshot:diff name=baseline open=1
```

### Build Verification
Snapshot system verifies build output hasn't changed unexpectedly:

```bash
rake snapshot:create name=baseline desc="Before refactoring"
# ... make changes ...
rake build
rake snapshot:diff name=baseline
```

## Documentation

For comprehensive documentation including:
- AI agent guidelines
- All rake tasks with examples
- Configuration files reference
- IDE setup (RubyMine, WebStorm)
- Advanced workflows
- Detailed architecture
- Complete troubleshooting guide

**See [CLAUDE.md](CLAUDE.md)**

## Technology Stack

- **Jekyll** - Static site generator
- **Stylus** - CSS preprocessing
- **Lightning CSS** - CSS minification
- **Terser** - JavaScript minification
- **Playwright** - Browser automation & testing
- **ODiff** - Visual diff for screenshots
- **mise** - Version management
- **nginx** - Development proxy server

## License

Individual sites have their own licenses. Check each submodule repository.
