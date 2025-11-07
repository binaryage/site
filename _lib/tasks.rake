# frozen_string_literal: true

# Load configuration first (contains constants and SITES array)
require_relative 'tasks/config'

# Load all task definitions
Dir[File.join(__dir__, 'tasks', '*.rb')].sort.each do |file|
  next if File.basename(file) == 'config.rb' # Already loaded
  require file
end

# Default task
task default: :serve
