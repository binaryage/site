require 'colored2'
require_relative './compressor.rb' # blocks replacement must be applied before compression

module Jekyll
  require 'coffee-script'

  # noinspection RubyResolve
  class Page
    alias_method :csblock_orig_write, :write

    def write(dest)
      if self.html?
        counter = 0
        self.output.gsub! /(<script.*?>)(.*?)(<.*?\/script>)/m do |_|
          pre = $1
          code = $2
          post = $3

          if pre =~ /coffeescript/
            counter += 1
            puts "#{'COMPRESS'.magenta} replacing coffeescript block ##{counter} in #{destination(dest).yellow}\n"
            pre.gsub!('coffeescript', 'javascript')
            begin
              code = CoffeeScript.compile code
            rescue StandardError => e
              STDERR.puts 'CoffeeScript error:' + e.message
              raise FatalException.new("CoffeeScript error: #{e.message}")
            end
          end

          "#{pre}#{code}#{post}"
        end
      end
      csblock_orig_write(dest)
    end
  end

end
