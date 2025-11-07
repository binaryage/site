# frozen_string_literal: true

namespace :shared do
  desc 'Manually sync shared submodules (from=www to sync from specific site)'
  task :sync do
    source_name = ENV['from'] || 'www'

    # Find source site
    source_site = SITES.find { |s| s.name == source_name }
    unless source_site
      die "Source site '#{source_name}' not found"
    end

    source_dir = File.join(source_site.dir, 'shared')
    unless Dir.exist?(source_dir)
      die "Source shared directory not found: #{source_dir}"
    end

    # Get source commit
    source_commit = Dir.chdir(source_dir) do
      `git rev-parse HEAD 2>/dev/null`.strip
    end

    if source_commit.empty?
      die "Could not get commit from #{source_name}/shared"
    end

    source_commit_short = source_commit[0..6]
    source_path = File.expand_path(source_dir)

    puts "Syncing from #{"#{source_name}/shared".yellow} (#{source_commit_short.blue})"
    puts

    synced = 0
    skipped = 0
    failed = 0

    SITES.each do |site|
      next if site.name == source_name

      target_dir = File.join(site.dir, 'shared')
      next unless Dir.exist?(target_dir)

      # Check if it's a git repository
      is_git = Dir.chdir(target_dir) do
        system('git rev-parse --git-dir >/dev/null 2>&1')
      end
      next unless is_git

      # Check for uncommitted changes
      has_changes = Dir.chdir(target_dir) do
        !system('git diff --quiet 2>/dev/null') || !system('git diff --cached --quiet 2>/dev/null')
      end

      if has_changes
        puts "  #{'⚠️ '.yellow} #{site.name.yellow}/shared - has uncommitted changes, skipping"
        skipped += 1
        next
      end

      # Perform sync
      success = Dir.chdir(target_dir) do
        # Fetch from source
        system("git fetch '#{source_path}' HEAD >/dev/null 2>&1") &&
        # Update HEAD ref
        system("git update-ref HEAD #{source_commit}") &&
        # Reset working tree
        system("git reset --hard HEAD >/dev/null 2>&1")
      end

      if success
        # Verify
        actual_commit = Dir.chdir(target_dir) do
          `git rev-parse --short HEAD`.strip
        end
        puts "  #{'✅'.green} #{site.name.yellow}/shared → #{actual_commit.blue}"
        synced += 1
      else
        puts "  #{'❌'.red} #{site.name.yellow}/shared - sync failed"
        failed += 1
      end
    end

    puts
    if synced > 0
      puts "#{'✨'.green} Synced #{synced} site(s)"
    end
    if skipped > 0
      puts "#{'⏭️ '.yellow} Skipped #{skipped} site(s) with uncommitted changes"
    end
    if failed > 0
      puts "#{'⚠️ '.red} Failed to sync #{failed} site(s)"
      exit 1
    end
  end
end
