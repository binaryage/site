# frozen_string_literal: true

require_relative 'colored2'
require_relative 'utils.rb'
require_relative 'site.rb'
require_relative 'workspace.rb'
require_relative 'build.rb'
require_relative 'store.rb'

## CONFIG ###################################################################################################################

BASE_PORT = 4101
BUILD_BASE_PORT = 8000 # base port for serving built static sites
MAIN_PORT = 80 # we will need admin rights to bind to this port when running `rake proxy`
LOCAL_DOMAIN = 'binaryage.org' # this domain is for testing to be set in /etc/hosts, see `rake hosts`

MIN_YARN_VERSION = '0.24.4'
MIN_GEM_VERSION = '1.8.23'

ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
NODE_DIR = File.join(ROOT, '_node')
STAGE_DIR = File.join(ROOT, '.stage')
SERVE_DIR = File.join(STAGE_DIR, 'serve')
BUILD_DIR = File.join(STAGE_DIR, 'build')
STORE_DIR = File.join(STAGE_DIR, 'store')

## SITES ####################################################################################################################

# Dynamically detect all git submodules at root level
DIRS = `git config --file .gitmodules --get-regexp path`
         .lines
         .map { |line| line.split[1] }
         .compact
         .freeze

SITES = DIRS.each_with_index.collect do |dir, index|
  Site.new(File.join(ROOT, dir), BASE_PORT + index, LOCAL_DOMAIN)
end

## TASKS ####################################################################################################################

namespace :init do
  desc 'install yarn dependencies'
  task :yarn do
    unless Gem::Version.new(`yarn --version`) >= Gem::Version.new(MIN_YARN_VERSION)
      die "install yarn (>=v#{MIN_YARN_VERSION}) => https://yarnpkg.com"
    end
    Dir.chdir NODE_DIR do
      sys('rm -rf node_modules')
      sys('yarn install')
    end
  end

  desc 'install gem dependencies'
  task :gem do
    unless Gem::Version.new(`gem --version`) >= Gem::Version.new(MIN_GEM_VERSION)
      error_msg = "install rubygems (>=v#{MIN_GEM_VERSION}, no sudo, consider rvm) "\
                  '=> http://rubygems.org, http://beginrescueend.com'
      die error_msg
    end
    sys('bundle install')
  end

  desc 'verify lightningcss-cli installation'
  task :lightningcss do
    lightningcss_bin = File.join(NODE_DIR, 'node_modules/.bin/lightningcss')

    unless File.exist?(lightningcss_bin)
      die "lightningcss-cli not found. Run 'rake init:yarn' first."
    end

    puts "✓ lightningcss-cli found at #{lightningcss_bin}".green
  end

  desc 'init submodules'
  task :repo do
    init_workspace(SITES)
  end
end

desc 'init workspace - needs special care'
task init: ['init:gem', 'init:yarn', 'init:lightningcss', 'init:repo']

desc 'clean stage'
task :clean do
  sys("rm -rf \"#{SERVE_DIR}\"")
  sys("rm -rf \"#{STAGE_DIR}\"")
end

desc 'reset workspace to match remote changes - this will destroy your local changes!!!'
task reset: [:clean] do
  reset_workspace(SITES)
end

desc 'pin submodules to point to latest branch tips'
task :pin do
  puts "note: #{'to get remote changes'.green} you have to do #{'git fetch'.blue} first"
  pin_workspace(SITES)
end

desc 'prints info how to setup /etc/hosts'
task :hosts do
  puts prepare_hosts_template(SITES)
end

namespace :proxy do
  desc 'generate proxy config (for nginx)'
  task :config do
    puts prepare_proxy_config(SITES, mode: :serve, proxy_port: MAIN_PORT)
  end
end

desc 'start proxy server'
task :proxy do
  trap('INT') do
    exit 10
  end
  config_path = File.join(STAGE_DIR, '.proxy.config')
  FileUtils.mkdir_p(STAGE_DIR) unless File.exist? STAGE_DIR
  File.write(config_path, prepare_proxy_config(SITES, mode: :serve, proxy_port: MAIN_PORT))
  sys("sudo nginx -c \"#{config_path}\"")
end

