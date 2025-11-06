module HtmlPress
  require 'yui/compressor'
  def self.style_compressor (text, cache_dir=nil)
    if cache_dir then
      my_cache_dir = File.join(cache_dir, "css")
      sha = Digest::SHA1.hexdigest text
      cache_hit = File.join(my_cache_dir, sha)
      return File.read(cache_hit) if File.exist? cache_hit
    end
    compressor = YUI::CssCompressor.new
    res = compressor.compress text
    if cache_hit then
      FileUtils.mkdir_p(my_cache_dir)
      File.open(cache_hit, 'w') {|f| f.write(res) }
    end
    res
  end
end