require 'colored2'
require 'digest/sha1'
require 'pathname'
require 'yaml'

require_relative 'utils.rb'

# noinspection RubyStringKeysInHashInspection
def prepare_jekyll_config(site, opts)
  dev_mode = opts[:dev_mode]
  stage = opts[:stage]
  busters = opts[:busters]
  domain = 'binaryage.'+(dev_mode ? 'org' : 'com')

  begin
    config = YAML.load_file('_config.yml')
  rescue => _
    config = {}
  end
  config['gems'] ||= []
  config['gems'] << 'jekyll-coffeescript'
  config['layouts_dir'] = 'shared/layouts'
  config['plugins_dir'] = '../_plugins'
  config['target_url'] = "https://#{site.subdomain}.#{domain}"
  config['enforce_ssl'] = "#{site.subdomain}.#{domain}"
  config['markdown'] = 'rdiscount'
  config['dev'] = dev_mode
  config['stylus'] = {
      'compress' => (not dev_mode),
      'debug' => dev_mode,
      'path' => './shared/css/site.styl'
  }
  config['combinejs'] = {
      'path' => './shared/js/code.list',
      'minify' => (not dev_mode)
  }
  config['html_press'] = {
      'compress' => (not dev_mode),
      'cache' => File.join(stage, '_cache')
  }
  config['cdn'] = {
      'enabled' => (not dev_mode and opts[:cdn]),
      'zone' => File.join(stage, '_cdn'),
      'url' => opts[:cdn_url]
  }
  config['busterizer'] = {
      'css' => (busters and (not dev_mode)),
      'html' => (busters and (not dev_mode))
  }

  output = YAML.dump(config)
  sha = Digest::SHA1.hexdigest output
  sha = sha[0..7]

  configs_dir = File.join(stage, '.configs')
  FileUtils.mkdir_p(configs_dir)
  config_path = File.join(configs_dir, site.name+'_jekyll_config_'+sha+'.yml')
  File.open(config_path, 'w') { |f| f.write(output) }

  Pathname.new(config_path).relative_path_from(Pathname.new Dir.pwd).to_s
end

def build_site(site, opts)
  dest = File.join(opts[:stage], site.name)

  sys("rm -rf \"#{dest}\"") if opts[:clean_stage]

  # build jekyll
  Dir.chdir site.dir do
    config_path = prepare_jekyll_config(site, opts)
    sys("bundle exec jekyll build --config \"#{config_path}\" --destination \"#{dest}\" --trace")
  end

  # noinspection RubyResolve
  puts '=> ' + "#{dest}".magenta
end

def build_sites(sites, opts, names)
  names.each do |name|
    site = lookup_site(sites, name)
    if site
      build_site(site, opts)
    else
      puts "unable to lookup site name '#{name}', valid names: '#{sites_subdomains(sites).join(',')}'"
    end
  end
end

def serve_site(site, base_dir)
  port = site.port
  Dir.chdir site.dir do
    config_path = prepare_jekyll_config(site, {:dev_mode => true,
                                               :stage => base_dir})
    work_dir = File.join(base_dir, site.name)
    FileUtils.mkdir_p(work_dir)
    fork do
      trap('INT') { exit 11 }
      sys("bundle exec jekyll serve --incremental --drafts --port 1#{port} -b / --config \"#{config_path}\" --destination \"#{work_dir}\"")
    end
    sleep(0.2)
    fork do
      trap('INT') { exit 12 }
      # see https://browsersync.io/docs/command-line
      verbosity = '--logLevel info'
      submisivity = '--no-ui --no-online --no-open'
      plugins = " --plugins \"bs-html-injector?files[]=#{work_dir}/**/*.html\""
      locations = "--port #{port} --proxy http://localhost:1#{port} --files \"#{work_dir}/**/*.css\""
      sys("cd .. && _node/node_modules/.bin/browser-sync start #{verbosity} #{submisivity} #{plugins} #{locations}")
    end
    sleep(0.2)
  end
end

def serve_sites(sites, base_dir, names)
  names.each do |name|
    site = lookup_site(sites, name)
    if site
      serve_site(site, base_dir)
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
end
