# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'

module HtmlPress
  begin
    require 'terser'

    # Compress JavaScript using Terser
    #
    # This method compresses JavaScript and optionally caches the result.
    # Cache uses SHA1 hashing of the input to determine cache hits.
    #
    # Terser is a modern JavaScript minifier that supports ES6+ syntax.
    # It is the successor to UglifyJS and is actively maintained.
    #
    # @param text [String] JavaScript text to compress
    # @param options [Hash, nil] Options passed to Terser
    #   See https://github.com/ahorek/terser-ruby#options for available options
    # @param cache_dir [String, nil] Directory path for caching compressed JS
    #   If nil, no caching is performed
    #
    # @return [String] Compressed JavaScript (with trailing semicolon removed)
    #
    # @raise [StandardError] If Terser fails to compile the JavaScript
    #
    # @example Without caching
    #   js = "function foo() { return 42; }"
    #   HtmlPress.js_compressor(js)
    #   # => "function foo(){return 42}"
    #
    # @example With options and caching
    #   HtmlPress.js_compressor(js,
    #     { compress: { unused: false } },
    #     '/tmp/cache'
    #   )
    def self.js_compressor(text, options = nil, cache_dir = nil)
      options ||= {}

      # Check cache if directory provided
      if cache_dir
        my_cache_dir = File.join(cache_dir, 'js')
        sha = Digest::SHA1.hexdigest(text)
        cache_hit = File.join(my_cache_dir, sha)

        # Return cached result if available
        cached_content = File.read(cache_hit) if File.exist?(cache_hit)
        return cached_content if cached_content
      end

      # Compress JavaScript using Terser
      begin
        # Remove trailing semicolon for cleaner output
        result = Terser.new(options).compile(text).gsub(/;$/, '')

        # Write to cache if directory provided
        if cache_hit
          FileUtils.mkdir_p(my_cache_dir)
          File.write(cache_hit, result)
        end

        result
      rescue => e
        # Output problematic code for debugging
        warn "\nTerser problem with code snippet:"
        warn '---'
        warn text
        warn '---'
        raise e
      end
    end
  rescue LoadError => e
    # Graceful degradation if Terser is not available
    # @param text [String] JavaScript text (returned unmodified)
    # @param options [Hash, nil] Ignored
    # @param cache_dir [String, nil] Ignored
    # @return [String] Original JavaScript text
    def self.js_compressor(text, options = nil, cache_dir = nil)
      text
    end
  end
end
