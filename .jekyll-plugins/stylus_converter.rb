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

    def setup
      return if @setup
      @setup = true
      require 'stylus'
      Stylus.compress = @config['stylus']['compress'] if @config['stylus']['compress']
      Stylus.paths << @config['stylus']['path'] if @config['stylus']['path']
      Stylus.debug = @config['stylus']['debug'] if @config['stylus']['debug']
    rescue LoadError
      STDERR.puts $!
      STDERR.puts 'You are missing a library required for Stylus. Please run:'
      STDERR.puts '  $ [sudo] gem install stylus'
      raise FatalException.new('Missing dependency: stylus')
    end

    def matches(ext)
      ext =~ /styl/i
    end

    def output_ext(ext)
      '.css'
    end

    def convert(content)
      begin
        setup
        Dir.chdir File.dirname(Stylus.paths[0]) do
          Stylus.compile content
        end
      rescue => e
        puts "Stylus Exception: #{e.message}"
        exit 233
      end
    end
  end
end