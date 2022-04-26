# frozen_string_literal: true

require 'jekyll-contentblocks'

module Jekyll
  module Tags
    class InlineStyles < Liquid::Tag
      include ::Jekyll::ContentBlocks::ContentBlockTag

      def render(context)
        @content_block_name = 'inline_styles'
        content = content_for_block(context)
        return '' if !content || content.empty?

        texts = ['<style>']
        content.each do |block|
          texts << block
        end
        texts << '</style>'
        texts.join
      end
    end
  end
end
