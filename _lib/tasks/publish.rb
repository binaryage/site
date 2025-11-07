# frozen_string_literal: true

desc 'publish all dirty sites, use force=1 to force publishing of all'
task :publish do
  opts = {
    force: ENV['force'] == '1',
    dont_push: ENV['dont_push'] == '1'
  }
  publish_workspace(SITES, opts)
end
