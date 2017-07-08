# frozen_string_literal: true

require 'colored2'

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

def die(msg, status=1)
  puts msg.red
  puts
  Signal.trap('EXIT') do
    exit(status)
  end
  raise msg
end

def friendly_dir(dir)
  return dir unless dir.start_with? BASE_DIR
  dir[BASE_DIR.size + 1..-1] || '.'
end

def sys(cmd, check=true)
  workdir = friendly_dir(Dir.pwd)
  puts "(in #{workdir.yellow}) " + "> #{cmd}".blue
  res = system(cmd)
  die '^ something went wrong' if check && !res
end

def patch(path, replacers)
  puts 'Patching ' + path.blue
  lines = []
  File.open(path, 'r') do |f|
    f.each do |line|
      replacers.each do |r|
        line.gsub!(r[0], r[1])
      end
      lines << line
    end
  end
  File.open(path, 'w') do |f|
    f << lines.join
  end
end

def sites_subdomains(sites)
  sites.collect(&:subdomain)
end

def clean_names(names)
  names.collect(&:strip)
end

def lookup_site(sites, _name)
  # we are not too strict here and lookup by name or subdomain
  sites.detect { |site| site.name == ame || site.subdomain == ame }
end

def git_cwd_clean?
  system('test -z "$(git status --porcelain)" > /dev/null')
end
