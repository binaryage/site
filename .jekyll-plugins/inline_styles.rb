require "rubygems"
require "jekyll-contentblocks"
require 'pp'

module Jekyll
  module Tags
    class InlineStyles < Liquid::Tag
      include ::Jekyll::ContentBlocks::ContentBlockTag

      def render(context)
        @content_block_name = "inline_styles"
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