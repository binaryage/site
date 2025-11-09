# frozen_string_literal: true

namespace :upgrade do
  desc 'upgrade Ruby dependencies'
  task :ruby do
    sys('bundle update')
  end

  desc 'upgrade Node dependencies'
  task :node do
    # Different package managers use different upgrade commands
    upgrade_cmd = case NODE_PKG_MANAGER
                  when 'npm'
                    'npm update'
                  when 'yarn'
                    'yarn upgrade'
                  when 'bun'
                    'bun update'
                  else
                    "#{NODE_PKG_MANAGER} update"
                  end

    Dir.chdir NODE_DIR do
      sys(upgrade_cmd)
    end
  end
end

desc "upgrade dependencies (via Ruby's bundler and Node's #{NODE_PKG_MANAGER})"
task upgrade: ['upgrade:ruby', 'upgrade:node']
