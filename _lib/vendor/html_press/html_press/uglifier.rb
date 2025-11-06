# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'

module HtmlPress
  begin
    require 'uglifier'

    # Compress JavaScript using Uglifier
    #
    # This method compresses JavaScript and optionally caches the result.
    # Cache uses SHA1 hashing of the input to determine cache hits.
    #
    # @param text [String] JavaScript text to compress
    # @param options [Hash, nil] Options passed to Uglifier
    #   See https://github.com/lautis/uglifier#options for available options
    # @param cache_dir [String, nil] Directory path for caching compressed JS
    #   If nil, no caching is performed
    #
    # @return [String] Compressed JavaScript (with trailing semicolon removed)
    #
    # @raise [StandardError] If Uglifier fails to compile the JavaScript
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

      # Compress JavaScript using Uglifier
      begin
        # Remove trailing semicolon for cleaner output
        result = Uglifier.new(options).compile(text).gsub(/;$/, '')

        # Write to cache if directory provided
        if cache_hit
          FileUtils.mkdir_p(my_cache_dir)
          File.write(cache_hit, result)
        end

        result
      rescue => e
        # Output problematic code for debugging
        warn "\nUglifier problem with code snippet:"
        warn '---'
        warn text
        warn '---'
        raise e
      end
    end
  rescue LoadError => e
    # Graceful degradation if Uglifier is not available
    # @param text [String] JavaScript text (returned unmodified)
    # @param options [Hash, nil] Ignored
    # @param cache_dir [String, nil] Ignored
    # @return [String] Original JavaScript text
    def self.js_compressor(text, options = nil, cache_dir = nil)
      text
    end
  end
end
