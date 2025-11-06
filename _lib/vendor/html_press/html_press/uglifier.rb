require 'digest/sha1'

module HtmlPress
  begin
    require 'uglifier'
    # Available options https://github.com/lautis/uglifier#options
    def self.js_compressor (text, options = nil, cache_dir=nil)
      options ||= {}
      if cache_dir then
        my_cache_dir = File.join(cache_dir, "js")
        sha = Digest::SHA1.hexdigest text
        cache_hit = File.join(my_cache_dir, sha)
        return File.read(cache_hit) if File.exist? cache_hit
      end
      begin
        res = Uglifier.new(options).compile(text).gsub(/;$/, '')
        if cache_hit then
          FileUtils.mkdir_p(my_cache_dir)
          File.open(cache_hit, 'w') { |f| f.write(res) }
        end
        res
      rescue => e
        puts "\nUglifier problem with code snippet:"
        puts "---"
        puts text
        puts "---"
        raise e
      end
    end
  rescue LoadError => e
    def self.js_compressor (text, options = nil)
      text
    end
  end
end
