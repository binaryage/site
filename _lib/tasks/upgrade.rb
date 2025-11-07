# frozen_string_literal: true

namespace :upgrade do
  desc 'upgrade Ruby dependencies'
  task :ruby do
    sys('bundle update')
  end

  desc 'upgrade Node dependencies'
  task :node do
    Dir.chdir NODE_DIR do
      sys('yarn upgrade')
    end
  end
end

desc 'upgrade dependencies (via Ruby\'s bundler and Node\'s yarn)'
task upgrade: ['upgrade:ruby', 'upgrade:node']
