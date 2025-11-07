# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require 'tempfile'

module HtmlPress
  # Compress CSS using Lightning CSS
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

    # Compress CSS using Lightning CSS
    result = compress_with_lightningcss(text)

    # Write to cache if directory provided
    if cache_hit
      FileUtils.mkdir_p(my_cache_dir)
      File.write(cache_hit, result)
    end

    result
  end

  # Compress CSS using Lightning CSS CLI
  #
  # Uses the lightningcss-cli binary from _node/node_modules/.bin/
  # Falls back to uncompressed CSS if binary is not found.
  #
  # @param css_text [String] CSS text to compress
  # @return [String] Compressed CSS or original text if compression fails
  #
  # @api private
  def self.compress_with_lightningcss(css_text)
    # Get path to lightningcss binary from _node/node_modules
    root = File.expand_path(File.join(File.dirname(__FILE__), '../../../..'))
    lightningcss_bin = File.join(root, '_node/node_modules/.bin/lightningcss')

    unless File.exist?(lightningcss_bin)
      warn "⚠️  Lightning CSS binary not found at: #{lightningcss_bin}"
      warn "    Run 'rake init' or 'npm install' in _node/ to install dependencies."
      return css_text # Return uncompressed
    end

    source_file = Tempfile.new(['source', '.css'])
    result_file = Tempfile.new(['result', '.css'])

    begin
      source_file.write(css_text)
      source_file.close

      cmd = "#{lightningcss_bin} --minify --bundle --targets '>= 0.25%' #{source_file.path} -o #{result_file.path}"
      success = system(cmd, out: File::NULL, err: File::NULL)

      if success
        File.read(result_file.path)
      else
        warn '⚠️  Lightning CSS compression failed, using uncompressed CSS'
        css_text
      end
    ensure
      source_file.unlink if source_file
      result_file.unlink if result_file
    end
  end

  private_class_method :compress_with_lightningcss
end
