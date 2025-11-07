# frozen_string_literal: true

# this script is responsible for registering our plugins in correct order

# Load html_press library before plugins
require_relative '../_lib/html_press'

require_relative 'compressor'
require_relative 'reshaper'
require_relative 'pruner'
require_relative 'cname_generator'

require_relative 'inline_styles'
require_relative 'firstcontentblock'

# -- liquid tags ------------------------------------------------------------------------------------------------------------

Liquid::Template.register_tag('inline_styles', Jekyll::Tags::InlineStyles)
Liquid::Template.register_tag('firstcontentblock', Jekyll::Tags::FirstContentBlock)

# -- hooks ------------------------------------------------------------------------------------------------------------------

Jekyll::Hooks.register(%i[documents pages], :post_render) do |item|
  press_html!(item.site, item)
end

Jekyll::Hooks.register(:site, :post_render) do |site|
  remove_unwanted_content!(site)
end

Jekyll::Hooks.register(:site, :post_write) do |site|
  generate_cname_file!(site)
end

Jekyll::Hooks.register(:site, :post_write) do |site|
  remove_unwanted_files!(site)
end
