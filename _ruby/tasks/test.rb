# frozen_string_literal: true

require 'json'
require 'net/http'

namespace :test do
  desc 'Run smoke tests on all built sites'
  task :smoke do
    # Check if build directory exists
    die "Build directory #{BUILD_DIR} does not exist. Run 'rake build' first." unless File.directory?(BUILD_DIR)

    # Auto-detect built sites (same as serve:build)
    # Exclude volatile directories like _cache and .configs
    built_sites = Dir.glob(File.join(BUILD_DIR, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }
                     .reject { |name| name.start_with?('_') || name.start_with?('.') }

    die "No built sites found in #{BUILD_DIR}. Run 'rake build what=www,blog' first." if built_sites.empty?

    puts "Found built sites: #{built_sites.join(', ').yellow}\n\n"

    # Get proxy port from environment (default: 8080)
    proxy_port = (ENV['PORT'] || 8080).to_i

    # Create Site objects for built sites
    build_sites = create_build_sites(SITES, BUILD_BASE_PORT, LOCAL_DOMAIN)

    # Filter to only include actually built sites
    build_sites = build_sites.select { |site| built_sites.include?(site.name) }

    die "No matching sites found. Built sites: #{built_sites.join(', ')}" if build_sites.empty?

    # Check if serve:build is already running
    server_running = check_server_running(proxy_port)

    if server_running
      puts "#{'Server is already running on port'.green} #{proxy_port.to_s.blue}\n\n"
      run_smoke_tests(build_sites, proxy_port)
    else
      puts "#{'Server is not running. Starting serve:build in background...'.yellow}\n"
      run_with_server(build_sites, proxy_port)
    end
  end
end

def check_server_running(port)
  # Try to connect to localhost:port

  uri = URI("http://localhost:#{port}")
  Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
    http.head('/')
    return true
  end
rescue StandardError
  false
end

def run_smoke_tests(sites, port)
  # Convert sites to JSON format for Node.js script
  sites_json = sites.map { |site| { name: site.name, subdomain: site.subdomain } }.to_json

  # Run Playwright smoke test
  node_script = File.join(NODE_DIR, 'smoke-test.mjs')

  die "Smoke test script not found: #{node_script}" unless File.exist?(node_script)

  # Check if Playwright is installed
  playwright_bin = File.join(NODE_DIR, 'node_modules', '@playwright', 'test')
  unless File.directory?(playwright_bin)
    puts "#{'Playwright not installed. Installing...'.yellow}\n"
    Dir.chdir(NODE_DIR) do
      sys('npm install')
      puts "#{'Installing Playwright browsers...'.yellow}\n"
      sys('npx playwright install chromium')
    end
    puts
  end

  puts "#{'Running smoke tests...'.green}\n\n"

  success = system("cd #{NODE_DIR} && node smoke-test.mjs '#{sites_json}' #{port}")

  exit(success ? 0 : 1)
end

def run_with_server(sites, port)
  # Start serve:build in background
  pid = spawn('rake', 'serve:build', "PORT=#{port}",
              out: '/dev/null',
              err: '/dev/null')

  # Give the server time to start
  print 'Waiting for server to start'
  max_wait = 30 # seconds
  waited = 0
  server_ready = false

  while waited < max_wait
    sleep 1
    print '.'
    waited += 1

    if check_server_running(port)
      server_ready = true
      break
    end
  end

  puts "\n\n"

  unless server_ready
    Process.kill('INT', pid)
    Process.wait(pid)
    die "Server failed to start within #{max_wait} seconds"
  end

  puts "#{'Server started successfully'.green}\n\n"

  begin
    run_smoke_tests(sites, port)
  ensure
    # Stop the server
    puts "\n#{'Stopping server...'.yellow}"
    Process.kill('INT', pid)
    Process.wait(pid)
    puts 'Server stopped'.green
  end
end
