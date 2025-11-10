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

### Automated mise Activation (Recommended)

For the best developer experience, enable automatic mise activation so Ruby and Node.js are available without manual intervention:

**Option 1: Shell Integration (Recommended)**

Add mise activation to your shell profile:

```bash
# For Zsh (add to ~/.zshrc)
eval "$(mise activate zsh)"

# For Bash (add to ~/.bashrc or ~/.bash_profile)
eval "$(mise activate bash)"

# For Fish (add to ~/.config/fish/config.fish)
mise activate fish | source
```

After adding this, restart your shell or run `source ~/.zshrc` (or your shell's config file).

**Option 2: direnv Integration**

If you prefer direnv, mise can integrate with it:

```bash
# 1. Install direnv (if not already installed)
brew install direnv

# 2. Add direnv hook to your shell
# For Zsh (add to ~/.zshrc)
eval "$(direnv hook zsh)"

# For Bash (add to ~/.bashrc)
eval "$(direnv hook bash)"

# 3. Create .envrc in the project (already exists)
# mise will automatically work with direnv via .mise.toml

# 4. Allow direnv for this directory
direnv allow
```

**Verification:**

After setup, verify automatic activation works:

```bash
cd /path/to/site
ruby --version    # Should show 3.4.7 automatically
node --version    # Should show 22.21.1 automatically
```

Without activation, you'd need to manually run `mise exec -- command` for every command.

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
rake pin                    # Fix detached HEAD - checkout branch tips after git pull/submodule update
rake shared:sync            # Sync shared resources across all sites
rake remotes:list           # Show git remote URLs for all sites
rake remotes:ssh            # Convert all remotes to SSH format
rake screenshot:create name=X  # Create screenshot baseline
rake screenshot:diff name=X    # Compare screenshots
```

### Slash Commands

Use the `/commit-site` command for intelligent submodule commits:

```bash
/commit-site                # Interactive picker - auto-detects sites with changes
/commit-site www            # Commit changes in specific site
/commit-site www blog       # Commit multiple sites
/commit-site all            # Commit all sites with changes
```

This command intelligently handles both shared pointer updates and regular file changes, generating appropriate commit messages automatically. See [CLAUDE.md](CLAUDE.md#using-the-commit-site-slash-command) for details.

## Architecture Overview

### Subdomain Sites (Git Submodules)

- **www** - Main binaryage.com site
- **blog** - Blog subdomain
- **support** - Support site (redirects to discuss.binaryage.com)
- **Products**: totalfinder-web, totalspaces-web, totalterminal-web, asepsis-web, visor
- **Tools**: firequery, firerainbow, firelogger, xrefresh

Each site is a separate git repository tracked as a submodule.

### Shared Resources Architecture

⚠️ **CRITICAL CONCEPT**: All `shared/` directories across all submodules point to the **SAME** git repository ([binaryage/shared](https://github.com/binaryage/shared)).

This means:
- **Single source of truth**: One repository contains all shared layouts, CSS, and JavaScript
- **Edit once**: Changes to shared resources only need to be made in ONE place
- **Sync across sites**: Use `rake shared:sync` to propagate commits to all sites

**Shared repository contains:**
- `layouts/` - Jekyll layout files
- `includes/` - Includes for layouts
- `css/` - Shared CSS (plain CSS with modern features, bundled via Lightning CSS)
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
rake remotes:list           # Show remote URLs for all sites
rake remotes:ssh            # Convert all remotes to SSH format
rake hooks:install          # Install pre-push hooks (auto-installed during rake init)
rake hooks:status           # Check hook installation status
```

### Pre-Push Safety Hook

The repository includes a pre-push git hook that prevents accidentally pushing website changes with unpushed shared submodule commits. The hook:
- Automatically installed during `rake init`
- Only checks when pushing to `web` branch
- Auto-fetches to verify shared commits are on GitHub
- Shows clear error messages with guidance
- Can be bypassed with `git push --no-verify` if needed

See [CLAUDE.md](CLAUDE.md#git-hooks-for-shared-submodule-safety) for detailed documentation.

## Deployment

Standard deployment flow:
1. Make changes in a subsite repository
2. Push to the `web` branch
3. The `hookgun` hook automatically builds and deploys to GitHub Pages
4. Root-level submodule pointer automatically updated

`hookgun` is maintained outside this repository (BinaryAge's deployment infrastructure). If you need to audit or adjust it, coordinate with the infrastructure team—the scripts are not stored in `site/`.

**Important**: When modifying shared resources, always push shared changes **before** pushing website changes.

## Basic Troubleshooting

### mise Issues

**If commands fail with Ruby/Node version errors:**

First, verify mise is working:

```bash
mise --version              # Verify mise is installed
mise install                # Install Ruby & Node.js
mise current                # Check active versions
```

**Recommended**: Set up automated mise activation (see "Automated mise Activation" section above) to avoid needing `mise exec --` prefixes.

**Without activation**, you must explicitly use mise:

```bash
mise exec -- ruby --version              # Should show 3.4.7
mise exec -- node --version              # Should show 22.21.1
mise exec -- bundle exec rake build      # Correct way to run rake tasks
```

**With activation** (shell integration or direnv), commands work directly:

```bash
ruby --version              # Should show 3.4.7 automatically
node --version              # Should show 22.21.1 automatically
rake build                  # Just works
```

### Bundle Install Fails

```bash
gem install bundler
bundle install
```

Never use `sudo` - mise installs gems in user space.

> **Tip:** macOS ships Bundler 1.x by default. Run all Ruby commands through mise (e.g. `mise exec -- bundle exec rake -T`) so Bundler 2 from your managed toolchain is used and you avoid the "You must use Bundler 2" error.

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

### Manual Workspace Reset

⚠️ **WARNING: This is a DESTRUCTIVE operation that will permanently delete all local changes!**

In rare cases where you need to completely reset your workspace to match remote state (e.g., corrupted git state), use manual git commands instead of an automated task for safety:

**Reset a single site:**

```bash
cd www                           # Navigate to the site
git checkout -f web              # Force checkout web branch
git reset --hard origin/web      # Hard reset to remote state
git clean -f -f -d              # Remove untracked files
git pull origin web              # Pull latest changes

# Also reset the shared submodule if needed:
cd shared
git checkout -f master
git reset --hard origin/master
git clean -f -f -d
git pull origin master
```

**Reset all sites** (if you're absolutely sure):

```bash
# Reset all site submodules using git submodule foreach
git submodule foreach '
  echo "Resetting $(basename $PWD)..." &&
  git checkout -f web &&
  git reset --hard origin/web &&
  git clean -f -f -d &&
  git pull origin web &&
  if [ -d shared ]; then
    cd shared &&
    git checkout -f master &&
    git reset --hard origin/master &&
    git clean -f -f -d &&
    git pull origin master
  fi
'
```

**Less destructive alternatives:**

Before resorting to a full reset, consider these safer options:

- `rake pin` - Fix detached HEAD without losing changes
- `git reset --hard origin/web` - Reset just one site
- `git stash` - Save changes temporarily before resetting
- Manual `git checkout` - Discard changes to specific files only

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
- **Lightning CSS** - CSS bundling, nesting transformation, and minification
- **Terser** - JavaScript minification
- **Playwright** - Browser automation & testing
- **ODiff** - Visual diff for screenshots
- **mise** - Version management
- **nginx** - Development proxy server

## License

Individual sites have their own licenses. Check each submodule repository.
