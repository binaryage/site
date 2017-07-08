# frozen_string_literal: true

require_relative 'utils.rb'

# prevents git error message:
# You can't push to git://github.com/darwin/site.git
# Use git@github.com:darwin/site.git
def writable_git_url
  `git remote show origin | grep "Fetch URL:"`.strip =~ /Fetch URL:\s*(.*)/

  if Regexp.last_match(1).nil?
    puts "unable to parse: #{res} (ouput from: git remote show origin | grep \"Fetch URL:\")"
    exit 2
  end

  Regexp.last_match(1).sub('git://', 'git@').sub('github.com/', 'github.com:')
end
