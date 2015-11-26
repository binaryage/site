require "rubygems"
require "jekyll-contentblocks"
require 'pp'

module Jekyll
  module Tags
    class FirstContentBlock < Liquid::Tag
      include ::Jekyll::ContentBlocks::ContentBlockTag

      def render(context)
        block_content = content_for_block(context)[0] # take only first one
        return '' unless block_content
        converters = context.environments.first['converters']
        converters.reduce(block_content) do |content, converter|
          converter.convert(content)
        end
      end
    end
  end
end

Liquid::Template.register_tag('firstcontentblock', Jekyll::Tags::FirstContentBlock)