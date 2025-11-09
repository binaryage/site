# frozen_string_literal: true

require 'digest/sha1'
require 'pathname'
require 'yaml'

require_relative 'utils'
require_relative 'cache_version'
require_relative 'build_lock'

# noinspection RubyStringKeysInHashInspection
def prepare_jekyll_config(site, opts)
  dev_mode = opts[:dev_mode]
  stage = opts[:stage]
  busters = opts[:busters]
  domain = "binaryage.#{dev_mode ? 'org' : 'com'}"

  begin
    config = YAML.load_file('_config.yml')
  rescue => _e
    config = {}
  end
  config['plugins'] ||= []
  config['plugins'] << 'jekyll-redirect-from' # see https://help.github.com/articles/redirects-on-github-pages/
  config['layouts_dir'] = 'shared/layouts'
  config['includes_dir'] = 'shared/includes'
  config['plugins_dir'] = '../_ruby/jekyll-plugins'
  config['target_url'] = "https://#{site.subdomain}.#{domain}"
  config['enforce_ssl'] = "#{site.subdomain}.#{domain}"
  config['dev'] = dev_mode
  config['combinejs'] = [{
    'path' => './shared/js/code.list',
    'minify' => !dev_mode
  }, {
    'path' => './shared/js/changelog.list',
    'minify' => !dev_mode
  }]
  config['html_press'] = {
    'compress' => !dev_mode,
    'cache' => File.join(stage, '_cache')
  }
  config['cache_dir'] = File.join(stage, '_cache', 'jekyll', site.name)
  config['busterizer'] = {
    'css' => busters && !dev_mode,
    'html' => busters && !dev_mode
  }

  config.delete('prune_files') if opts[:dont_prune]

  output = YAML.dump(config)
  sha = Digest::SHA1.hexdigest output
  sha = sha[0..7]

  configs_dir = File.join(stage, '.configs')
  FileUtils.mkdir_p(configs_dir)
  config_path = File.join(configs_dir, "#{site.name}_jekyll_config_#{sha}.yml")
  File.write(config_path, output)

  Pathname.new(config_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
end

def debugger_prefix
  return '' unless ENV['debug_jekyll']

  die 'you must have set RDEBUG_PREFIX env var' unless ENV['RDEBUG_PREFIX']
  ENV.fetch('RDEBUG_PREFIX', nil)
end

def bundle_exec
  bundle_path = `which bundle`.strip
  gemfile_path = File.join(ROOT, '_ruby/Gemfile')
  debugger_prefix + "\"#{bundle_path}\" exec --gemfile=\"#{gemfile_path}\" "
end

def build_site(site, opts)
  dest = File.join(opts[:stage], site.name)

  sys("rm -rf \"#{dest}\"") if opts[:clean_stage]

  # build jekyll
  Dir.chdir site.dir do
    config_path = prepare_jekyll_config(site, opts)
    cmd = bundle_exec +
          'jekyll build ' \
          "--config \"#{config_path}\" " \
          "--destination \"#{dest}\" " \
          '--trace'
    # NODE_NO_WARNINGS is needed to silence stylus, https://github.com/stylus/stylus/issues/2534
    sys(cmd, true, { 'NODE_NO_WARNINGS' => '1' })
  end

  # noinspection RubyResolve
  puts "=> #{dest.to_s.magenta}"
end

def build_sites(sites, opts, names)
  # Acquire lock for this stage to prevent concurrent builds
  lock = BuildLock.new(opts[:stage])
  lock.acquire!

  begin
    # Check and invalidate cache if plugins/dependencies changed
    cache_dir = File.join(opts[:stage], '_cache')
    CacheVersion.check_and_invalidate_if_needed(cache_dir)

    names.each do |name|
      site = lookup_site(sites, name)
      if site
        build_site(site, opts)
      else
        puts "unable to lookup site name '#{name}', valid names: '#{sites_subdomains(sites).join(',')}'"
      end
    end
  ensure
    lock.release
  end
end

def serve_site(site, base_dir, index)
  port = site.port
  livereload_port = 35729 + index  # Base LiveReload port + site index
  Dir.chdir site.dir do
    opts = { dev_mode: true,
             stage: base_dir }
    config_path = prepare_jekyll_config(site, opts)
    work_dir = File.join(base_dir, site.name)
    FileUtils.mkdir_p(work_dir)
    fork do
      trap('INT') { exit 11 }
      cmd = bundle_exec +
            'jekyll serve ' \
            '--incremental ' \
            '--drafts ' \
            '--livereload ' \
            "--livereload-port #{livereload_port} " \
            '--trace ' \
            "--port #{port} " \
            '-b / ' \
            "--config \"#{config_path}\" " \
            "--destination \"#{work_dir}\""
      # NODE_NO_WARNINGS is needed to silence stylus, https://github.com/stylus/stylus/issues/2534
      sys(cmd, true, { 'NODE_NO_WARNINGS' => '1' })
    end
    sleep(0.2)
  end
end

def serve_sites(sites, base_dir, names)
  # Acquire lock for this stage to prevent concurrent serves
  lock = BuildLock.new(base_dir)
  lock.acquire!

  begin
    # Check and invalidate cache if plugins/dependencies changed
    cache_dir = File.join(base_dir, '_cache')
    CacheVersion.check_and_invalidate_if_needed(cache_dir)

    names.each_with_index do |name, index|
      site = lookup_site(sites, name)
      if site
        serve_site(site, base_dir, index)
      else
        puts "unable to lookup site name '#{name}', valid names: '#{sites_subdomains(sites).join(',')}'"
      end
    end

    # wait for signal and instantly kill all offsprings
    # http://autonomousmachine.com/posts/2011/6/2/cleaning-up-processes-in-ruby
    trap('INT') { exit 10 }
    at_exit do
      # if process exits on its own we want to kill whole group
      Process.kill('INT', -Process.getpgrp)
    end

    Process.waitall
  ensure
    lock.release
  end
end
