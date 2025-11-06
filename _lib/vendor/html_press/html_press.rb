# frozen_string_literal: true

require 'html_press/version'
require 'html_press/css_press'
require 'html_press/uglifier'
require 'html_press/html'

# HtmlPress - HTML compression library
#
# This library compresses HTML by:
# - Removing unnecessary whitespace
# - Removing HTML comments (except IE conditional comments)
# - Minifying inline JavaScript via Uglifier
# - Minifying inline CSS via YUI Compressor
# - Preserving content in <code> and <pre> blocks
# - Re-indenting output for readability
#
# @example Basic usage
#   html = "<html>\n  <body>  <p>Hello</p>  </body>\n</html>"
#   compressed = HtmlPress.press(html)
#   # => "<html>\n  <body>\n    <p>Hello</p>\n  </body>\n</html>"
#
# @example With options
#   HtmlPress.press(html,
#     unquoted_attributes: true,
#     drop_empty_values: true,
#     js_minifier_options: { compress: { unused: false } },
#     cache: '/tmp/cache'
#   )
module HtmlPress
  # Compress HTML content
  #
  # @param text [String, IO] HTML content to compress
  # @param options [Hash] Compression options
  # @option options [Logger, nil] :logger Logger instance for error reporting
  # @option options [Boolean] :unquoted_attributes Remove quotes from HTML attributes
  # @option options [Boolean] :drop_empty_values Drop empty attribute values
  # @option options [Boolean] :strip_crlf Strip CRLF characters
  # @option options [Hash, nil] :js_minifier_options Options passed to Uglifier
  # @option options [String, nil] :cache Directory path for caching compressed JS/CSS
  #
  # @return [String] Compressed HTML
  #
  # @example
  #   HtmlPress.press("<html>\n  <body>Hello</body>\n</html>")
  #   # => "<html>\n  <body>Hello</body>\n</html>"
  def self.press(text, options = {})
    HtmlPress::Html.new(options).press(text)
  end

  # Compress HTML content (backward compatibility alias)
  #
  # @deprecated Use {.press} instead
  # @param text [String, IO] HTML content to compress
  # @param options [Hash] Compression options (see {.press})
  # @return [String] Compressed HTML
  def self.compress(text, options = {})
    HtmlPress::Html.new(options).press(text)
  end
end
