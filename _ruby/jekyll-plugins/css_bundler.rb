# frozen_string_literal: true

# A Jekyll plugin to process CSS bundle entry files via lightningcss
# Processes files with .bundle.css extension
#
# Features:
# - Transforms CSS nesting to flat CSS for browser compatibility
# - Processes @import statements via --bundle flag
# - Optional minification (controlled by site.dev config)

require 'pathname'
require 'tempfile'
require 'open3'
require 'fileutils'

module Jekyll
  module CssBundler
    # Hook runs after site is written to destination
    Jekyll::Hooks.register :site, :post_write do |site|
      process_css_bundles(site)
    end

    def self.process_css_bundles(site)
      # Jekyll runs with CWD set to the website directory (www, blog, etc.)
      source_dir = site.source
      dest_dir = site.dest

      # Find all .bundle.css files in source
      bundle_files = Dir.glob(File.join(source_dir, '**', '*.bundle.css'))

      bundle_files.each do |source_path|
        process_bundle_file(source_path, source_dir, dest_dir, site.config)
      end
    end

    def self.process_bundle_file(source_path, source_dir, dest_dir, config)
      # Get relative path from source
      relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(source_dir)).to_s

      # Determine output paths
      # .bundle.css → .css
      output_relative_path = relative_path.sub(/\.bundle\.css$/, '.css')
      output_path = File.join(dest_dir, output_relative_path)
      bundle_dest_path = File.join(dest_dir, relative_path)

      # Create temp file for result
      result_file = Tempfile.new(['result', '.css'])

      begin

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
        minify_flag = config['dev'] ? '' : '--minify'

        cmd = "#{lightningcss_bin} #{minify_flag} --bundle --targets '>= 0.25%' #{source_path} -o #{result_file.path}"

        # Execute lightningcss
        _stdout, stderr, status = Open3.capture3(cmd)

        unless status.success?
          error_msg = "CSS Bundler (lightningcss) failed for #{relative_path}\n"
          error_msg += "Command: #{cmd}\n"
          error_msg += "Error output:\n#{stderr}" unless stderr.empty?
          raise error_msg
        end

        # Write output to destination
        FileUtils.mkdir_p(File.dirname(output_path))
        FileUtils.cp(result_file.path, output_path)

        # Remove .bundle.css from destination if it was copied there
        FileUtils.rm_f(bundle_dest_path) if File.exist?(bundle_dest_path)

        puts "  CSS Bundle: #{relative_path} → #{output_relative_path}".colorize(:magenta)
      ensure
        result_file&.unlink
      end
    rescue => e
      puts "CSS Bundler Exception: #{e.message}"
      puts e.backtrace
      raise e
    end
  end
end
