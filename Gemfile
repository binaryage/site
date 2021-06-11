# frozen_string_literal: true

source 'http://rubygems.org'

gem 'closure-compiler'
gem 'coffee-script'
gem 'colored2'
# we mention explicit ref to fight "bundle install" caching logic (affects hookgun not picking up latest version)
# => https://stackoverflow.com/a/13851020/84283
gem 'html_press', git: 'https://github.com/binaryage/html_press', ref: '96bf0b6db25aaf224da1d8b6620553c69fb069fb'
gem 'jekyll'
gem 'stylus'
gem 'tilt'
gem 'yui-compressor'
gem 'webrick'

group :jekyll_plugins do
  gem 'jekyll-coffeescript'
  gem 'jekyll-contentblocks'
  gem 'jekyll-redirect-from'
end
