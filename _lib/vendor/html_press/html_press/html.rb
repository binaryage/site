# frozen_string_literal: true

module HtmlPress
  # Main HTML compression engine
  #
  # This class handles the core HTML compression logic including:
  # - Extracting and preserving <code> and <pre> blocks
  # - Processing inline <script> and <style> tags
  # - Removing HTML comments
  # - Trimming whitespace
  # - Processing block elements
  # - Re-indenting output for readability
  class Html
    # Default compression options
    DEFAULTS = {
      logger: false,
      unquoted_attributes: false,
      drop_empty_values: false,
      strip_crlf: false,
      js_minifier_options: false
    }.freeze

    # Regex patterns (compiled once for performance)
    REGEX_CODE_BLOCK = /<code>(.*?)<\/code>/mi.freeze
    REGEX_PRE_BLOCK = /<pre>(.*?)<\/pre>/mi.freeze
    REGEX_CARRIAGE_RETURN = /\r/.freeze
    REGEX_EMPTY_LINE = /^$\n/.freeze
    REGEX_SCRIPT_TAG = /(<script.*?>)(.*?)(<\/script>)/im.freeze
    REGEX_STYLE_TAG = /(<style.*?>)(.*?)(<\/style>)/im.freeze
    REGEX_EMPTY_COMMENT = /<!--([ \t]*?)-->/.freeze
    REGEX_LINE_WHITESPACE = /^[ \t]+|[ \t]+$/m.freeze
    REGEX_TAG_WITH_ATTRS = /<([a-z\-:]+)([^>]*?)([\/]*?)>/i.freeze
    REGEX_TAG_SCAN = /<([\/]?[a-z\-:]+)([^>]*?)>/i.freeze
    REGEX_NEWLINES = /[\r\n]+/.freeze
    REGEX_WHITESPACE = /[ \t]+/.freeze
    REGEX_ATTR_NEWLINES = /[\n]+/.freeze
    REGEX_ATTR_SPACES = /[ ]+/.freeze
    REGEX_BETWEEN_TAGS = />([^<]+)</.freeze

    # Initialize HTML compressor
    #
    # @param options [Hash] Compression options
    # @option options [Logger, nil] :logger Logger instance for error reporting
    # @option options [Boolean] :unquoted_attributes Remove quotes from HTML attributes
    # @option options [Boolean] :drop_empty_values Drop empty attribute values
    # @option options [Boolean] :strip_crlf Strip CRLF characters
    # @option options [Hash, nil] :js_minifier_options Options passed to Terser
    # @option options [String, nil] :cache Directory path for caching compressed JS/CSS
    #
    # @raise [ArgumentError] If logger doesn't respond to :error
    def initialize(options = {})
      @options = DEFAULTS.merge(options)

      # Handle deprecated option name
      if @options.key?(:dump_empty_values)
        @options[:drop_empty_values] = @options.delete(:dump_empty_values)
        warn 'dump_empty_values deprecated use drop_empty_values'
      end

      # Validate logger interface
      if @options[:logger] && !@options[:logger].respond_to?(:error)
        raise ArgumentError, 'Logger has no error method'
      end
    end

    # Extract <code> blocks and replace with placeholders
    #
    # @param html [String] HTML content
    # @return [String] HTML with <code> blocks replaced by placeholders
    # @api private
    def extract_code_blocks(html)
      @code_blocks = []
      html.gsub(REGEX_CODE_BLOCK) do
        @code_blocks << Regexp.last_match(1)
        "<code>##HTMLPRESSCODEBLOCK#{@code_blocks.size - 1}##</code>"
      end
    end

    # Restore <code> blocks from placeholders
    #
    # @param html [String] HTML with placeholders
    # @return [String] HTML with restored <code> blocks
    # @api private
    def return_code_blocks(html)
      html.gsub(/##HTMLPRESSCODEBLOCK(\d+)##/) do
        @code_blocks[Regexp.last_match(1).to_i]
      end
    end

    # Extract <pre> blocks and replace with placeholders
    #
    # @param html [String] HTML content
    # @return [String] HTML with <pre> blocks replaced by placeholders
    # @api private
    def extract_pre_blocks(html)
      @pre_blocks = []
      html.gsub(REGEX_PRE_BLOCK) do
        @pre_blocks << Regexp.last_match(1)
        "<pre>##HTMLPRESSPREBLOCK#{@pre_blocks.size - 1}##</pre>"
      end
    end

    # Restore <pre> blocks from placeholders
    #
    # @param html [String] HTML with placeholders
    # @return [String] HTML with restored <pre> blocks
    # @api private
    def return_pre_blocks(html)
      html.gsub(/##HTMLPRESSPREBLOCK(\d+)##/) do
        @pre_blocks[Regexp.last_match(1).to_i]
      end
    end

    # Compress HTML content
    #
    # This is the main compression method that orchestrates all compression steps:
    # 1. Extract <pre> and <code> blocks
    # 2. Process inline scripts and styles
    # 3. Remove HTML comments
    # 4. Trim whitespace
    # 5. Process block elements
    # 6. Re-indent output
    # 7. Restore preserved blocks
    #
    # @param html [String, IO] HTML content to compress
    # @return [String] Compressed HTML
    #
    # @example
    #   compressor = HtmlPress::Html.new
    #   compressor.press("<html>\n  <body>Hello</body>\n</html>")
    #   # => "<html>\n  <body>Hello</body>\n</html>"
    def press(html)
      # Handle both String and IO objects
      # Only dup if necessary (frozen strings or to avoid mutating input)
      out = html.respond_to?(:read) ? html.read : html.to_s
      out = out.dup if out.frozen?

      # Early return for empty input
      return '' if out.empty?

      # Extract blocks that should not be compressed
      out = extract_pre_blocks(out)
      out = extract_code_blocks(out)

      # Remove carriage returns
      out.gsub!(REGEX_CARRIAGE_RETURN, '')

      # Process inline scripts and styles
      out = process_scripts(out)
      out = process_styles(out)

      # Compress HTML structure
      out = process_html_comments(out)
      out = trim_lines(out)
      out = process_block_elements(out)
      out = process_whitespaces(out)

      # Clean up attributes and void elements
      out = process_attributes(out)
      out = fixup_void_elements(out)

      # Remove empty lines
      out.gsub!(REGEX_EMPTY_LINE, '')

      # Format and restore preserved blocks
      out = reindent(out)
      out = return_code_blocks(out)
      out = return_pre_blocks(out)
      out
    end

    # Backward compatibility alias for {#press}
    # @deprecated Use {#press} instead
    alias compile press

    protected

    # Re-indent HTML for readability
    #
    # Adds 2-space indentation based on tag nesting level.
    # Handles special cases for <script>, <style>, <code>, and <pre> tags.
    #
    # @param out [String] HTML to re-indent
    # @return [String] Re-indented HTML
    # @api private
    def reindent(out)
      level = 0
      in_script = 0
      in_style = 0
      in_code = 0
      in_pre = 0
      result = []

      out.split("\n").each do |line|
        pre_level = level

        # Track nesting level by scanning tags
        line.scan(REGEX_TAG_SCAN) do
          tag = Regexp.last_match(1)
          full_match = Regexp.last_match(0)

          # Track special blocks that affect indentation
          in_code += 1 if tag == 'code'
          in_code -= 1 if tag == '/code'
          in_pre += 1 if tag == 'pre'
          in_pre -= 1 if tag == '/pre'

          if tag == 'script'
            level += 1
            in_script += 1
          end
          in_script -= 1 if tag == '/script'

          if tag == 'style'
            level += 1
            in_style += 1
          end
          in_style -= 1 if tag == '/style'

          # Skip comments and self-closing tags
          next if full_match[1] == '!'
          next if full_match[-2] == '/'
          next if in_style > 0 || in_script > 0

          # Adjust level for opening/closing tags
          tag[0] == '/' ? level -= 1 : level += 1
          level = 0 if level.negative?
        end

        # Use the smaller indentation level to avoid over-indenting closing tags
        indent_level = [level, pre_level].min
        indent_level = 0 if (in_code > 0 || in_pre > 0) && level <= pre_level

        result << (('  ' * indent_level) + line)
      end

      result.join("\n")
    end

    # Process HTML attributes
    #
    # Normalizes whitespace in attributes:
    # - Replaces newlines with spaces
    # - Collapses multiple spaces into one
    # - Trims trailing whitespace
    #
    # @param out [String] HTML to process
    # @return [String] HTML with processed attributes
    # @api private
    def process_attributes(out)
      out.gsub(REGEX_TAG_WITH_ATTRS) do
        tag = Regexp.last_match(1)
        attrs = Regexp.last_match(2)
        normalized_attrs = attrs.gsub(REGEX_ATTR_NEWLINES, ' ')
                               .gsub(REGEX_ATTR_SPACES, ' ')
                               .rstrip
        "<#{tag}#{normalized_attrs}>"
      end
    end

    # Fix void elements to have proper self-closing syntax
    #
    # Ensures void elements (like <br>, <img>, <input>) have the proper
    # self-closing tag format with trailing slash.
    #
    # @see http://dev.w3.org/html5/spec/syntax.html#void-elements
    #
    # @param out [String] HTML to process
    # @return [String] HTML with fixed void elements
    # @api private
    def fixup_void_elements(out)
      # List of HTML5 void elements (including SVG path, rect)
      void_elements = %w[
        area base br col command embed hr img input keygen link
        meta param source track wbr path rect
      ].join('|')

      # Cache regex (frozen constant would be better but pattern is dynamic)
      @void_elements_regex ||= /<(#{void_elements})([^>]*?)[\/]*>/i

      out.gsub(@void_elements_regex) do
        "<#{Regexp.last_match(1)}#{Regexp.last_match(2)}/>"
      end
    end

    # Process inline <script> tags
    #
    # Minifies JavaScript within <script> tags using Terser.
    #
    # @param out [String] HTML to process
    # @return [String] HTML with minified scripts
    # @api private
    def process_scripts(out)
      out.gsub(REGEX_SCRIPT_TAG) do
        pre = Regexp.last_match(1)
        script_content = Regexp.last_match(2)
        post = Regexp.last_match(3)

        compressed_js = HtmlPress.js_compressor(
          script_content,
          @options[:js_minifier_options],
          @options[:cache]
        )

        "#{pre}#{compressed_js}#{post}"
      end
    end

    # Process inline <style> tags
    #
    # Minifies CSS within <style> tags using YUI Compressor.
    #
    # @param out [String] HTML to process
    # @return [String] HTML with minified styles
    # @api private
    def process_styles(out)
      out.gsub(REGEX_STYLE_TAG) do
        pre = Regexp.last_match(1)
        style_content = Regexp.last_match(2)
        post = Regexp.last_match(3)

        compressed_css = HtmlPress.style_compressor(style_content, @options[:cache])

        "#{pre}#{compressed_css}#{post}"
      end
    end

    # Remove HTML comments (except IE conditional comments)
    #
    # Only removes empty comments (<!-- -->). IE conditional comments
    # like <!--[if IE]> are preserved.
    #
    # @param out [String] HTML to process
    # @return [String] HTML with comments removed
    # @api private
    def process_html_comments(out)
      out.gsub(REGEX_EMPTY_COMMENT, '')
    end

    # Trim leading and trailing whitespace from each line
    #
    # @param out [String] HTML to process
    # @return [String] HTML with trimmed lines
    # @api private
    def trim_lines(out)
      out.gsub(REGEX_LINE_WHITESPACE, '')
    end

    # Remove whitespace outside of block elements
    #
    # Removes unnecessary whitespace around block-level elements while
    # preserving whitespace within inline elements.
    #
    # @param out [String] HTML to process
    # @return [String] HTML with optimized whitespace
    # @api private
    def process_block_elements(out)
      # List of block-level elements
      block_elements = '(?:area|base(?:font)?|blockquote|body|caption|center|cite|' \
                       'col(?:group)?|dd|dir|div|dl|dt|fieldset|form|frame(?:set)?|' \
                       'h[1-6]|head|hr|html|legend|li|link|map|menu|meta|' \
                       'ol|opt(?:group|ion)|p|param|' \
                       't(?:able|body|head|d|h|r|foot|itle)|ul)'

      # Cache the block elements regex
      @block_elements_regex ||= /[ \t]+(<\/?#{block_elements}\b[^>]*>)/

      # Remove whitespace before and after block element tags
      out.gsub!(@block_elements_regex, '\\1')

      # Trim whitespace between elements
      out.gsub!(REGEX_BETWEEN_TAGS) do |match|
        match.gsub(/^[ \t]+|[ \t]+$/, ' ')
      end

      out
    end

    # Replace multiple whitespaces with single space
    #
    # Collapses consecutive whitespace characters (spaces, tabs, newlines)
    # into a single space, except within <code> and <pre> blocks.
    #
    # @param out [String] HTML to process
    # @return [String] HTML with collapsed whitespace
    # @api private
    def process_whitespaces(out)
      # Normalize newlines
      out.gsub!(REGEX_NEWLINES, "\n")

      in_code = 0
      in_pre = 0
      result = []

      out.split("\n").each do |line|
        # Track <code> and <pre> blocks
        line.scan(REGEX_TAG_SCAN) do
          tag = Regexp.last_match(1)
          in_code += 1 if tag == 'code'
          in_code -= 1 if tag == '/code'
          in_pre += 1 if tag == 'pre'
          in_pre -= 1 if tag == '/pre'
        end

        # Collapse whitespace unless in preserved block
        line.gsub!(REGEX_WHITESPACE, ' ') unless in_code > 0 || in_pre > 0
        result << line
      end

      result.join("\n")
    end

    # Log error message if logger is configured
    #
    # @param text [String] Error message to log
    # @api private
    def log(text)
      @options[:logger].error(text) if @options[:logger]
    end
  end
end
