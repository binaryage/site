# frozen_string_literal: true

require 'stringio'
require_relative 'utils'
require_relative 'site'

def pin_workspace(sites)
  sites.each do |site|
    Dir.chdir(site.dir) do
      sys('git checkout web')
      if Dir.exist? 'shared'
        Dir.chdir('shared') do
          sys('git checkout master')
        end
      end
    end
  end
end

def init_workspace(sites)
  sys('git submodule update --init --recursive --depth 42')
  pin_workspace(sites)
end

def prepare_hosts_template(sites)
  io = StringIO.new
  io.puts 'add this section into your /etc/hosts:'
  io.puts
  io.puts "#### #{LOCAL_DOMAIN} test site ####"
  sites.each do |site|
    io.puts "127.0.0.1 #{site.domain}"
  end
  io.puts "#### #{LOCAL_DOMAIN} test site ####"
  io.string
end

def prepare_proxy_config(sites, mode: :serve, proxy_port: 80)
  # header
  config = <<~CONFIG_SNIPPET
    daemon off;
    master_process off;
    error_log /dev/stdout info;
    events {
      worker_connections 1024;
    }
    http {
      server_names_hash_bucket_size  64;
  CONFIG_SNIPPET

  # per-site configs
  sites.each do |site|
    config += <<~CONFIG_SNIPPET
      server {
        listen #{proxy_port};
        server_name #{site.domain};

        location / {
          proxy_buffering off;
          rewrite ^(.*)/$ $1/ break;
          rewrite ^([^.]*)$ $1.html break;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $http_host;
          proxy_set_header X-NginX-Proxy true;
          proxy_pass http://0.0.0.0:#{site.port};
          proxy_redirect off;
        }
      }
    CONFIG_SNIPPET
  end

  # footer
  config += <<~CONFIG_SNIPPET
    }
  CONFIG_SNIPPET

  config
end

def create_build_sites(sites, build_base_port, domain)
  # Create Site objects for built sites with different port range
  sites.each_with_index.map do |site, index|
    Site.new(site.dir, build_base_port + index, domain)
  end
end

def start_python_servers(sites, build_dir)
  # Start Python HTTP servers for each built site
  pids = []

  sites.each do |site|
    site_dir = File.join(build_dir, site.name)
    next unless File.directory?(site_dir)

    puts "Starting Python HTTP server for #{site.name.yellow} on port #{site.port.to_s.blue}..."

    pid = spawn("python3 -m http.server #{site.port}",
                chdir: site_dir,
                out: '/dev/null',
                err: '/dev/null')

    pids << pid
    Process.detach(pid)
  end

  # Give servers time to start
  sleep 1

  pids
end

def stop_python_servers(pids)
  # Stop all Python HTTP servers
  pids.each do |pid|
    Process.kill('TERM', pid)
    Process.wait(pid, Process::WNOHANG)
  rescue Errno::ESRCH, Errno::ECHILD
    # Process already terminated, ignore
  end
end

def publish_workspace(sites, opts)
  sites.each do |site|
    Dir.chdir(site.dir) do
      next if !opts[:force] && git_cwd_clean?

      if `git rev-parse --abbrev-ref HEAD`.strip != 'web'
        puts "#{friendly_dir(Dir.pwd).yellow} not on 'web' branch => #{'skipping'.red}"
        next
      end

      sys('git add -A .')
      sys('git commit --allow-empty -m "publish"')
    end
  end
  return if opts[:dont_push]

  sites.each do |site|
    Dir.chdir(site.dir) do
      sys('git push origin web')
    end
  end
end
