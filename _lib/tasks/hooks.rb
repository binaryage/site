# frozen_string_literal: true

namespace :hooks do
  desc 'Install git hooks to all submodules'
  task :install do
    template_path = File.join(ROOT, '_lib/hooks/pre-push.template')

    unless File.exist?(template_path)
      die "Hook template not found: #{template_path}"
    end

    puts "Installing pre-push hooks to all submodules..."
    puts

    installed = 0
    failed = 0

    SITES.each do |site|
      site_name = site.name
      hooks_dir = File.join(ROOT, '.git/modules', site.dir.sub("#{ROOT}/", ''), 'hooks')
      hook_path = File.join(hooks_dir, 'pre-push')

      # Check if hooks directory exists
      unless Dir.exist?(hooks_dir)
        puts "  #{'⚠️ '.yellow} #{site_name.yellow} - hooks directory not found, skipping"
        next
      end

      # Copy template to hook location
      begin
        FileUtils.cp(template_path, hook_path)
        FileUtils.chmod(0o755, hook_path) # Make executable

        puts "  #{'✅'.green} #{site_name.yellow} - hook installed"
        installed += 1
      rescue StandardError => e
        puts "  #{'❌'.red} #{site_name.yellow} - failed: #{e.message}"
        failed += 1
      end
    end

    puts
    if installed > 0
      puts "#{'✨'.green} Installed hooks to #{installed} site(s)"
    end
    if failed > 0
      puts "#{'⚠️ '.red} Failed to install #{failed} hook(s)"
      exit 1
    end
  end

  desc 'Uninstall git hooks from all submodules'
  task :uninstall do
    puts "Uninstalling pre-push hooks from all submodules..."
    puts

    removed = 0
    not_found = 0

    SITES.each do |site|
      site_name = site.name
      hooks_dir = File.join(ROOT, '.git/modules', site.dir.sub("#{ROOT}/", ''), 'hooks')
      hook_path = File.join(hooks_dir, 'pre-push')

      if File.exist?(hook_path)
        begin
          FileUtils.rm(hook_path)
          puts "  #{'✅'.green} #{site_name.yellow} - hook removed"
          removed += 1
        rescue StandardError => e
          puts "  #{'❌'.red} #{site_name.yellow} - failed to remove: #{e.message}"
        end
      else
        puts "  #{'○'.blue} #{site_name.yellow} - no hook found"
        not_found += 1
      end
    end

    puts
    if removed > 0
      puts "#{'✨'.green} Removed hooks from #{removed} site(s)"
    end
    if not_found == SITES.size
      puts "#{'ℹ️ '.blue} No hooks were installed"
    end
  end

  desc 'Show git hook installation status for all submodules'
  task :status do
    template_path = File.join(ROOT, '_lib/hooks/pre-push.template')

    puts "Git hook status:"
    puts

    installed = 0
    missing = 0
    outdated = 0

    # Read template content for comparison
    template_content = File.exist?(template_path) ? File.read(template_path) : nil

    SITES.each do |site|
      site_name = site.name
      hooks_dir = File.join(ROOT, '.git/modules', site.dir.sub("#{ROOT}/", ''), 'hooks')
      hook_path = File.join(hooks_dir, 'pre-push')

      if File.exist?(hook_path)
        # Check if hook matches template
        hook_content = File.read(hook_path)
        if template_content && hook_content == template_content
          puts "  #{'✅'.green} #{site_name.yellow} - installed (up to date)"
          installed += 1
        else
          puts "  #{'⚠️ '.yellow} #{site_name.yellow} - installed (outdated or modified)"
          outdated += 1
        end
      else
        puts "  #{'○'.blue} #{site_name.yellow} - not installed"
        missing += 1
      end
    end

    puts
    puts "Summary:"
    puts "  ✅ Installed: #{installed}"
    puts "  ⚠️  Outdated:  #{outdated}" if outdated > 0
    puts "  ○  Missing:   #{missing}" if missing > 0

    if outdated > 0
      puts
      puts "#{'💡'.yellow} Run #{'rake hooks:install'.green} to update outdated hooks"
    elsif missing > 0
      puts
      puts "#{'💡'.blue} Run #{'rake hooks:install'.green} to install hooks"
    end
  end
end
