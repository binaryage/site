require 'colored2'
require 'pathname'
require 'html_press'

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

def press(site, item)
  unless do_press?(site)
    return
  end
  unless HTML_EXTENSIONS.include?(item.output_ext)
    return
  end
  print "#{'COMPRESS'.magenta} generating #{item.inspect.yellow}"

  root_cache_dir = cache_dir(site)
  html_cache_dir = File.join(root_cache_dir, 'html')
  sha = Digest::SHA1.hexdigest(item.output)
  cache_file = File.join(html_cache_dir, sha)
  if File.exists? cache_file
    print "<= cache @ #{relative_cache_file_path(cache_file).green}\n"
    return
  end

  # cache miss
  print '=> pressing'
  item.output = HtmlPress.press(item.output, {
      :strip_crlf => false,
      :logger => SimpleLogger.new,
      :cache => root_cache_dir
  })

  FileUtils.mkdir_p(html_cache_dir)
  File.open(cache_file, 'w') { |f| f.write(item.output) }
  print " @ #{relative_cache_file_path(cache_file).red}\n"
  true
end

Jekyll::Hooks.register([:documents, :pages], :post_render) do |item|
  press(item.site, item)
end
