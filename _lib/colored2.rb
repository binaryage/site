# frozen_string_literal: true

require 'colored2'

# this is here just IntelliJ to understand colors
class String
  def self.blue
    Colored2.blue(self)
  end

  def self.red
    Colored2.red(self)
  end

  def self.yellow
    Colored2.yellow(self)
  end

  def self.green
    Colored2.green(self)
  end

  def self.cyan
    Colored2.cyan(self)
  end

  def self.magenta
    Colored2.magenta(self)
  end

  def self.bold
    Colored2.bold(self)
  end

  def self.underline
    Colored2.underline(self)
  end
end
