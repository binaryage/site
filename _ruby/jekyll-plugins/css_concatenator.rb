# frozen_string_literal: true

# A Jekyll plugin to process CSS files via lightningcss
# Replaces the Stylus converter for CSS transformation and bundling
#
# Features:
# - Transforms CSS nesting to flat CSS for browser compatibility
# - Processes @import statements
# - Optional minification (controlled by site.dev config)

require 'pathname'
require 'tempfile'
require 'open3'

module Jekyll
  class CssConcatenator < Converter
    safe true
    priority :low

    def initialize(config)
      super
      @config = config
    end

    def matches(ext)
      ext =~ /\.styl$/i
    end

    def output_ext(_ext)
      '.css'
    end

    def convert(content)
      # Jekyll runs with CWD set to the website directory (www, blog, etc.)
      # Remove YAML front matter and create temp file in shared/css/ for @import resolution
      css_content = content.lines.reject { |line| line.strip == '---' }.join

      # Create temp file in shared/css/ directory so lightningcss can resolve @import
      source_file = Tempfile.new(['site', '.css'], 'shared/css')
      result_file = Tempfile.new(['result', '.css'])

      begin
        source_file.write(css_content)
        source_file.close

        # Get path to lightningcss binary
        root = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
        lightningcss_bin = File.join(root, '_node/node_modules/.bin/lightningcss')

        unless File.exist?(lightningcss_bin)
          raise "Lightning CSS binary not found at: #{lightningcss_bin}\n" \
                "Run 'rake init' to install dependencies."
        end

        # Build lightningcss command
        # --bundle: resolves @import statements (relative to source file)
        # --targets: browser compatibility (transforms nesting)
        # --minify: only in production (when dev mode is false)
        minify_flag = @config['dev'] ? '' : '--minify'

        cmd = "#{lightningcss_bin} #{minify_flag} --bundle --targets '>= 0.25%' #{source_file.path} -o #{result_file.path}"

        # Execute lightningcss
        _stdout, stderr, status = Open3.capture3(cmd)

        unless status.success?
          error_msg = "CSS Concatenator (lightningcss) failed.\n"
          error_msg += "Command: #{cmd}\n"
          error_msg += "Error output:\n#{stderr}" unless stderr.empty?
          raise error_msg
        end

        File.read(result_file.path)
      ensure
        source_file&.unlink
        result_file&.unlink
      end
    rescue => e
      puts "CSS Concatenator Exception: #{e.message}"
      puts e.backtrace
      raise e
    end
  end
end
