# frozen_string_literal: true

require 'colored2'

# colored2 gem provides standard ANSI colors via instance methods:
# "text".red, "text".green, "text".blue, "text".bold, etc.
#
# We only extend it with a custom gray color, which the gem doesn't provide.
class String
  # Custom gray color (bright black / dark gray)
  def gray
    "\033[90m#{self}\033[0m"
  end
end
