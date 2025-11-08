# frozen_string_literal: true

# A Jekyll plugin to concatenate CSS files via @import statements
# Replaces the Stylus converter for simple CSS concatenation

require 'pathname'

module Jekyll
  class CssConcatenator < Converter
    safe true
    priority :low

    def initialize(config)
      super
      @site_source = nil
    end

    def matches(ext)
      ext =~ /\.styl$/i
    end

    def output_ext(_ext)
      '.css'
    end

    def convert(content)
      # Jekyll runs with CWD set to the website directory (www, blog, etc.)
      # CSS files are in shared/css/ relative to the website root
      base_dir = 'shared/css'

      result = []

      content.each_line do |line|
        # Skip YAML front matter
        next if line.strip == '---'

        # Process @import statements
        if line =~ /@import\s+["']([^"']+)["']/
          import_file = $1
          import_path = File.join(base_dir, import_file)

          if File.exist?(import_path)
            imported_content = File.read(import_path)
            result << imported_content
          else
            warn "CSS Concatenator: Could not find #{import_path}"
          end
        elsif line =~ /^\/\//
          # Skip comments
          next
        else
          # Keep other lines (comments, etc.)
          result << line unless line.strip.empty?
        end
      end

      result.join("\n")
    rescue => e
      puts "CSS Concatenator Exception: #{e.message}"
      puts e.backtrace
      raise e
    end
  end
end
