# frozen_string_literal: true

require_relative 'colored2'
require_relative 'utils.rb'
require_relative 'site.rb'
require_relative 'workspace.rb'
require_relative 'build.rb'
require_relative 'store.rb'

## CONFIG ###################################################################################################################

BASE_PORT = 4101
MAIN_PORT = 80 # we will need admin rights to bind to this port when running `rake proxy`
LOCAL_DOMAIN = 'binaryage.org' # this domain is for testing to be set in /etc/hosts, see `rake hosts`

MIN_YARN_VERSION = '0.24.4'
MIN_GEM_VERSION = '1.8.23'

STATIC_CDN_URL = 'https://static.binaryage.com/'
STATIC_CDN_PUSH_URL = 'user_ho054rw1@push-1.cdn77.com:/www/'

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
    puts prepare_proxy_config(SITES)
  end
end

desc 'start proxy server'
task :proxy do
  trap('INT') do
    exit 10
  end
  config_path = File.join(STAGE_DIR, '.proxy.config')
  FileUtils.mkdir_p(STAGE_DIR) unless File.exist? STAGE_DIR
  sys("rake -s proxy:config > \"#{config_path}\"")
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

desc 'build site'
task :build do
  what = (ENV['what'] || sites_subdomains(SITES).join(','))
  names = clean_names(what.split(','))

  # TODO: we could bring in more stuff from env
  build_opts = {
    stage: ENV['stage'] || BUILD_DIR,
    dev_mode: false,
    clean_stage: true,
    busters: true,
    cdn: false,  # Disable static CDN - serve assets locally from each repo
    static_cdn_url: STATIC_CDN_URL,
    static_cdn_push_url: STATIC_CDN_PUSH_URL
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

task default: :serve
