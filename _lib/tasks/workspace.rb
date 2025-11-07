# frozen_string_literal: true

desc 'clean stage'
task :clean do
  sys("rm -rf \"#{SERVE_DIR}\"")
  sys("rm -rf \"#{STAGE_DIR}\"")
end

desc 'reset workspace to match remote changes - this will destroy your local changes!!!'
task reset: [:clean] do
  reset_workspace(SITES)
end

desc 'pin submodules to point to latest branch tips'
task :pin do
  puts "note: #{'to get remote changes'.green} you have to do #{'git fetch'.blue} first"
  pin_workspace(SITES)
end

# Helper method to check shared submodule status
def check_shared_submodule(shared_path, verbose)
  issues = 0

  unless File.exist?(File.join(shared_path, '.git'))
    puts "  #{'✗'.red}  shared/ #{'Not initialized as git submodule'.red}"
    return 1
  end

  Dir.chdir(shared_path) do
    # Get current branch
    branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
    branch = 'DETACHED' if branch.empty?

    # Get current commit hash (short)
    commit = `git rev-parse --short HEAD 2>/dev/null`.strip
    commit = 'UNKNOWN' if commit.empty?

    # Check if on expected branch (should be 'master' for shared)
    has_shared_issues = false
    if branch != 'master'
      has_shared_issues = true
      issues += 1
    end

    # Check working directory status
    status_output = `git status --porcelain 2>/dev/null`.strip
    is_dirty = !status_output.empty?
    if is_dirty
      has_shared_issues = true
      issues += 1
    end

    # Check ahead/behind status
    ahead_behind_parts = []
    if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
      ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
      behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

      if ahead > 0
        ahead_behind_parts << "↑#{ahead}".green + ' '
        has_shared_issues = true
      end
      if behind > 0
        ahead_behind_parts << "↓#{behind}".red + ' '
        has_shared_issues = true
      end
    end

    # Print shared status
    shared_icon = has_shared_issues ? '●'.yellow : '✓'.green
    branch_display = branch != 'master' ? branch.yellow : branch

    puts "  #{shared_icon} shared/ [#{branch_display} @ #{commit}]"

    if verbose || has_shared_issues
      puts "     #{'⚠'.yellow}  Working directory has uncommitted changes" if is_dirty
    end

    # Always show ahead/behind if present (even in non-verbose mode)
    unless ahead_behind_parts.empty?
      puts "     #{'↔'.blue}  Remote: #{ahead_behind_parts.join('')}"
    end
  end

  issues
end

desc 'check status of all git submodules and their shared submodules (verbose=1 for details)'
task :status do
  verbose = ENV['verbose'] == '1'

  # Counters for summary
  total_submodules = SITES.length
  clean_count = 0
  dirty_count = 0
  ahead_count = 0
  behind_count = 0
  wrong_branch_count = 0
  shared_issues = 0

  puts "#{'=== Git Submodules Status ==='.cyan.bold}\n\n"

  # Check each submodule
  SITES.each do |site|
    has_issues = false

    # Check if submodule directory exists
    unless File.directory?(site.dir)
      puts "#{'✗'.red} #{site.name.bold} - #{'MISSING'.red}"
      dirty_count += 1
      next
    end

    Dir.chdir(site.dir) do
      # Get current branch
      branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      branch = 'DETACHED' if branch.empty?

      # Check if on expected branch (should be 'web' for main submodules)
      branch_display = if branch != 'web'
                         has_issues = true
                         wrong_branch_count += 1
                         "#{branch.yellow} #{'(expected: web)'.gray}"
                       else
                         branch.green
                       end

      # Check working directory status
      status_output = `git status --porcelain 2>/dev/null`.strip
      is_dirty = !status_output.empty?
      if is_dirty
        has_issues = true
        dirty_count += 1
      end

      # Check ahead/behind status
      ahead_behind_parts = []
      if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
        ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
        behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

        if ahead > 0
          ahead_behind_parts << "↑#{ahead}".green
          ahead_count += 1
        end
        if behind > 0
          ahead_behind_parts << "↓#{behind}".red
          has_issues = true
          behind_count += 1
        end
      end

      # Print main status line
      status_icon = has_issues ? '●'.yellow : '✓'.green
      clean_count += 1 unless has_issues

      puts "#{status_icon} #{site.name.bold} [#{branch_display}]"

      # Show details if verbose or if there are issues
      if verbose || has_issues
        puts "  #{'⚠'.yellow}  Working directory has uncommitted changes" if is_dirty
      end

      # Always show ahead/behind if present (even in non-verbose mode)
      unless ahead_behind_parts.empty?
        puts "  #{'↔'.blue}  Remote: #{ahead_behind_parts.join('')}"
      end

      # Check shared submodule
      shared_dir = File.join(site.dir, 'shared')
      if Dir.exist?(shared_dir)
        shared_issues += check_shared_submodule(shared_dir, verbose)
      else
        puts "  #{'✗'.red}  #{'shared/ directory missing'.red}"
        shared_issues += 1
      end

      puts
    end
  end

  # Print summary
  puts "#{'=== Summary ==='.cyan.bold}"
  puts "Total submodules:     #{total_submodules.to_s.bold}"
  puts "Clean:                #{clean_count.to_s.green}"
  puts "With local changes:   #{dirty_count.to_s.yellow}"
  puts "Ahead of remote:      #{ahead_count.to_s.green}"
  puts "Behind remote:        #{behind_count.to_s.red}"
  puts "Wrong branch:         #{wrong_branch_count.to_s.yellow}" if wrong_branch_count > 0
  puts "Shared/ issues:       #{shared_issues.to_s.yellow}" if shared_issues > 0

  # Exit code based on issues
  exit 1 if behind_count > 0 || shared_issues > 0
end
