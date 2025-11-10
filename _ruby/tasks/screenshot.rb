# frozen_string_literal: true

require 'English'
require 'json'
require 'net/http'
require 'fileutils'
require 'find'

# Screenshot helper functions

def screenshot_path(name)
  File.join(SCREENSHOTS_DIR, name)
end

def screenshot_exists?(name)
  File.directory?(screenshot_path(name))
end

def validate_screenshot_name(name)
  return if name =~ /^[a-zA-Z0-9_-]+$/

  die "Invalid screenshot name '#{name}'. Use only alphanumeric characters, dashes, and underscores."
end

def save_screenshot_metadata(path, data)
  meta_file = File.join(path, '.screenshot-meta.txt')
  content = <<~META
    Screenshot Set Name: #{data[:name]}
    Created: #{data[:created]}
    Git Branch: #{data[:git_branch]}
    Git Commit: #{data[:git_commit]}
    Description: #{data[:description]}
    Port: #{data[:port]}
    Viewport: #{data[:viewport]}
    Browser: #{data[:browser]}
    Total Sites: #{data[:total_sites]}
    Sites: #{data[:sites].join(', ')}
  META
  File.write(meta_file, content)
end

def load_screenshot_metadata(path)
  meta_file = File.join(path, '.screenshot-meta.txt')
  return nil unless File.exist?(meta_file)

  metadata = {}
  File.readlines(meta_file).each do |line|
    next if line.strip.empty?

    key, value = line.split(':', 2)
    next unless value

    metadata[key.strip] = value.strip
  end
  metadata
end

def git_metadata
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  commit = `git rev-parse --short HEAD`.strip
  { branch: branch, commit: commit }
end

def check_server_running(port)
  uri = URI("http://localhost:#{port}")
  Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
    http.head('/')
    return true
  end
rescue StandardError
  false
end

def ensure_build_server_running(port)
  if check_server_running(port)
    puts "#{'Server is already running on port'.green} #{port.to_s.blue}"
    return nil # No PID to clean up
  end

  puts "#{'Starting build server on port'.yellow} #{port.to_s.blue}#{'...'.yellow}"
  pid = spawn('rake', 'serve:build', "PORT=#{port}",
              out: '/dev/null',
              err: '/dev/null')

  # Wait for server to be ready (max 30 seconds)
  30.times do
    sleep 1
    if check_server_running(port)
      puts "#{'Server ready'.green}\n\n"
      return pid
    end
  end

  die "Server failed to start on port #{port} within 30 seconds"
end

def capture_screenshots(sites, output_dir, port)
  # Convert sites to JSON for Node.js script
  sites_json = sites.map { |site| { name: site.name, subdomain: site.subdomain } }.to_json

  # Run screenshot capture script
  node_script = File.join(NODE_DIR, 'screenshot-capture.mjs')

  die "Screenshot capture script not found: #{node_script}" unless File.exist?(node_script)

  system("cd #{NODE_DIR} && node screenshot-capture.mjs '#{sites_json}' '#{output_dir}' #{port}")

  # Don't fail on screenshot errors - some sites may timeout (e.g. redirects)
  # Just warn if there were failures
  puts "#{'⚠ Some screenshots may have failed (check output above)'.yellow}\n" unless $CHILD_STATUS.success?
end

def compare_screenshots(sites, baseline_dir, current_dir, diff_dir)
  sites_json = sites.map { |site| { name: site.name, subdomain: site.subdomain } }.to_json

  node_script = File.join(NODE_DIR, 'screenshot-diff.mjs')

  die "Screenshot diff script not found: #{node_script}" unless File.exist?(node_script)

  # Returns exit code: 0 if no changes, 1 if changes detected
  system("cd #{NODE_DIR} && node screenshot-diff.mjs '#{sites_json}' '#{baseline_dir}' '#{current_dir}' '#{diff_dir}'")
  $CHILD_STATUS.exitstatus
end

