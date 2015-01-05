require "rubygems"
require "jekyll-contentblocks"
require 'pp'

module Jekyll
  module Tags
    class FirstContentBlock < Liquid::Tag
      include ::Jekyll::ContentBlocks::Common

      def initialize(tag_name, block_name, tokens)
        super
        @block_name = get_content_block_name(tag_name, block_name)
      end

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