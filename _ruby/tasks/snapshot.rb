# frozen_string_literal: true

# Helper methods for snapshot functionality
def validate_snapshot_name(name)
  return if name =~ /^[a-zA-Z0-9_-]+$/

  die 'Snapshot name must contain only letters, numbers, dashes, and underscores'
end

def snapshot_path(name)
  File.join(SNAPSHOTS_DIR, name)
end

def snapshot_exists?(name)
  File.directory?(snapshot_path(name))
end

def confirm?(message)
  print "#{message} (y/N): "
  $stdin.gets.chomp.downcase == 'y'
end

def git_metadata
  {
    commit: `git rev-parse --short HEAD 2>/dev/null`.strip,
    branch: `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
  }
rescue StandardError
  { commit: 'unknown', branch: 'unknown' }
end

def save_snapshot_metadata(path, data)
  metadata_file = File.join(path, '.snapshot-meta.txt')
  content = <<~META
    Snapshot Name: #{data[:name]}
    Created: #{data[:timestamp]}
    Git Branch: #{data[:branch]}
    Git Commit: #{data[:commit]}
    Description: #{data[:description] || 'N/A'}
    Build Command: rake build
    Exclusions: #{SNAPSHOT_EXCLUDES.map { |e| "#{e}/" }.join(', ')}
  META
  File.write(metadata_file, content)
end

def load_snapshot_metadata(path)
  metadata_file = File.join(path, '.snapshot-meta.txt')
  return {} unless File.exist?(metadata_file)

  content = File.read(metadata_file)
  {
    name: content[/^Snapshot Name: (.+)$/, 1],
    created: content[/^Created: (.+)$/, 1],
    branch: content[/^Git Branch: (.+)$/, 1],
    commit: content[/^Git Commit: (.+)$/, 1],
    description: content[/^Description: (.+)$/, 1]
  }
end

def format_friendly_time(utc_time_string)
  require 'time'
  return 'unknown' if utc_time_string.nil? || utc_time_string == 'unknown'

  begin
    # Parse UTC time and convert to local time
    utc_time = Time.parse(utc_time_string)
    local_time = utc_time.getlocal

    # Format: "Nov 8, 2025 at 2:54 PM"
    local_time.strftime('%b %-d, %Y at %-I:%M %p')
  rescue StandardError
    utc_time_string
  end
end

def human_size(bytes)
  units = %w[B KB MB GB TB]
  return '0 B' if bytes.zero?

  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = [exp, units.length - 1].min
  size = bytes / (1024.0**exp)
  format('%<size>.1f %<unit>s', size: size, unit: units[exp])
end

def directory_size(dir)
  total = 0
  Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH).each do |file|
    total += File.size(file) if File.file?(file)
  end
  total
end

def copy_build_excluding(dest, excludes)
  require 'fileutils'
  FileUtils.mkdir_p(dest)
  FileUtils.cp_r("#{BUILD_DIR}/.", dest)
  excludes.each do |pattern|
    FileUtils.rm_rf(Dir.glob(File.join(dest, pattern)))
  end
end

def diff_directories(dir1, dir2, excludes)
  # Returns: { changed: [], new: [], missing: [], unchanged: [] }
  result = { changed: [], new: [], missing: [], unchanged: [] }

  # Get sites from both directories
  current_sites = Dir.glob(File.join(dir2, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }
                     .reject { |name| excludes.include?(name) || name.start_with?('.') }

  snapshot_sites = Dir.glob(File.join(dir1, '*'))
                      .select { |f| File.directory?(f) }
                      .map { |f| File.basename(f) }
                      .reject { |name| excludes.include?(name) || name.start_with?('.') }

  # Compare each current site
  current_sites.each do |site|
    snapshot_site = File.join(dir1, site)
    current_site = File.join(dir2, site)

    unless File.directory?(snapshot_site)
      result[:new] << site
      next
    end

    # Compare directories using system diff command
    diff_cmd = "diff -rq --exclude='_cache' --exclude='.configs' --exclude='atom.xml' " \
               "'#{snapshot_site}' '#{current_site}' >/dev/null 2>&1"
    if system(diff_cmd)
      result[:unchanged] << site
    else
      result[:changed] << site
    end
  end

  # Find missing sites (in snapshot but not current)
  snapshot_sites.each do |site|
    current_site = File.join(dir2, site)
    result[:missing] << site unless File.directory?(current_site)
  end

  result
end

def show_verbose_diff(snapshot_site, current_site)
  diff_cmd = "diff -rq --exclude='_cache' --exclude='.configs' --exclude='atom.xml' " \
             "'#{snapshot_site}' '#{current_site}' 2>/dev/null"
  output = `#{diff_cmd}`
  output.lines.each do |line|
    puts "     #{line.strip}"
  end
end

namespace :snapshot do
  desc 'create a snapshot of the current build output (name=<name> desc=<description>)'
  task :create do
    name = ENV.fetch('name', nil)
    die 'Snapshot name is required. Usage: rake snapshot:create name=<name> desc=<description>' unless name

    validate_snapshot_name(name)
    description = ENV['desc'] || ENV.fetch('description', nil)

    # Check if snapshot already exists
    if snapshot_exists?(name)
      puts "#{'Warning:'.yellow} Snapshot '#{name}' already exists"
      unless confirm?('Overwrite?')
        puts 'Cancelled'.gray
        exit 0
      end
      puts 'Removing existing snapshot...'.yellow
      FileUtils.rm_rf(snapshot_path(name))
    end

    # Create snapshots directory
    FileUtils.mkdir_p(SNAPSHOTS_DIR)

    puts "#{'=== Creating Snapshot:'.cyan.bold} #{name.bold} #{'==='.cyan.bold}\n\n"

    # Step 1: Build all sites
    puts "#{'→'.blue} Building all sites..."
    puts "  #{'Running: rake build'.gray}"
    build_log = '/tmp/snapshot-build.log'
    unless system("rake build > #{build_log} 2>&1")
      puts '✗ Build failed!'.red
      puts "  #{'See log:'.gray} #{build_log}"
      puts `tail -n 20 #{build_log}`
      exit 1
    end
    puts "#{'✓'.green} Build completed successfully\n\n"

    # Check if build directory exists
    die "Build directory not found: #{BUILD_DIR}" unless File.directory?(BUILD_DIR)

    # Step 2: Create snapshot
    puts "#{'→'.blue} Creating snapshot..."
    puts "  #{'Copying build output (excluding volatile files)...'.gray}"
    copy_build_excluding(snapshot_path(name), SNAPSHOT_EXCLUDES)
    puts "#{'✓'.green} Snapshot created\n\n"

    # Step 3: Save metadata
    git_meta = git_metadata
    timestamp = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')

    save_snapshot_metadata(snapshot_path(name), {
                             name: name,
                             timestamp: timestamp,
                             branch: git_meta[:branch],
                             commit: git_meta[:commit],
                             description: description
                           })

    puts "#{'→'.blue} Snapshot metadata saved\n\n"

    # Step 4: Display summary
    size = directory_size(snapshot_path(name))
    site_count = Dir.glob(File.join(snapshot_path(name), '*'))
                    .select { |f| File.directory?(f) && !File.basename(f).start_with?('.') }
                    .reject { |f| SNAPSHOT_EXCLUDES.include?(File.basename(f)) }
                    .count

    puts '=== Snapshot Summary ==='.cyan.bold
    puts "Name:         #{name.bold}"
    puts "Location:     #{snapshot_path(name).gray}"
    puts "Size:         #{human_size(size).green}"
    puts "Sites:        #{site_count}"
    puts "Git commit:   #{git_meta[:commit].gray} on #{git_meta[:branch].gray}"
    puts "Description:  #{description}" if description
    puts

    # List all snapshots
    Rake::Task['snapshot:list'].invoke

    puts "\n#{'✓ Snapshot created successfully'.green}"
    puts "#{'Compare with: rake snapshot:diff name='.gray}#{name.gray}"
  end

  desc 'compare current build with a snapshot (name=<name> verbose=1 for details)'
  task :diff do
    name = ENV.fetch('name', nil)
    die 'Snapshot name is required. Usage: rake snapshot:diff name=<name> verbose=1' unless name

    verbose = ENV['verbose'] == '1'

    # Validate snapshot exists
    unless snapshot_exists?(name)
      puts "#{'Error:'.red} Snapshot '#{name}' not found"
      puts 'Available snapshots:'.gray
      if File.directory?(SNAPSHOTS_DIR)
        Dir.glob(File.join(SNAPSHOTS_DIR, '*')).each do |snap|
          puts "  - #{File.basename(snap)}" if File.directory?(snap)
        end
      else
        puts '  (none)'.gray
      end
      exit 2
    end

    # Validate current build exists
    die "Current build not found: #{BUILD_DIR}\nRun 'rake build' first" unless File.directory?(BUILD_DIR)

    # Display snapshot metadata
    metadata = load_snapshot_metadata(snapshot_path(name))
    puts "#{'=== Comparing Build Output ==='.cyan.bold}\n\n"
    puts "#{'Snapshot:'.bold} #{name}"
    if metadata[:created]
      puts "#{'Created:'.gray} #{metadata[:created]}"
      puts "#{'Git commit:'.gray} #{metadata[:commit]}" if metadata[:commit]
      puts "#{'Description:'.gray} #{metadata[:description]}" if metadata[:description] && metadata[:description] != 'N/A'
    end
    puts

    # Compare directories
    puts "#{'→'.blue} Comparing sites...\n\n"
    diff = diff_directories(snapshot_path(name), BUILD_DIR, SNAPSHOT_EXCLUDES)

    # Display results
    all_sites = (diff[:unchanged] + diff[:changed] + diff[:new]).sort

    all_sites.each do |site|
      if diff[:new].include?(site)
        puts "  #{'+'.cyan} #{site.bold} - #{'NEW'.cyan} (not in snapshot)"
      elsif diff[:unchanged].include?(site)
        puts "  #{'✓'.green} #{site} - #{'unchanged'.gray}"
      elsif diff[:changed].include?(site)
        puts "  #{'●'.yellow} #{site.bold} - #{'CHANGED'.yellow}"
        if verbose
          snapshot_site = File.join(snapshot_path(name), site)
          current_site = File.join(BUILD_DIR, site)
          show_verbose_diff(snapshot_site, current_site)
        end
      end
    end

    # Show missing sites
    diff[:missing].each do |site|
      puts "  #{'-'.red} #{site.bold} - #{'MISSING'.red} (was in snapshot)"
    end

    puts

    # Print summary
    total_sites = all_sites.count
    puts '=== Summary ==='.cyan.bold
    puts "Total sites:     #{total_sites.to_s.bold}"
    puts "Unchanged:       #{diff[:unchanged].count.to_s.green}"
    puts "Changed:         #{diff[:changed].count.to_s.yellow}" if diff[:changed].any?
    puts "New sites:       #{diff[:new].count.to_s.cyan}" if diff[:new].any?
    puts "Missing sites:   #{diff[:missing].count.to_s.red}" if diff[:missing].any?
    puts

    # Show instructions for detailed diff
    if diff[:changed].any? || diff[:new].any? || diff[:missing].any?
      puts 'For detailed file-level differences:'.bold
      puts "  #{"rake snapshot:diff name=#{name} verbose=1".gray}" unless verbose
      diff_example = "diff -ru --exclude='_cache' --exclude='.configs' --exclude='atom.xml' " \
                     "#{snapshot_path(name)}/ #{BUILD_DIR}/"
      puts "  #{diff_example.gray}"
      puts

      # List changed sites
      if diff[:changed].any?
        puts 'Changed sites:'.bold
        diff[:changed].each do |site|
          puts "  - #{site}"
          puts "    #{"diff -ru #{snapshot_path(name)}/#{site}/ #{BUILD_DIR}/#{site}/".gray}"
        end
        puts
      end

      puts '⚠ Build output differs from snapshot'.yellow
      exit 1
    else
      puts '✓ Build output matches snapshot exactly'.green
      exit 0
    end
  end

  desc 'list all available snapshots'
  task :list do
    require 'time'

    puts 'Available snapshots:'.bold
    if File.directory?(SNAPSHOTS_DIR)
      snapshot_list = Dir.glob(File.join(SNAPSHOTS_DIR, '*'))
                         .select { |f| File.directory?(f) }
                         .map do |snap_path|
                           metadata = load_snapshot_metadata(snap_path)
                           created = metadata[:created]
                           # Parse date for sorting (format: "YYYY-MM-DD HH:MM:SS UTC")
                           timestamp = if created && created != 'unknown'
                                         begin
                                           Time.parse(created)
                                         rescue StandardError
                                           Time.at(0)
                                         end
                                       else
                                         Time.at(0) # Unknown dates go to the end
                                       end
                           { path: snap_path, timestamp: timestamp }
                         end
      snapshots = snapshot_list.sort_by { |s| -s[:timestamp].to_i } # Newest first (negative for descending)

      if snapshots.empty?
        puts '  (none)'.gray
      else
        snapshots.each do |snap|
          name = File.basename(snap[:path])
          size = directory_size(snap[:path])
          metadata = load_snapshot_metadata(snap[:path])
          created = format_friendly_time(metadata[:created])

          puts "  #{'○'.gray} #{name} - #{human_size(size)} - #{created}"
        end
      end
    else
      puts '  (none)'.gray
    end
  end
end
