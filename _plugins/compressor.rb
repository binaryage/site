# frozen_string_literal: true

require 'colored2'
require 'pathname'
require_relative '_shared'

def press_html!(site, item)
  return unless do_html_press?(site)
  return unless HTML_EXTENSIONS.include?(item.output_ext)

  print "#{'COMPRESS'.magenta} generating #{item.inspect.yellow}"

  root_cache_dir = html_press_cache_dir(site)
  html_cache_dir = File.join(root_cache_dir, 'html')
  sha = Digest::SHA1.hexdigest(item.output)
  cache_file = File.join(html_cache_dir, sha)
  if File.exist? cache_file
    print "<= cache @ #{relative_cache_file_path(cache_file).green}\n"
    item.output = File.read(cache_file)
    return
  end

  # cache miss
  print '=> pressing'
  item.output = HtmlPress.press(item.output, strip_crlf: false,
                                             logger: SimpleLogger.new,
                                             cache: root_cache_dir)

  FileUtils.mkdir_p(html_cache_dir)
  File.write(cache_file, item.output)
  print " @ #{relative_cache_file_path(cache_file).red}\n"
  true
end
