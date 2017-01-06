require 'colored2'

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

def die(msg, code=1)
  puts msg.red
  exit(code)
end

def friendly_dir(dir)
  return dir unless dir.start_with? BASE_DIR
  dir[BASE_DIR.size+1..-1] or '.'
end

def sys(cmd, check=true)
  workdir = friendly_dir(Dir.pwd)
  puts "(in #{workdir.yellow}) " + "> #{cmd}".blue
  res = system(cmd)
  if check and not res
    die 'something went wrong'
  end
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
  sites.collect { |site| site.subdomain }
end

def clean_names(names)
  names.collect { |name| name.strip }
end

def lookup_site(sites, name)
  # we are not too strict here and lookup by name or subdomain
  sites.detect { |site| site.name==name or site.subdomain==name }
end

def git_cwd_clean?
  system("test -z \"$(git status --porcelain)\" > /dev/null")
end
