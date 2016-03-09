require "rubygems"
require "jekyll-contentblocks"

module Jekyll
  module Tags
    class FirstContentBlock < Liquid::Tag
      include ::Jekyll::ContentBlocks::ContentBlockTag

      def render(context)
        block_content = content_for_block(context)[0] # take only the first one
        return '' unless block_content
        if convert_content?
          converted_content(block_content, context)
        else
          block_content
        end
      end

      private

      def convert_content?
        !content_block_options.include?('no-convert')
      end

      def converted_content(block_content, context)
        converters = context.environments.first['converters']
        Array(converters).reduce(block_content) do |content, converter|
          converter.convert(content)
        end
      end
    end
  end
end

Liquid::Template.register_tag('firstcontentblock', Jekyll::Tags::FirstContentBlock)