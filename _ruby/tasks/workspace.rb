# frozen_string_literal: true

# Helper to strip ANSI color codes for length calculation
def strip_ansi(str)
  str.gsub(/\e\[\d+m/, '')
end

desc 'clean stage'
task :clean do
  sys("rm -rf \"#{SERVE_DIR}\"")
  sys("rm -rf \"#{STAGE_DIR}\"")
end

desc 'force invalidate and clean all caches (build, serve, jekyll)'
task 'clean:cache' do
  require_relative '../cache_version'
  deleted = CacheVersion.invalidate_all_caches
  if deleted.empty?
    puts 'ℹ️  No cache directories found'
  else
    dir_word = deleted.length == 1 ? 'directory' : 'directories'
    puts "✅ Cleaned #{deleted.length} cache #{dir_word}"
    deleted.each { |dir| puts "   🗑️  #{dir.sub("#{ROOT}/", '')}" }
  end
end

desc 'Pin submodules to branch tips (use after git fetch or submodule update to fix detached HEAD)'
task :pin do
  puts "note: #{'to get remote changes'.green} you have to do #{'git fetch'.blue} first"
  pin_workspace(SITES)
end

# Helper method to get shared submodule status data
def get_shared_submodule_status(shared_path)
  unless File.exist?(File.join(shared_path, '.git'))
    return {
      error: true,
      icon: '✗'.red,
      branch: 'NOT_INITIALIZED',
      commit: '',
      issues: 1,
      symbols: []
    }
  end

  issues = 0
  symbols = []

  Dir.chdir(shared_path) do
    # Get current branch
    branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
    branch = 'DETACHED' if branch.empty?

    # Get current commit hash (short, 7 chars)
    commit = `git rev-parse --short=7 HEAD 2>/dev/null`.strip
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
      symbols << '⚠'.yellow
    end

    # Check ahead/behind status
    ahead = 0
    behind = 0
    if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
      ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
      behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

      if ahead.positive?
        symbols << "↑#{ahead}".green
        has_shared_issues = true
      end
      if behind.positive?
        symbols << "↓#{behind}".red
        has_shared_issues = true
      end
    end

    # Prepare return data
    shared_icon = has_shared_issues ? '●'.yellow : '✓'.green
    branch_display = branch == 'master' ? branch : branch.yellow

    return {
      error: false,
      icon: shared_icon,
      branch: branch_display,
      raw_branch: branch,
      commit: commit,
      issues: issues,
      symbols: symbols,
      is_dirty: is_dirty,
      has_issues: has_shared_issues,
      ahead: ahead,
      behind: behind
    }
  end
end

# Helper method to check shared submodule status (for verbose mode)
def check_shared_submodule(shared_path, verbose)
  status = get_shared_submodule_status(shared_path)

  if status[:error]
    puts "  #{status[:icon]}  shared/ #{'Not initialized as git submodule'.red}"
    return status[:issues]
  end

  puts "  #{status[:icon]} shared/ [#{status[:branch]} @ #{status[:commit]}]"

  if (verbose || status[:has_issues]) && status[:is_dirty]
    puts "     #{'⚠'.yellow}  Working directory has uncommitted changes"
  end

  # Always show ahead/behind if present (even in non-verbose mode)
  unless status[:symbols].empty?
    remote_parts = status[:symbols].select { |s| s.include?('↑') || s.include?('↓') }
    puts "     #{'↔'.blue}  Remote: #{remote_parts.join(' ')}" unless remote_parts.empty?
  end

  status[:issues]
end

desc 'check status of all git submodules and their shared submodules (verbose=1 for details)'
task :status do
  verbose = ENV['verbose'] == '1'

  # Counters for summary
  total_submodules = SITES.length
  clean_count = 0
  dirty_count = 0
  shared_pointer_only_count = 0
  ahead_count = 0
  behind_count = 0
  wrong_branch_count = 0

  # Detailed shared counters
  shared_dirty_count = 0
  shared_wrong_branch_count = 0
  shared_ahead_count = 0
  shared_behind_count = 0

  puts "#{'=== Git Submodules Status ==='.cyan.bold}\n\n"

  # Calculate max site name length for alignment
  max_name_len = SITES.map { |s| s.name.length }.max

  # Check each submodule
  SITES.each do |site|
    has_issues = false

    # Check if submodule directory exists
    unless File.directory?(site.dir)
      if verbose
        puts "#{'✗'.red} #{site.name.bold} - #{'MISSING'.red}"
        puts
      else
        puts "#{'✗'.red} #{site.name.ljust(max_name_len)} [#{'MISSING'.red}]"
      end
      dirty_count += 1
      next
    end

    Dir.chdir(site.dir) do
      # Get current branch
      branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      branch = 'DETACHED' if branch.empty?

      # Check if on expected branch (should be 'web' for main submodules)
      branch_display = if branch == 'web'
                         branch.green
                       else
                         has_issues = true
                         wrong_branch_count += 1
                         "#{branch.yellow} #{'(expected: web)'.gray}"
                       end

      # For compact display, simpler branch display
      branch_compact = branch == 'web' ? branch : branch.yellow

      # Check working directory status
      status_output = `git status --porcelain 2>/dev/null`.strip
      is_dirty = !status_output.empty?

      # Detect if only shared submodule pointer changed (normal after rake shared:sync)
      status_lines = status_output.lines
      is_only_shared_pointer = status_lines.length == 1 && status_lines[0].strip == 'M shared'

      if is_dirty
        if is_only_shared_pointer
          shared_pointer_only_count += 1
        else
          has_issues = true
          dirty_count += 1
        end
      end

      # Check ahead/behind status
      site_symbols = []
      ahead_behind_parts = []
      if system("git rev-parse --verify origin/#{branch} >/dev/null 2>&1")
        ahead = `git rev-list --count origin/#{branch}..HEAD 2>/dev/null`.strip.to_i
        behind = `git rev-list --count HEAD..origin/#{branch} 2>/dev/null`.strip.to_i

        if ahead.positive?
          ahead_behind_parts << "↑#{ahead}".green
          site_symbols << "↑#{ahead}".green
          ahead_count += 1
        end
        if behind.positive?
          ahead_behind_parts << "↓#{behind}".red
          site_symbols << "↓#{behind}".red
          has_issues = true
          behind_count += 1
        end
      end

      # Print status line
      status_icon = has_issues ? '●'.yellow : '✓'.green
      clean_count += 1 unless has_issues

      # Check shared submodule
      shared_dir = File.join(site.dir, 'shared')
      shared_status = if Dir.exist?(shared_dir)
                        get_shared_submodule_status(shared_dir)
                      else
                        {
                          error: true,
                          icon: '✗'.red,
                          branch: 'MISSING',
                          raw_branch: 'MISSING',
                          commit: '',
                          issues: 1,
                          symbols: [],
                          is_dirty: false,
                          has_issues: true,
                          ahead: 0,
                          behind: 0
                        }
                      end

      # Update shared counters
      unless shared_status[:error]
        shared_dirty_count += 1 if shared_status[:is_dirty]
        shared_wrong_branch_count += 1 if shared_status[:raw_branch] != 'master'
        shared_ahead_count += 1 if shared_status[:ahead].positive?
        shared_behind_count += 1 if shared_status[:behind].positive?
      end

      if verbose
        # Verbose mode: multi-line format (current behavior)
        puts "#{status_icon} #{site.name.bold} [#{branch_display}]"

        # Show details if verbose or if there are issues
        if verbose || has_issues
          if is_only_shared_pointer
            puts "  #{'↻'.blue}  Shared submodule pointer updated"
          elsif is_dirty
            puts "  #{'⚠'.yellow}  Working directory has uncommitted changes"
          end
        end

        # Always show ahead/behind if present (even in non-verbose mode)
        puts "  #{'↔'.blue}  Remote: #{ahead_behind_parts.join}" unless ahead_behind_parts.empty?

        # Show shared status in verbose mode
        if shared_status[:error]
          puts "  #{shared_status[:icon]}  #{'shared/ directory missing'.red}"
        else
          puts "  #{shared_status[:icon]} shared/ [#{shared_status[:branch]} @ #{shared_status[:commit]}]"

          if (verbose || shared_status[:has_issues]) && shared_status[:is_dirty]
            puts "     #{'⚠'.yellow}  Working directory has uncommitted changes"
          end

          unless shared_status[:symbols].empty?
            remote_parts = shared_status[:symbols].select { |s| s.include?('↑') || s.include?('↓') }
            puts "     #{'↔'.blue}  Remote: #{remote_parts.join(' ')}" unless remote_parts.empty?
          end
        end

        puts
      else
        # Compact mode: single-line table format with leading ⚠ column
        # Format: ⚠ ✓ sitename        [web] ↑2     ● shared/ [master @ hash] ⚠ ↑1

        # Warning column for site (first column)
        # Use different indicator for "only shared pointer" vs "other changes"
        site_warning = if is_only_shared_pointer
                         '↻'.blue
                       elsif is_dirty
                         '⚠'.yellow
                       else
                         ' '
                       end

        # Site part with symbols (only ahead/behind, no ⚠)
        site_symbols_str = site_symbols.empty? ? '' : " #{site_symbols.join}"
        site_part_raw = "#{site.name.ljust(max_name_len)} [#{branch_compact}]#{site_symbols_str}"
        site_part = "#{site_warning} #{status_icon} #{site_part_raw}"

        # Warning column for shared (separate from other symbols)
        shared_warning = shared_status[:is_dirty] ? '⚠'.yellow : ' '

        # Shared symbols without the ⚠ (filter it out)
        shared_symbols_filtered = shared_status[:symbols].reject { |s| s.include?('⚠') }
        shared_symbols_str = shared_symbols_filtered.empty? ? '' : " #{shared_symbols_filtered.join}"

        shared_part = if shared_status[:error]
                        "#{shared_warning} #{shared_status[:icon]} shared/ " \
                          "[#{shared_status[:branch]}]#{shared_symbols_str}"
                      else
                        "#{shared_warning} #{shared_status[:icon]} shared/ " \
                          "[#{shared_status[:branch]} @ #{shared_status[:commit]}]#{shared_symbols_str}"
                      end

        # Calculate padding to align shared column (using stripped length)
        # Site visual length without ANSI codes
        site_visual_len = strip_ansi(site_part).length
        # Target column for shared to start (adjust as needed)
        shared_column_start = max_name_len + 23 # Increased to account for ⚠ column
        padding_needed = [shared_column_start - site_visual_len, 1].max

        # Print as aligned columns
        puts "#{site_part}#{' ' * padding_needed}#{shared_part}"
      end
    end
  end

  # Print summary
  puts
  puts '=== Summary ==='.cyan.bold

  if verbose
    # Verbose summary
    puts "Total submodules:              #{total_submodules.to_s.bold}"
    puts "Clean:                         #{clean_count.to_s.green}"
    puts "Sites uncommitted changes:     #{dirty_count.to_s.yellow}" if dirty_count.positive?
    puts "Sites shared pointer only:     #{shared_pointer_only_count.to_s.blue}" if shared_pointer_only_count.positive?
    puts "Sites ahead of remote:         #{ahead_count.to_s.green}" if ahead_count.positive?
    puts "Sites behind remote:           #{behind_count.to_s.red}" if behind_count.positive?
    puts "Sites wrong branch:            #{wrong_branch_count.to_s.yellow}" if wrong_branch_count.positive?
    puts "Shared uncommitted changes:    #{shared_dirty_count.to_s.yellow}" if shared_dirty_count.positive?
    puts "Shared detached HEAD:          #{shared_wrong_branch_count.to_s.yellow}" if shared_wrong_branch_count.positive?
    puts "Shared ahead of remote:        #{shared_ahead_count.to_s.green}" if shared_ahead_count.positive?
    puts "Shared behind remote:          #{shared_behind_count.to_s.red}" if shared_behind_count.positive?
  else
    # Compact summary - detailed descriptions
    parts = []

    # Sites info
    parts << "#{dirty_count} uncommitted".yellow if dirty_count.positive?
    parts << "#{shared_pointer_only_count} shared pointer".blue if shared_pointer_only_count.positive?
    parts << "#{ahead_count} ahead".green if ahead_count.positive?
    parts << "#{behind_count} behind".red if behind_count.positive?
    parts << "#{wrong_branch_count} wrong branch".yellow if wrong_branch_count.positive?

    sites_str = if parts.empty?
                  'all clean'.green
                else
                  parts.join(', ')
                end

    # Shared info
    shared_parts = []
    shared_parts << "#{shared_dirty_count} uncommitted".yellow if shared_dirty_count.positive?
    shared_parts << "#{shared_wrong_branch_count} detached".yellow if shared_wrong_branch_count.positive?
    shared_parts << "#{shared_ahead_count} ahead".green if shared_ahead_count.positive?
    shared_parts << "#{shared_behind_count} behind".red if shared_behind_count.positive?

    shared_str = if shared_parts.empty?
                   'all on master'.green
                 else
                   shared_parts.join(', ')
                 end

    puts "Sites: #{sites_str} | Shared: #{shared_str}"
  end

  # Exit code based on issues
  exit 1 if behind_count.positive? || shared_behind_count.positive?
end
