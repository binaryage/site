module Jekyll
  require 'coffee-script'

  class CoffeeScriptConverter < Converter
    safe true
    priority :normal

    def matches(ext)
      ext =~ /\.coffee$/i
    end

    def output_ext(ext)
      ".js"
    end

    def convert(content)
      begin
        CoffeeScript.compile content
      rescue StandardError => e
        STDERR.puts "CoffeeScript error:" + e.message
        raise FatalException.new("CoffeeScript error: #{e.message}")
      end
    end
  end

end