require 'colored2'

require_relative 'utils.rb'
require_relative 'site.rb'

def init_workspace(sites, git_url)
  master = sites[0]
  slaves = sites[1..-1]

  sys("git remote set-url --push origin #{git_url}")

  sys('git submodule init')
  sys("git submodule update \"#{master.dir}\"")

  # download submodules into master site
  Dir.chdir(master.dir) do
    sys('git checkout web')
    sys('git submodule update --init shared')
    Dir.chdir('shared') do
      # fix push url in submodule
      sys("git remote set-url --push origin #{git_url}")
      sys('git checkout master')
    end
  end

  # for each slave, "symlink" submodules from master repo
  slaves.each do |slave|
    sys("git submodule update \"#{slave.dir}\"")
    sys("rmdir \"#{slave.dir}/shared\"") if File.directory?("#{slave.dir}/shared")
    sys("./_bin/hlink/hlink \"#{master.dir}/shared\" \"#{slave.dir}/shared\"")
  end

  # fix push urls
  sites.each do |site|
    Dir.chdir(site.dir) do
      sys("git remote set-url --push origin #{git_url}")
    end
  end

  # this is here for case there are additional submodules outside sites
  sys('git submodule update --init --recursive')
end

def update_workspace(sites)
  master = sites[0]
  slaves = sites[1..-1]

  # move to branch tips
  Dir.chdir(master.dir) do
    sys('git checkout web')
    Dir.chdir('shared') do
      # note this will reflect in all hard-linked shared folders
      sys('git checkout master')
    end
  end

  slaves.each do |slave|
    Dir.chdir(slave.dir) do
      sys('git checkout web')
      Dir.chdir('shared') do
        # note this should be a no-op under hard-linked setup
        sys('git checkout master')
      end
    end
  end
end

# noinspection RubyResolve
def reset_workspace(sites)
  master = sites[0]
  slaves = sites[1..-1]
  Dir.chdir(master.dir) do
    sys('git checkout -f web')
    sys('git reset --hard HEAD^') # be resilient to amends
    sys('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
    sys('git pull origin web')
    ['shared'].each do |submodule|
      submodule = File.join(master.dir, submodule)
      Dir.chdir(submodule) do
        sys('git checkout -f master')
        sys('git reset --hard HEAD^') # be resilient to amends
        sys('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
        sys('git pull origin master')
      end
    end
  end
  slaves.each do |slave|
    Dir.chdir(slave.dir) do
      sys('git checkout -f web')
      sys('git reset --hard HEAD^') # be resilient to amends
      sys('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
      sys('git pull origin web')
    end
    # shared should be hard linked, so we got pull for free from master
  end
end

def prepare_hosts_template(sites)
  io = StringIO.new
  io.puts 'add this section into your /etc/hosts:'
  io.puts
  io.puts "#### #{domain} test site ####"
  sites.each do |site|
    io.puts "127.0.0.1 #{site.domain}"
  end
  io.puts "#### #{domain} test site ####"
  io.string
end

def prepare_proxy_config(sites)

  # header
  config = <<eos
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
  config += <<eos
}
eos

  config
end