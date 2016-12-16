require 'colored2'
require 'pathname'
require 'html_press'
require_relative '_shared'

def press_html!(site, item)
  unless do_html_press?(site)
    return
  end
  unless HTML_EXTENSIONS.include?(item.output_ext)
    return
  end
  print "#{'COMPRESS'.magenta} generating #{item.inspect.yellow}"

  root_cache_dir = html_press_cache_dir(site)
  html_cache_dir = File.join(root_cache_dir, 'html')
  sha = Digest::SHA1.hexdigest(item.output)
  cache_file = File.join(html_cache_dir, sha)
  if File.exists? cache_file
    print "<= cache @ #{relative_cache_file_path(cache_file).green}\n"
    item.output = File.read(cache_file)
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
