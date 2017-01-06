# this is shared code for our plugins

HTML_EXTENSIONS = %w(
      .html
      .xhtml
      .htm
    ).freeze

class SimpleLogger
  def error(msg)
    STDERR.puts(msg)
    raise Jekyll::Errors::FatalException.new("HtmlPress: #{msg}")
  end
end

def relative_cache_file_path(full_path)
  Pathname.new(full_path).relative_path_from(Pathname.new File.join(Dir.pwd, '..')).to_s
end

def do_html_press?(site)
  site.config['html_press']['compress']
end

def html_press_cache_dir(site)
  site.config['html_press']['cache']
end

def will_be_generated?(site, me, dest, path)
  site.each_site_file do |item|
    next if item == me
    return true if item.destination(dest) == path
  end
  false
end