desc 'run dev server'
task :serve do
  all_names = sites_subdomains(SITES).join(',')
  what = ENV['what']
  if what.to_s.strip.empty?
    error_msg = 'specify coma separated list of sites to serve, or `rake serve what=all`, '\
                "full list:\n`rake serve what=#{all_names}`"
    die error_msg
  end

  what = all_names if what == 'all'
  names = clean_names(what.split(','))

  puts "note: #{'make sure you have'.green} #{'/etc/hosts'.yellow} #{'properly configured, see'.green} #{'rake hosts'.blue}"
  serve_sites(SITES, SERVE_DIR, names)
end

namespace :serve do
  desc 'serve pre-built sites from .stage/build/ via nginx proxy (for testing production builds locally)'
  task :build do
    # Check if build directory exists
    unless File.directory?(BUILD_DIR)
      die "Build directory #{BUILD_DIR} does not exist. Run 'rake build' first."
    end

    # Auto-detect built sites
    built_sites = Dir.glob(File.join(BUILD_DIR, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }

    if built_sites.empty?
      die "No built sites found in #{BUILD_DIR}. Run 'rake build what=www,blog' first."
    end

    puts "Found built sites: #{built_sites.join(', ').yellow}"

    # Get proxy port from environment (default: 8080, no sudo needed)
    proxy_port = (ENV['PORT'] || 8080).to_i
    use_sudo = proxy_port < 1024

    # Create Site objects for built sites
    build_sites = create_build_sites(SITES, BUILD_BASE_PORT, LOCAL_DOMAIN)

    # Filter to only include actually built sites
    build_sites = build_sites.select { |site| built_sites.include?(site.subdomain) }

    if build_sites.empty?
      die "No matching sites found. Built sites: #{built_sites.join(', ')}"
    end

    puts "\n#{'Starting servers for:'.green}"
    build_sites.each do |site|
      puts "  • #{site.subdomain.yellow} on port #{site.port.to_s.blue}"
    end
    puts "\n#{'Proxy will be available at:'.green} #{"http://localhost:#{proxy_port}".blue}"
    puts "#{'Access sites at:'.green}"
    build_sites.each do |site|
      puts "  • #{"http://#{site.subdomain}.#{LOCAL_DOMAIN}:#{proxy_port}".blue}"
    end
    puts

    # Start Python HTTP servers for each built site
    pids = start_python_servers(build_sites, BUILD_DIR)

    # Generate nginx config
    config_path = File.join(STAGE_DIR, '.proxy-build.config')
    FileUtils.mkdir_p(STAGE_DIR) unless File.exist?(STAGE_DIR)
    File.write(config_path, prepare_proxy_config(build_sites, mode: :build, proxy_port: proxy_port))

    # Trap INT signal to cleanup
    trap('INT') do
      puts "\n\n#{'Stopping servers...'.yellow}"
      stop_python_servers(pids)
      puts "#{'All servers stopped.'.green}"
      exit 0
    end

    # Start nginx
    nginx_cmd = use_sudo ? "sudo nginx -c \"#{config_path}\"" : "nginx -c \"#{config_path}\""
    puts "#{'Starting nginx...'.green} (#{use_sudo ? 'with sudo' : 'without sudo'})"

    begin
      sys(nginx_cmd)
    rescue StandardError => e
      puts "#{'Failed to start nginx:'.red} #{e.message}"
      stop_python_servers(pids)
      exit 1
    end

    puts "\n#{'Press Ctrl+C to stop all servers'.yellow}"

    # Keep the script running
    sleep
  end
end

desc 'build site'
task :build do
  what = (ENV['what'] || sites_subdomains(SITES).join(','))
  names = clean_names(what.split(','))

  # TODO: we could bring in more stuff from env
  build_opts = {
    stage: ENV['stage'] || BUILD_DIR,
    dev_mode: false,
    clean_stage: true,
    busters: true
  }

  build_sites(SITES, build_opts, names)
end

desc 'generate store template zip' # see https://springboard.fastspring.com/site/configuration/template/doc/templateOverview.xml
task :store do
  opts = {
    stage: STORE_DIR,
    dont_prune: true,
    zip_path: File.join(ROOT, 'store-template.zip')
  }
  build_store(SITES.first, opts)
end

desc 'inspect the list of sites currently registered'
task :inspect do
  puts SITES
end

desc 'publish all dirty sites, use force=1 to force publishing of all'
task :publish do
  opts = {
    force: ENV['force'] == '1',
    dont_push: ENV['dont_push'] == '1'
  }
  publish_workspace(SITES, opts)
end

namespace :upgrade do
  desc 'upgrade Ruby dependencies'
  task :ruby do
    sys('bundle update')
  end

  desc 'upgrade Node dependencies'
  task :node do
    Dir.chdir NODE_DIR do
      sys('yarn upgrade')
    end
  end
end

desc 'upgrade dependencies (via Ruby\'s bundler and Node\'s yarn)'
task upgrade: ['upgrade:ruby', 'upgrade:node']

## SHARED SUBMODULE SYNC ####################################################################################################

namespace :shared do
  desc 'Manually sync shared submodules (from=www to sync from specific site)'
  task :sync do
    source_name = ENV['from'] || 'www'

    # Find source site
    source_site = SITES.find { |s| s.name == source_name }
    unless source_site
      die "Source site '#{source_name}' not found"
    end

    source_dir = File.join(source_site.dir, 'shared')
    unless Dir.exist?(source_dir)
      die "Source shared directory not found: #{source_dir}"
    end

    # Get source commit
    source_commit = Dir.chdir(source_dir) do
      `git rev-parse HEAD 2>/dev/null`.strip
    end

    if source_commit.empty?
      die "Could not get commit from #{source_name}/shared"
    end

    source_commit_short = source_commit[0..6]
    source_path = File.expand_path(source_dir)

    puts "Syncing from #{"#{source_name}/shared".yellow} (#{source_commit_short.blue})"
    puts

    synced = 0
    skipped = 0
    failed = 0

    SITES.each do |site|
      next if site.name == source_name

      target_dir = File.join(site.dir, 'shared')
      next unless Dir.exist?(target_dir)

      # Check if it's a git repository
      is_git = Dir.chdir(target_dir) do
        system('git rev-parse --git-dir >/dev/null 2>&1')
      end
      next unless is_git

      # Check for uncommitted changes
      has_changes = Dir.chdir(target_dir) do
        !system('git diff --quiet 2>/dev/null') || !system('git diff --cached --quiet 2>/dev/null')
      end

      if has_changes
        puts "  #{'⚠️ '.yellow} #{site.name.yellow}/shared - has uncommitted changes, skipping"
        skipped += 1
        next
      end

      # Perform sync
      success = Dir.chdir(target_dir) do
        # Fetch from source
        system("git fetch '#{source_path}' HEAD >/dev/null 2>&1") &&
        # Update HEAD ref
        system("git update-ref HEAD #{source_commit}") &&
        # Reset working tree
        system("git reset --hard HEAD >/dev/null 2>&1")
      end

      if success
        # Verify
        actual_commit = Dir.chdir(target_dir) do
          `git rev-parse --short HEAD`.strip
        end
        puts "  #{'✅'.green} #{site.name.yellow}/shared → #{actual_commit.blue}"
        synced += 1
      else
        puts "  #{'❌'.red} #{site.name.yellow}/shared - sync failed"
        failed += 1
      end
    end

    puts
    if synced > 0
      puts "#{'✨'.green} Synced #{synced} site(s)"
    end
    if skipped > 0
      puts "#{'⏭️ '.yellow} Skipped #{skipped} site(s) with uncommitted changes"
    end
    if failed > 0
      puts "#{'⚠️ '.red} Failed to sync #{failed} site(s)"
      exit 1
    end
  end
end

## STATUS CHECK ############################################################################################################

# Helper method to check shared submodule status
def check_shared_submodule(shared_path, verbose)
  issues = 0

  unless File.exist?(File.join(shared_path, '.git'))
    puts "  #{'✗'.red}  shared/ #{'Not initialized as git submodule'.red}"
    return 1
  end

  Dir.chdir(shared_path) do
    # Get current branch
    branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
    branch = 'DETACHED' if branch.empty?

    # Get current commit hash (short)
    commit = `git rev-parse --short HEAD 2>/dev/null`.strip
    commit = 'UNKNOWN' if commit.empty?

    # Check if on expected branch (should be 'master' for shared)
    has_shared_issues = false
    if branch != 'master'
      has_shared_issues = true
      issues += 1
    end

    # Check working directory status
    status_output = `git status --porcelain 2>/dev/null`.strip
    is_dirty = !status_output.empty?
    if is_dirty
      has_shared_issues = true
      issues += 1
    end

    # Check ahead/behind status
    ahead_behind_parts = []
    if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
      ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
      behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

      if ahead > 0
        ahead_behind_parts << "↑#{ahead}".green + ' '
        has_shared_issues = true
      end
      if behind > 0
        ahead_behind_parts << "↓#{behind}".red + ' '
        has_shared_issues = true
      end
    end

    # Print shared status
    shared_icon = has_shared_issues ? '●'.yellow : '✓'.green
    branch_display = branch != 'master' ? branch.yellow : branch

    puts "  #{shared_icon} shared/ [#{branch_display} @ #{commit}]"

    if verbose || has_shared_issues
      puts "     #{'⚠'.yellow}  Working directory has uncommitted changes" if is_dirty
    end

    # Always show ahead/behind if present (even in non-verbose mode)
    unless ahead_behind_parts.empty?
      puts "     #{'↔'.blue}  Remote: #{ahead_behind_parts.join('')}"
    end
  end

  issues
end

desc 'check status of all git submodules and their shared submodules (verbose=1 for details)'
task :status do
  verbose = ENV['verbose'] == '1'

  # Counters for summary
  total_submodules = SITES.length
  clean_count = 0
  dirty_count = 0
  ahead_count = 0
  behind_count = 0
  wrong_branch_count = 0
  shared_issues = 0

  puts "#{'=== Git Submodules Status ==='.cyan.bold}\n\n"

  # Check each submodule
  SITES.each do |site|
    has_issues = false

    # Check if submodule directory exists
    unless File.directory?(site.dir)
      puts "#{'✗'.red} #{site.name.bold} - #{'MISSING'.red}"
      dirty_count += 1
      next
    end

    Dir.chdir(site.dir) do
      # Get current branch
      branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      branch = 'DETACHED' if branch.empty?

      # Check if on expected branch (should be 'web' for main submodules)
      branch_display = if branch != 'web'
                         has_issues = true
                         wrong_branch_count += 1
                         "#{branch.yellow} #{'(expected: web)'.gray}"
                       else
                         branch.green
                       end

      # Check working directory status
      status_output = `git status --porcelain 2>/dev/null`.strip
      is_dirty = !status_output.empty?
      if is_dirty
        has_issues = true
        dirty_count += 1
      end

      # Check ahead/behind status
      ahead_behind_parts = []
      if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
        ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
        behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

        if ahead > 0
          ahead_behind_parts << "↑#{ahead}".green
          ahead_count += 1
        end
        if behind > 0
          ahead_behind_parts << "↓#{behind}".red
          has_issues = true
          behind_count += 1
        end
      end

      # Print main status line
      status_icon = has_issues ? '●'.yellow : '✓'.green
      clean_count += 1 unless has_issues

      puts "#{status_icon} #{site.name.bold} [#{branch_display}]"

      # Show details if verbose or if there are issues
      if verbose || has_issues
        puts "  #{'⚠'.yellow}  Working directory has uncommitted changes" if is_dirty
      end

      # Always show ahead/behind if present (even in non-verbose mode)
      unless ahead_behind_parts.empty?
        puts "  #{'↔'.blue}  Remote: #{ahead_behind_parts.join('')}"
      end

      # Check shared submodule
      shared_dir = File.join(site.dir, 'shared')
      if Dir.exist?(shared_dir)
        shared_issues += check_shared_submodule(shared_dir, verbose)
      else
        puts "  #{'✗'.red}  #{'shared/ directory missing'.red}"
        shared_issues += 1
      end

      puts
    end
  end

  # Print summary
  puts "#{'=== Summary ==='.cyan.bold}"
  puts "Total submodules:     #{total_submodules.to_s.bold}"
  puts "Clean:                #{clean_count.to_s.green}"
  puts "With local changes:   #{dirty_count.to_s.yellow}"
  puts "Ahead of remote:      #{ahead_count.to_s.green}"
  puts "Behind remote:        #{behind_count.to_s.red}"
  puts "Wrong branch:         #{wrong_branch_count.to_s.yellow}" if wrong_branch_count > 0
  puts "Shared/ issues:       #{shared_issues.to_s.yellow}" if shared_issues > 0

  # Exit code based on issues
  exit 1 if behind_count > 0 || shared_issues > 0
end

task default: :serve
