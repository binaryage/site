require_relative './utils.rb'

# prevents git error message:
# You can't push to git://github.com/darwin/site.git
# Use git@github.com:darwin/site.git
def get_writable_git_url
  `git remote show origin | grep "Fetch URL:"`.strip =~ /Fetch URL:\s*(.*)/

  if $1.nil?
    puts "unable to parse: #{res} (ouput from: git remote show origin | grep \"Fetch URL:\")"
    exit 2
  end

  $1.sub('git://', 'git@').sub('github.com/', 'github.com:')
end
