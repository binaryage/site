# this is shared code for our plugins

HTML_EXTENSIONS = %w(
      .html
      .xhtml
      .htm
    ).freeze

class SimpleLogger
  def error(msg)
    STDERR.puts(msg)
    raise FatalException.new("HtmlPress: #{msg}")
  end
end

def relative_cache_file_path(full_path)
  Pathname.new(full_path).relative_path_from(Pathname.new File.join(Dir.pwd, '..')).to_s
end

def do_press?(site)
  site.config['html_press']['compress']
end

def cache_dir(site)
  site.config['html_press']['cache']
end

def will_be_generated?(site, me, dest, path)
  return true if site.pages.any? { |f| f!=me and f.destination(dest) == path }
  return true if site.static_files.any? { |f| f!=me and f.destination(dest) == path }
  false
end
