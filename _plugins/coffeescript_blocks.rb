# frozen_string_literal: true

require 'colored2'
require 'coffee-script'
require_relative '_shared'

def render_coffescript_blocks!(item)
  return unless HTML_EXTENSIONS.include?(item.output_ext)

  counter = 0
  re = /(<script.*?>)(.*?)(<.*?\/script>)/m
  item.output.gsub! re do |_|
    pre = Regexp.last_match(1)
    code = Regexp.last_match(2)
    post = Regexp.last_match(3)

    if pre.match?(/coffeescript/)
      counter += 1
      puts "#{'COMPRESS'.magenta} replacing coffeescript block ##{counter} in #{item.path.yellow}\n"
      pre.gsub!('coffeescript', 'javascript')
      begin
        code = CoffeeScript.compile code
      rescue => e
        warn "CoffeeScript error:#{e.message}"
        raise e
      end
    end

    "#{pre}#{code}#{post}"
  end
end
