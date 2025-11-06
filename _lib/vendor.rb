# frozen_string_literal: true

# Load vendored libraries
# This file adds the vendor directory to the Ruby load path and requires vendored gems

# Add html_press vendor directory to load path
html_press_path = File.expand_path('../vendor/html_press', __FILE__)
$LOAD_PATH.unshift(html_press_path) unless $LOAD_PATH.include?(html_press_path)

# Require vendored libraries
require 'html_press'
