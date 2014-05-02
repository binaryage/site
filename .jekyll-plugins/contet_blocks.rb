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
        converter = context.environments.first['converter']
        first_block = content_for_block(context)[0]
        return '' unless first_block
        converter.convert(first_block || '')
      end
    end
  end
end

Liquid::Template.register_tag('firstcontentblock', Jekyll::Tags::FirstContentBlock)