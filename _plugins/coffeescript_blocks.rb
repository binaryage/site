require 'colored2'
require 'coffee-script'
require_relative '_shared'

def render_coffescript_blocks!(item)
  unless HTML_EXTENSIONS.include?(item.output_ext)
    return
  end
  counter = 0
  item.output.gsub! /(<script.*?>)(.*?)(<.*?\/script>)/m do |_|
    pre = $1
    code = $2
    post = $3

    if pre =~ /coffeescript/
      counter += 1
      puts "#{'COMPRESS'.magenta} replacing coffeescript block ##{counter} in #{item.path.yellow}\n"
      pre.gsub!('coffeescript', 'javascript')
      begin
        code = CoffeeScript.compile code
      rescue => e
        STDERR.puts 'CoffeeScript error:' + e.message
        raise e
      end
    end

    "#{pre}#{code}#{post}"
  end
end
