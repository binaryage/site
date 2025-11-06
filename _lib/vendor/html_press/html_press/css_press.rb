# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'

module HtmlPress
  require 'yui/compressor'

  # Compress CSS using YUI Compressor
  #
  # This method compresses CSS and optionally caches the result.
  # Cache uses SHA1 hashing of the input to determine cache hits.
  #
  # @param text [String] CSS text to compress
  # @param cache_dir [String, nil] Directory path for caching compressed CSS
  #   If nil, no caching is performed
  #
  # @return [String] Compressed CSS
  #
  # @example Without caching
  #   css = "body { color: red; }"
  #   HtmlPress.style_compressor(css)
  #   # => "body{color:red}"
  #
  # @example With caching
  #   HtmlPress.style_compressor(css, '/tmp/cache')
  #   # First call: compresses and caches
  #   # Second call: returns from cache
  def self.style_compressor(text, cache_dir = nil)
    # Check cache if directory provided
    if cache_dir
      my_cache_dir = File.join(cache_dir, 'css')
      sha = Digest::SHA1.hexdigest(text)
      cache_hit = File.join(my_cache_dir, sha)

      # Return cached result if available
      cached_content = File.read(cache_hit) if File.exist?(cache_hit)
      return cached_content if cached_content
    end

    # Compress CSS using YUI Compressor
    compressor = YUI::CssCompressor.new
    result = compressor.compress(text)

    # Write to cache if directory provided
    if cache_hit
      FileUtils.mkdir_p(my_cache_dir)
      File.write(cache_hit, result)
    end

    result
  end
end
