require "rubygems"
require "jekyll-contentblocks"
require 'pp'

module Jekyll
  module Tags
    class InlineStyles < Liquid::Tag
      include ::Jekyll::ContentBlocks::Common

      def initialize(tag_name, block_name, tokens)
        super
        @block_name = get_content_block_name(tag_name, "inline_styles")
      end

      def render(context)
        content = content_for_block(context)
        return '' if not content or content.size==0
        texts = ['<style>']
        content.each do |block|
          texts << block
        end
        texts << '</style>'
        texts.join("")
      end
    end
  end
end

Liquid::Template.register_tag('inline_styles', Jekyll::Tags::InlineStyles)