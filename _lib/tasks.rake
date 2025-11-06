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

  desc 'init submodules'
  task :repo do
    init_workspace(SITES)
  end
end

desc 'init workspace - needs special care'
task init: ['init:gem', 'init:yarn', 'init:repo']

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
  HOOK_SOURCE = File.join(ROOT, '_scripts', 'shared-sync-hook.sh')
  SYNC_ENABLED_FLAG = File.join(ROOT, '.shared-autosync-enabled')

  desc 'Show status of shared submodule sync hooks'
  task :status do
    puts "Shared Submodule Sync Status"
    puts "=" * 80
    puts

    enabled = File.exist?(SYNC_ENABLED_FLAG)
    puts "Auto-sync: #{enabled ? 'enabled'.green : 'disabled'.red}"
    puts

    if !enabled
      puts "Run #{'rake shared:enable'.blue} to enable automatic synchronization"
      puts
    end

    # Check each shared directory for hook installation
    hook_count = 0
    SITES.each do |site|
      shared_dir = File.join(site.dir, 'shared')
      next unless Dir.exist?(shared_dir)

      # Get the git directory
      git_dir = Dir.chdir(shared_dir) do
        `git rev-parse --git-dir 2>/dev/null`.strip
      end

      next if git_dir.empty?

      hook_path = File.join(git_dir, 'hooks', 'post-commit')

      if File.exist?(hook_path)
        puts "  #{'✅'.green} #{site.name.yellow}/shared - hook installed"
        hook_count += 1
      else
        puts "  #{'❌'.red} #{site.name.yellow}/shared - no hook"
      end
    end

    puts
    puts "Hooks installed: #{hook_count}/#{SITES.size}"
  end

  desc 'Enable automatic shared submodule synchronization'
  task :enable do
    unless File.exist?(HOOK_SOURCE)
      die "Hook script not found: #{HOOK_SOURCE}"
    end

    puts "Installing shared sync hooks..."
    puts

    hook_content = File.read(HOOK_SOURCE)
    installed_count = 0

    SITES.each do |site|
      shared_dir = File.join(site.dir, 'shared')

      unless Dir.exist?(shared_dir)
        puts "  #{'⏭️ '.yellow} #{site.name.yellow}/shared - directory not found"
        next
      end

      # Get the git directory
      git_dir = Dir.chdir(shared_dir) do
        `git rev-parse --git-dir 2>/dev/null`.strip
      end

      if git_dir.empty?
        puts "  #{'⏭️ '.yellow} #{site.name.yellow}/shared - not a git repository"
        next
      end

      hooks_dir = File.join(git_dir, 'hooks')
      hook_path = File.join(hooks_dir, 'post-commit')

      # Create hooks directory if it doesn't exist
      FileUtils.mkdir_p(hooks_dir) unless Dir.exist?(hooks_dir)

      # Write the hook
      File.write(hook_path, hook_content)

      # Make it executable
      FileUtils.chmod(0755, hook_path)

      puts "  #{'✅'.green} #{site.name.yellow}/shared - hook installed"
      installed_count += 1
    end

    # Create the enabled flag
    FileUtils.touch(SYNC_ENABLED_FLAG)

    puts
    puts "#{'✨'.green} Installed hooks in #{installed_count} site(s)"
    puts
    puts "Now when you commit in #{'any'.yellow} shared directory, changes will"
    puts "automatically sync to all other shared directories."
    puts
    puts "To disable: #{'rake shared:disable'.blue}"
  end

  desc 'Disable automatic shared submodule synchronization'
  task :disable do
    puts "Removing shared sync hooks..."
    puts

    removed_count = 0

    SITES.each do |site|
      shared_dir = File.join(site.dir, 'shared')
      next unless Dir.exist?(shared_dir)

      git_dir = Dir.chdir(shared_dir) do
        `git rev-parse --git-dir 2>/dev/null`.strip
      end

      next if git_dir.empty?

      hook_path = File.join(git_dir, 'hooks', 'post-commit')

      if File.exist?(hook_path)
        FileUtils.rm(hook_path)
        puts "  #{'✅'.green} #{site.name.yellow}/shared - hook removed"
        removed_count += 1
      else
        puts "  #{'⏭️ '.yellow} #{site.name.yellow}/shared - no hook found"
      end
    end

    # Remove the enabled flag
    FileUtils.rm(SYNC_ENABLED_FLAG) if File.exist?(SYNC_ENABLED_FLAG)

    puts
    puts "#{'✨'.green} Removed hooks from #{removed_count} site(s)"
  end

  desc 'Remove old www-shared remote configuration from shared submodules'
  task :cleanup_remotes do
    puts "Removing www-shared remotes..."
    puts

    removed_count = 0

    SITES.each do |site|
      shared_dir = File.join(site.dir, 'shared')
      next unless Dir.exist?(shared_dir)

      # Check if www-shared remote exists
      has_remote = Dir.chdir(shared_dir) do
        system('git remote | grep -q "^www-shared$" 2>/dev/null')
      end

      if has_remote
        Dir.chdir(shared_dir) do
          system('git remote remove www-shared 2>/dev/null')
        end
        puts "  #{'✅'.green} #{site.name.yellow}/shared - removed www-shared remote"
        removed_count += 1
      else
        puts "  #{'⏭️ '.yellow} #{site.name.yellow}/shared - no www-shared remote"
      end
    end

    puts
    if removed_count > 0
      puts "#{'✨'.green} Removed www-shared remote from #{removed_count} site(s)"
    else
      puts "No www-shared remotes found"
    end
  end
end

task default: :serve
