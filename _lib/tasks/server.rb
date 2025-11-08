# frozen_string_literal: true

desc 'prints info how to setup /etc/hosts'
task :hosts do
  puts prepare_hosts_template(SITES)
end

namespace :proxy do
  desc 'generate proxy config (for nginx)'
  task :config do
    puts prepare_proxy_config(SITES, mode: :serve, proxy_port: MAIN_PORT)
  end
end

desc 'start proxy server'
task :proxy do
  trap('INT') do
    exit 10
  end
  config_path = File.join(STAGE_DIR, '.proxy.config')
  FileUtils.mkdir_p(STAGE_DIR) unless File.exist? STAGE_DIR
  File.write(config_path, prepare_proxy_config(SITES, mode: :serve, proxy_port: MAIN_PORT))
  sys("sudo nginx -c \"#{config_path}\"")
end

desc 'run dev server'
task :serve do
  all_names = sites_subdomains(SITES).join(',')
  what = ENV['what']

  # Default to all sites if 'what' is not specified
  what = all_names if what.to_s.strip.empty? || what == 'all'
  names = clean_names(what.split(','))

  puts "note: #{'make sure you have'.green} #{'/etc/hosts'.yellow} #{'properly configured, see'.green} #{'rake hosts'.blue}"
  serve_sites(SITES, SERVE_DIR, names)
end

namespace :serve do
  desc 'serve pre-built sites from .stage/build/ via nginx proxy (for testing production builds locally)'
  task :build do
    # Check if build directory exists
    unless File.directory?(BUILD_DIR)
      die "Build directory #{BUILD_DIR} does not exist. Run 'rake build' first."
    end

    # Auto-detect built sites
    built_sites = Dir.glob(File.join(BUILD_DIR, '*'))
                     .select { |f| File.directory?(f) }
                     .map { |f| File.basename(f) }

    if built_sites.empty?
      die "No built sites found in #{BUILD_DIR}. Run 'rake build what=www,blog' first."
    end

    puts "Found built sites: #{built_sites.join(', ').yellow}"

    # Get proxy port from environment (default: 8080, no sudo needed)
    proxy_port = (ENV['PORT'] || 8080).to_i
    use_sudo = proxy_port < 1024

    # Create Site objects for built sites
    build_sites = create_build_sites(SITES, BUILD_BASE_PORT, LOCAL_DOMAIN)

    # Filter to only include actually built sites
    build_sites = build_sites.select { |site| built_sites.include?(site.name) }

    if build_sites.empty?
      die "No matching sites found. Built sites: #{built_sites.join(', ')}"
    end

    puts "\n#{'Starting servers for:'.green}"
    build_sites.each do |site|
      puts "  • #{site.subdomain.yellow} on port #{site.port.to_s.blue}"
    end
    puts "\n#{'Proxy will be available at:'.green} #{"http://localhost:#{proxy_port}".blue}"
    puts "#{'Access sites at:'.green}"
    build_sites.each do |site|
      puts "  • #{"http://#{site.subdomain}.#{LOCAL_DOMAIN}:#{proxy_port}".blue}"
    end
    puts

    # Start Python HTTP servers for each built site
    pids = start_python_servers(build_sites, BUILD_DIR)

    # Generate nginx config
    config_path = File.join(STAGE_DIR, '.proxy-build.config')
    FileUtils.mkdir_p(STAGE_DIR) unless File.exist?(STAGE_DIR)
    File.write(config_path, prepare_proxy_config(build_sites, mode: :build, proxy_port: proxy_port))

    # Trap INT signal to cleanup
    trap('INT') do
      puts "\n\n#{'Stopping servers...'.yellow}"
      stop_python_servers(pids)
      puts "#{'All servers stopped.'.green}"
      exit 0
    end

    # Start nginx
    nginx_cmd = use_sudo ? "sudo nginx -c \"#{config_path}\"" : "nginx -c \"#{config_path}\""
    puts "#{'Starting nginx...'.green} (#{use_sudo ? 'with sudo' : 'without sudo'})"

    begin
      sys(nginx_cmd)
    rescue StandardError => e
      puts "#{'Failed to start nginx:'.red} #{e.message}"
      stop_python_servers(pids)
      exit 1
    end

    puts "\n#{'Press Ctrl+C to stop all servers'.yellow}"

    # Keep the script running
    sleep
  end
end
