# frozen_string_literal: true

# A Jekyll plugin to convert .styl to .css
# This plugin requires the stylus gem, do:
# $ [sudo] gem install stylus

# See _config.yml for configuration options.

# Caveats:
# 1. Files intended for conversion must have empty YAML front matter a the top.
#    See site.styl above.
# 2. You must not @import .styl files intended to be converted.
#    See site.styl and individual.styl above.

module Jekyll
  class StylusConverter < Converter
    safe true

    def stylus_config(key)
      @config['stylus'][key]
    end

    def setup_if_needed!
      return if @setup_done
      @setup_done = true
      require 'stylus'
      Stylus.compress = stylus_config('compress') if stylus_config('compress')
      Stylus.paths << stylus_config('path') if stylus_config('path')
      Stylus.debug = stylus_config('debug') if stylus_config('debug')
      # noinspection RubyStringKeysInHashInspection
      @options = {
        'include css' => true # we want to inline css files into one, see https://github.com/LearnBoost/stylus/issues/448
      }
    rescue => e
      STDERR.puts $ERROR_INFO
      STDERR.puts 'You are missing a library required for Stylus. Please run:'
      STDERR.puts '  $ [sudo] gem install stylus'
      raise e
    end

    def matches(ext)
      ext =~ /\.styl$/i
    end

    def output_ext(_ext)
      '.css'
    end

    def convert(content)
      setup_if_needed!
      Dir.chdir File.dirname(Stylus.paths[0]) do
        Stylus.compile content, @options
      end
    rescue => e
      puts "Stylus Exception: #{e.message}"
      raise e
    end
  end
end
