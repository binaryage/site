# frozen_string_literal: true

require_relative '../colored2'
require_relative '../utils'
require_relative '../site'
require_relative '../workspace'
require_relative '../build'
require_relative '../store'

BASE_PORT = 4101
BUILD_BASE_PORT = 8000 # base port for serving built static sites
MAIN_PORT = 80 # we will need admin rights to bind to this port when running `rake proxy`
LOCAL_DOMAIN = 'binaryage.org' # this domain is for testing to be set in /etc/hosts, see `rake hosts`

MIN_GEM_VERSION = '1.8.23'

# Node.js package manager (npm, yarn, or bun)
NODE_PKG_MANAGER = ENV.fetch('NODE_PKG_MANAGER', 'npm')

ROOT = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
NODE_DIR = File.join(ROOT, '_node')
STAGE_DIR = File.join(ROOT, '.stage')
SERVE_DIR = File.join(STAGE_DIR, 'serve')
BUILD_DIR = File.join(STAGE_DIR, 'build')
STORE_DIR = File.join(STAGE_DIR, 'store')
SNAPSHOTS_DIR = File.join(ROOT, '.snapshots')
SNAPSHOT_EXCLUDES = ['_cache', '.configs', 'atom.xml']
SCREENSHOTS_DIR = File.join(ROOT, '.screenshots')
SCREENSHOT_EXCLUDES = ['support'] # Sites to exclude from screenshots (e.g., redirects)

# Dynamically detect all git submodules at root level
DIRS = `git config --file .gitmodules --get-regexp path`
         .lines
         .map { |line| line.split[1] }
         .compact
         .freeze

SITES = DIRS.each_with_index.collect do |dir, index|
  Site.new(File.join(ROOT, dir), BASE_PORT + index, LOCAL_DOMAIN)
end
