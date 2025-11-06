# frozen_string_literal: true

require 'htmlentities'
require 'securerandom'

module HtmlPress
  # HTML entities processor
  #
  # Decodes HTML entities while preserving special characters that should
  # remain encoded (&lt;, &gt;, &amp;).
  class Entities
    # Initialize a new Entities processor
    def initialize
      # Use SecureRandom to avoid collisions in parallel processing
      @replacement_hash = "MINIFYENTITY#{SecureRandom.hex(8)}"
      @placeholders = []
    end

    # Reserve a placeholder for content that should not be decoded
    #
    # @param content [String] Content to preserve
    # @return [String] Placeholder string
    # @api private
    def reserve(content)
      @placeholders.push(content)
      "%#{@replacement_hash}%#{@placeholders.size - 1}%"
    end

    # Minify HTML by decoding entities while preserving special characters
    #
    # This method:
    # 1. Reserves &lt;, &gt;, &amp; (and their numeric equivalents)
    # 2. Decodes all other HTML entities
    # 3. Restores the reserved characters
    #
    # @param text [String] HTML text with entities
    # @return [String] HTML with decoded entities (except reserved ones)
    #
    # @example
    #   entities = HtmlPress::Entities.new
    #   entities.minify("&lt;div&gt; &nbsp; &copy;")
    #   # => "<div>   ©"
    def minify(text)
      out = text.dup

      # Reserve characters that must stay encoded
      out.gsub!(/&lt;|&#60;|&gt;|&#62;|&amp;|&#38;/) do |match|
        reserve(match)
      end

      # Decode all other entities
      out = HTMLEntities.new.decode(out)

      # Restore reserved characters
      replacement_regex = Regexp.new("%#{@replacement_hash}%(\\d+)%")
      out.gsub!(replacement_regex) do |match|
        index = match[replacement_regex, 1].to_i
        @placeholders[index]
      end

      out
    end
  end

  # Compress HTML entities in text
  #
  # @param text [String] HTML text with entities
  # @return [String] HTML with compressed entities
  # @api public
  def self.entities_compressor(text)
    Entities.new.minify(text)
  end
end