def generate_html_report(diff_dir, baseline_name, baseline_metadata, current_metadata)
  results_file = File.join(diff_dir, 'results.json')
  return unless File.exist?(results_file)

  results = JSON.parse(File.read(results_file))

  changed_sites = results.reject { |r| r['error'] || r['matched'] }
  unchanged_sites = results.select { |r| !r['error'] && r['matched'] }

  html = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Screenshot Diff Report: #{baseline_name}</title>
      <style>
        * { box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          margin: 0;
          padding: 20px;
          background: #f5f5f5;
        }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { margin-top: 0; color: #333; }
        h2 { color: #555; border-bottom: 2px solid #e0e0e0; padding-bottom: 10px; }
        h3 { color: #666; }
        .metadata { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px; }
        .metadata-box { background: #f9f9f9; padding: 15px; border-radius: 4px; }
        .metadata-box p { margin: 5px 0; }
        .summary { background: #e3f2fd; padding: 20px; border-radius: 4px; margin-bottom: 30px; }
        .summary p { margin: 5px 0; }
        .site { margin-bottom: 40px; padding: 20px; border: 1px solid #e0e0e0; border-radius: 4px; }
        .site.unchanged { opacity: 0.6; }
        .site h3 { margin-top: 0; }
        .site h3.changed { color: #d32f2f; }
        .site h3.unchanged { color: #388e3c; }
        .comparison { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; margin-top: 20px; }
        .comparison-item { text-align: center; }
        .comparison-item h4 { margin: 0 0 10px 0; font-size: 14px; color: #666; }
        .comparison-item img { max-width: 100%; border: 1px solid #ddd; border-radius: 4px; }
        .jump-nav { position: sticky; top: 20px; background: #fff3cd; padding: 15px; border-radius: 4px; margin-bottom: 20px; }
        .jump-nav a { color: #856404; margin-right: 15px; text-decoration: none; }
        .jump-nav a:hover { text-decoration: underline; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>📸 Screenshot Diff Report</h1>

        <div class="metadata">
          <div class="metadata-box">
            <h2>Baseline</h2>
            <p><strong>Name:</strong> #{baseline_name}</p>
            <p><strong>Created:</strong> #{baseline_metadata['Created']}</p>
            <p><strong>Commit:</strong> #{baseline_metadata['Git Commit']}</p>
            <p><strong>Branch:</strong> #{baseline_metadata['Git Branch']}</p>
          </div>

          <div class="metadata-box">
            <h2>Current Build</h2>
            <p><strong>Commit:</strong> #{current_metadata[:commit]}</p>
            <p><strong>Branch:</strong> #{current_metadata[:branch]}</p>
            <p><strong>Date:</strong> #{current_metadata[:created]}</p>
          </div>
        </div>

        <div class="summary">
          <h2>Summary</h2>
          <p><strong>Total sites:</strong> #{results.length}</p>
          <p><strong>Unchanged:</strong> #{unchanged_sites.length}</p>
          <p><strong>Changed:</strong> #{changed_sites.length}</p>
          #{"<p><strong>Changed sites:</strong> #{changed_sites.map { |s| s['site'] }.join(', ')}</p>" if changed_sites.any?}
        </div>

        #{if changed_sites.any?
            "<div class=\"jump-nav\">
            <strong>Jump to changed sites:</strong>
            #{changed_sites.map { |s| "<a href=\"##{s['subdomain']}\">#{s['site']}</a>" }.join}
          </div>"
          end}

        <div class="sites">
  HTML

  results.each do |result|
    if result['error']
      html << "          <div class=\"site\">\n"
      html << "            <h3 class=\"error\">#{result['site']} (ERROR)</h3>\n"
      html << "            <p>Error: #{result['error']}</p>\n"
    elsif result['matched']
      html << "          <div class=\"site unchanged\" id=\"#{result['subdomain']}\">\n"
      html << "            <h3 class=\"unchanged\">✓ #{result['site']} (UNCHANGED)</h3>\n"
    else
      diff_count = result['diffCount'].to_s.reverse.scan(/\d{1,3}/).join(',').reverse
      html << "          <div class=\"site\" id=\"#{result['subdomain']}\">\n"
      html << "            <h3 class=\"changed\">● #{result['site']} (CHANGED - #{diff_count} pixels)</h3>\n"
      html << "            \n"
      html << "            <div class=\"comparison\">\n"
      html << "              <div class=\"comparison-item\">\n"
      html << "                <h4>Baseline</h4>\n"
      html << "                <img src=\"#{result['subdomain']}-baseline.png\" alt=\"Baseline\">\n"
      html << "              </div>\n"
      html << "              \n"
      html << "              <div class=\"comparison-item\">\n"
      html << "                <h4>Current</h4>\n"
      html << "                <img src=\"#{result['subdomain']}-current.png\" alt=\"Current\">\n"
      html << "              </div>\n"
      html << "              \n"
      html << "              <div class=\"comparison-item\">\n"
      html << "                <h4>Diff (magenta = changed)</h4>\n"
      html << "                <img src=\"#{result['subdomain']}-diff.png\" alt=\"Diff\">\n"
      html << "              </div>\n"
      html << "            </div>\n"
    end
    html << "          </div>\n"
  end

  html << <<~HTML_END
        </div>
      </div>
    </body>
    </html>
  HTML_END

  report_path = File.join(diff_dir, 'report.html')
  File.write(report_path, html)
  report_path
end

def list_screenshots
  return [] unless File.directory?(SCREENSHOTS_DIR)

  Dir.glob(File.join(SCREENSHOTS_DIR, '*'))
     .select { |f| File.directory?(f) }
     .map { |f| File.basename(f) }
     .reject { |name| name.start_with?('_') || name.start_with?('.') }
end

def get_directory_size(path)
  total = 0
  Find.find(path) do |file|
    total += File.size(file) if File.file?(file)
  end
  total
end

def format_size(bytes)
  units = %w[B KB MB GB]
  return '0 B' if bytes.zero?

  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = [exp, units.length - 1].min
  format('%<size>.1f %<unit>s', size: bytes.to_f / (1024**exp), unit: units[exp])
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

# Rake tasks

namespace :screenshot do
  desc 'Create a screenshot set (name=X desc="...")'
  task :create do
    name = ENV.fetch('name', nil)
    description = ENV['desc'] || 'Screenshot set'

    die 'Please provide a name: rake screenshot:create name=baseline desc="..."' unless name

    validate_screenshot_name(name)

    if screenshot_exists?(name)
      die "Screenshot set '#{name}' already exists. Use a different name or delete the existing one."
    end

    # Check if build directory exists
    die "Build directory #{BUILD_DIR} does not exist. Run 'rake build' first." unless File.directory?(BUILD_DIR)

    # Detect built sites
    built_sites = Dir.glob(File.join(BUILD_DIR, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }
                     .reject { |name| name.start_with?('_') || name.start_with?('.') }

    die "No built sites found in #{BUILD_DIR}. Run 'rake build' first." if built_sites.empty?

    puts "#{'=== Creating Screenshot Set:'.cyan} #{name.bold} #{'==='.cyan}\n\n"

    port = (ENV['PORT'] || 8080).to_i

    # Create Site objects for built sites
    build_sites = create_build_sites(SITES, BUILD_BASE_PORT, LOCAL_DOMAIN)
    build_sites = build_sites.select { |site| built_sites.include?(site.name) }

    # Filter out excluded sites
    build_sites = build_sites.reject { |site| SCREENSHOT_EXCLUDES.include?(site.name) }

    puts "#{'Excluded sites:'.gray} #{SCREENSHOT_EXCLUDES.join(', ').gray}\n\n" if SCREENSHOT_EXCLUDES.any?

    # Ensure server is running
    server_pid = ensure_build_server_running(port)

    begin
      # Create output directory
      output_dir = screenshot_path(name)
      FileUtils.mkdir_p(output_dir)

      # Capture screenshots
      puts "#{'→'.blue} Capturing screenshots...\n"
      capture_screenshots(build_sites, output_dir, port)
      puts

      # Save metadata
      git_data = git_metadata
      metadata = {
        name: name,
        created: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC'),
        git_branch: git_data[:branch],
        git_commit: git_data[:commit],
        description: description,
        port: port,
        viewport: '1920x1080',
        browser: 'chromium',
        total_sites: build_sites.length,
        sites: build_sites.map(&:subdomain)
      }
      save_screenshot_metadata(output_dir, metadata)

      # Display summary
      size = get_directory_size(output_dir)
      puts '=== Screenshot Set Summary ==='.cyan
      puts "#{'Name:'.bold.ljust(14)} #{name.bold}"
      puts "#{'Location:'.ljust(14)} #{output_dir.to_s.gray}"
      puts "#{'Size:'.ljust(14)} #{format_size(size).green}"
      puts "#{'Sites:'.ljust(14)} #{build_sites.length}"
      puts "#{'Git commit:'.ljust(14)} #{git_data[:commit].gray} on #{git_data[:branch].gray}"
      puts "#{'Description:'.ljust(14)} #{description}"
      puts
      puts '✓ Screenshot set created successfully'.green
    ensure
      # Clean up server if we started it
      if server_pid
        Process.kill('INT', server_pid)
        Process.wait(server_pid)
      end
    end
  end

  desc 'Compare screenshots with baseline (name=X open=1)'
  task :diff do
    name = ENV.fetch('name', nil)

    die 'Please provide a name: rake screenshot:diff name=baseline' unless name

    validate_screenshot_name(name)

    baseline_dir = screenshot_path(name)
    unless screenshot_exists?(name)
      die "Screenshot set '#{name}' does not exist. Available sets: #{list_screenshots.join(', ')}"
    end

    # Check if build directory exists
    die "Build directory #{BUILD_DIR} does not exist. Run 'rake build' first." unless File.directory?(BUILD_DIR)

    puts "#{'=== Comparing Screenshots:'.cyan} #{name.bold} #{'==='.cyan}\n\n"

    # Load baseline metadata
    baseline_metadata = load_screenshot_metadata(baseline_dir)

    port = (ENV['PORT'] || 8080).to_i

    # Detect built sites
    built_sites = Dir.glob(File.join(BUILD_DIR, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }
                     .reject { |name| name.start_with?('_') || name.start_with?('.') }

    build_sites = create_build_sites(SITES, BUILD_BASE_PORT, LOCAL_DOMAIN)
    build_sites = build_sites.select { |site| built_sites.include?(site.name) }

    # Filter out excluded sites
    build_sites = build_sites.reject { |site| SCREENSHOT_EXCLUDES.include?(site.name) }

    puts "#{'Excluded sites:'.gray} #{SCREENSHOT_EXCLUDES.join(', ').gray}\n\n" if SCREENSHOT_EXCLUDES.any?

    # Ensure server is running
    server_pid = ensure_build_server_running(port)

    begin
      # Capture current screenshots
      current_dir = File.join(SCREENSHOTS_DIR, '.tmp', Time.now.to_i.to_s)
      FileUtils.mkdir_p(current_dir)

      puts "#{'→'.blue} Capturing current screenshots...\n"
      capture_screenshots(build_sites, current_dir, port)
      puts

      # Compare screenshots
      diff_dir = File.join(SCREENSHOTS_DIR, ".diff-#{name}")
      FileUtils.rm_rf(diff_dir) if File.directory?(diff_dir)
      FileUtils.mkdir_p(diff_dir)

      puts "#{'→'.blue} Comparing with baseline...\n"
      compare_screenshots(build_sites, baseline_dir, current_dir, diff_dir)
      puts

      # Generate HTML report
      git_data = git_metadata
      current_metadata = {
        commit: git_data[:commit],
        branch: git_data[:branch],
        created: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')
      }
      report_path = generate_html_report(diff_dir, name, baseline_metadata, current_metadata)

      # Load results for summary
      results_file = File.join(diff_dir, 'results.json')
      results = JSON.parse(File.read(results_file)) if File.exist?(results_file)

      if results
        unchanged = results.count { |r| !r['error'] && r['matched'] }
        changed = results.count { |r| !r['error'] && !r['matched'] }
        changed_sites = results.select { |r| !r['error'] && !r['matched'] }.map { |r| r['site'] }

        puts '=== Diff Summary ==='.cyan
        puts "#{'Total sites:'.ljust(14)} #{results.length.to_s.bold}"
        puts "#{'Unchanged:'.ljust(14)} #{unchanged.to_s.green}"
        puts "#{'Changed:'.ljust(14)} #{changed.to_s.yellow}#{" (#{changed_sites.join(', ')})" if changed.positive?}"
        puts
        puts "#{'Report saved to:'.ljust(14)} #{report_path.to_s.gray}"

        # Optionally open report in browser
        if ENV['open'] == '1'
          puts 'Opening report...'.yellow
          system("open '#{report_path}'")
        else
          puts "#{'Open with:'.ljust(14)} #{"open #{report_path}".gray}"
        end
        puts

        if changed.positive?
          puts '⚠ Changes detected'.yellow
          exit(1)
        else
          puts '✓ No changes detected'.green
        end
      end
    ensure
      # Clean up server if we started it
      if server_pid
        Process.kill('INT', server_pid)
        Process.wait(server_pid)
      end

      # Clean up temp directory
      begin
        FileUtils.rm_rf(File.dirname(current_dir))
      rescue
        nil
      end
    end
  end

  desc 'List all screenshot sets'
  task :list do
    require 'time'

    if !File.directory?(SCREENSHOTS_DIR) || list_screenshots.empty?
      puts 'No screenshot sets found.'
      puts "Create one with: #{'rake screenshot:create name=baseline'.gray}"
      return
    end

    puts "#{'Available screenshot sets:'.cyan}\n\n"

    # Build list with metadata and sort by date (newest first)
    screenshot_list = Dir.glob(File.join(SCREENSHOTS_DIR, '*'))
                         .select { |f| File.directory?(f) }
                         .map { |f| File.basename(f) }
                         .reject { |name| name.start_with?('_') || name.start_with?('.') }
                         .map do |name|
                           path = screenshot_path(name)
                           metadata = load_screenshot_metadata(path)
                           created = metadata ? metadata['Created'] : nil
                           # Parse date for sorting
                           timestamp = if created && created != 'unknown'
                                         begin
                                           Time.parse(created)
                                         rescue StandardError
                                           Time.at(0)
                                         end
                                       else
                                         Time.at(0) # Unknown dates go to the end
                                       end
                           { name: name, path: path, metadata: metadata, timestamp: timestamp }
                         end
    screenshots = screenshot_list.sort_by { |s| -s[:timestamp].to_i } # Newest first (negative for descending)

    screenshots.each do |screenshot|
      name = screenshot[:name]
      path = screenshot[:path]
      metadata = screenshot[:metadata]
      size = get_directory_size(path)

      if metadata && metadata['Created']
        friendly_time = format_friendly_time(metadata['Created'])
        puts "  #{'○'.gray} #{name.bold} - #{format_size(size).green} - #{friendly_time}"
      else
        puts "  #{'○'.gray} #{name.bold} - #{format_size(size).green}"
      end
    end
  end
end
