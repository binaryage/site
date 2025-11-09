# frozen_string_literal: true

namespace :remotes do
  desc 'Fix remote URLs to use SSH format (git@github.com:binaryage/REPO.git)'
  task :ssh do
    puts "#{'=== Fixing Remote URLs to SSH ==='.cyan.bold}\n\n"

    updated = 0
    already_ssh = 0
    failed = 0

    SITES.each do |site|
      unless File.directory?(site.dir)
        puts "  #{'⏭️'.yellow} #{site.name.yellow} - directory missing, skipping"
        next
      end

      # Check if it's a git repository
      is_git = Dir.chdir(site.dir) do
        system('git rev-parse --git-dir >/dev/null 2>&1')
      end
      unless is_git
        puts "  #{'⏭️'.yellow} #{site.name.yellow} - not a git repository, skipping"
        next
      end

      # Get current origin URL
      current_url = Dir.chdir(site.dir) do
        `git remote get-url origin 2>/dev/null`.strip
      end

      if current_url.empty?
        puts "  #{'⏭️'.yellow} #{site.name.yellow} - no origin remote found, skipping"
        next
      end

      # Extract repo name from current URL
      repo_name = if current_url.match(%r{github\.com[:/]binaryage/([^/.]+)})
                    Regexp.last_match(1)
                  else
                    site.name
                  end

      ssh_url = "git@github.com:binaryage/#{repo_name}.git"

      # Check if already SSH
      if current_url.start_with?('git@github.com:')
        puts "  #{'✓'.green} #{site.name.yellow} - already SSH"
        already_ssh += 1
        next
      end

      # Update to SSH
      success = Dir.chdir(site.dir) do
        system("git remote set-url origin '#{ssh_url}' 2>/dev/null")
      end

      if success
        puts "  #{'✅'.green} #{site.name.yellow} - updated to SSH"
        puts "       #{current_url.gray}"
        puts "       → #{ssh_url.blue}"
        updated += 1
      else
        puts "  #{'❌'.red} #{site.name.yellow} - failed to update"
        failed += 1
      end
    end

    puts
    if updated > 0
      puts "#{'✨'.green} Updated #{updated} site(s) to SSH"
    end
    if already_ssh > 0
      puts "#{'✓'.green} #{already_ssh} site(s) already using SSH"
    end
    if failed > 0
      puts "#{'⚠️'.red} Failed to update #{failed} site(s)"
      exit 1
    end
  end

  desc 'Show current remote URLs for all sites'
  task :list do
    puts "#{'=== Remote URLs ==='.cyan.bold}\n\n"

    SITES.each do |site|
      unless File.directory?(site.dir)
        next
      end

      is_git = Dir.chdir(site.dir) do
        system('git rev-parse --git-dir >/dev/null 2>&1')
      end
      unless is_git
        next
      end

      url = Dir.chdir(site.dir) do
        `git remote get-url origin 2>/dev/null`.strip
      end

      if url.empty?
        puts "  #{site.name.yellow}: #{'no origin remote'.red}"
      elsif url.start_with?('git@github.com:')
        puts "  #{site.name.yellow}: #{url.green} #{'(SSH)'.gray}"
      else
        puts "  #{site.name.yellow}: #{url.yellow} #{'(HTTPS)'.gray}"
      end
    end
  end
end
