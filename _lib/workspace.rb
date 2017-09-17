# frozen_string_literal: true

require_relative 'utils.rb'
require_relative 'site.rb'

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

def reset_workspace(sites)
  sites.each do |slave|
    Dir.chdir(slave.dir) do
      sys('git checkout -f web')
      sys('git reset --hard HEAD^') # be resilient to amends
      sys('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
      sys('git pull origin web')
      if Dir.exist? 'shared'
        Dir.chdir('shared') do
          sys('git checkout -f master')
          sys('git reset --hard HEAD^') # be resilient to amends
          sys('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
          sys('git pull origin master')
        end
      end
    end
  end
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

def prepare_proxy_config(sites)
  # header
  config = <<~eos
    daemon off;
    master_process off;
    error_log /dev/stdout info;
    events {
      worker_connections 1024;
    }
    http {
eos

  # per-site configs
  sites.each do |site|
    config += <<eos
  server {
    listen 80;
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
eos
  end

  # footer
  config += <<~eos
    }
eos

  config
end

def publish_workspace(sites, opts)
  sites.each do |site|
    Dir.chdir(site.dir) do
      next if !(opts[:force]) && git_cwd_clean?
      if `git rev-parse --abbrev-ref HEAD`.strip != 'web'
        puts "#{friendly_dir(Dir.pwd).yellow} not on 'web' branch => #{'skipping'.red}"
        next
      end

      sys('git add -A .')
      sys('git commit --allow-empty -m "publish"')
    end
  end
  unless opts[:dont_push]
    sites.each do |site|
      Dir.chdir(site.dir) do
        sys('git push origin web')
      end
    end
  end
end
