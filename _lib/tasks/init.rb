# frozen_string_literal: true

namespace :init do
  desc 'install Node.js dependencies'
  task :node do
    Dir.chdir NODE_DIR do
      sys('rm -rf node_modules')
      sys("#{NODE_PKG_MANAGER} install")
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
      die "lightningcss-cli not found. Run 'rake init:node' first."
    end

    puts "✓ lightningcss-cli found at #{lightningcss_bin}".green
  end

  desc 'init submodules'
  task :repo do
    init_workspace(SITES)
  end
end

desc 'init workspace - needs special care'
task init: ['init:gem', 'init:node', 'init:lightningcss', 'init:repo']
