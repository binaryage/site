# frozen_string_literal: true

desc 'build site'
task :build do
  what = ENV['what'] || sites_subdomains(SITES).join(',')
  names = clean_names(what.split(','))

  # TODO: we could bring in more stuff from env
  build_opts = {
    stage: ENV['stage'] || BUILD_DIR,
    dev_mode: false,
    clean_stage: true,
    busters: true
  }

  build_sites(SITES, build_opts, names)
end

desc 'generate store template zip' # see https://springboard.fastspring.com/site/configuration/template/doc/templateOverview.xml
task :store do
  opts = {
    stage: STORE_DIR,
    dont_prune: true,
    zip_path: File.join(ROOT, 'store-template.zip')
  }
  build_store(SITES.first, opts)
end

desc 'inspect the list of sites currently registered (verbose=1 for details)'
task :inspect do
  verbose = ENV['verbose'] == '1'

  # Helper: check if site is built
  def site_is_built?(site, stage_dir)
    Dir.exist?(File.join(stage_dir, site.name))
  end

  # Helper: get git status
  def site_git_status(site)
    Dir.chdir(site.dir) do
      status = `git status --porcelain 2>/dev/null`.strip
      return status.empty? ? :clean : :dirty
    end
  rescue StandardError
    :unknown
  end

  # Helper: check if has shared submodule
  def site_has_shared?(site)
    shared_dir = File.join(site.dir, 'shared')
    git_dir = File.join(shared_dir, '.git')
    Dir.exist?(shared_dir) && (File.exist?(git_dir) || File.directory?(git_dir))
  end

  puts "#{'=== Registered Sites ==='.cyan.bold}\n\n"

  # Calculate column widths
  max_name_len = SITES.map { |s| s.name.length }.max
  max_subdomain_len = SITES.map { |s| s.subdomain.length }.max

  # Header
  puts format("%-#{max_name_len}s  %-#{max_subdomain_len}s  PORT   DEV URL                           STATUS",
              'NAME', 'SUBDOMAIN')

  # Sites
  SITES.each do |site|
    status_parts = []
    icon = '✓'.green

    # Check git status
    git_status = site_git_status(site)
    if git_status == :dirty
      icon = '●'.yellow
      status_parts << 'dirty'.yellow
    elsif git_status == :clean
      status_parts << 'clean'.green
    else
      status_parts << 'unknown'.gray
    end

    # Check if built
    status_parts << if site_is_built?(site, BUILD_DIR)
                      'built'.blue
                    else
                      'not built'.gray
                    end

    # Check shared submodule
    unless site_has_shared?(site)
      icon = '⚠'.red
      status_parts << 'no shared'.red
    end

    # Format URL (truncate if too long)
    dev_url = "http://#{site.domain}"
    dev_url = "#{dev_url[0..31]}..." if dev_url.length > 34

    # Print row
    puts format("%-#{max_name_len}s  %-#{max_subdomain_len}s  %4d   %-34s %s %s",
                site.name,
                site.subdomain,
                site.port,
                dev_url,
                icon,
                status_parts.join(', '))
  end

  # Summary
  puts "\n#{'=== Summary ==='.cyan.bold}"

  total = SITES.length
  built_sites = SITES.select { |s| site_is_built?(s, BUILD_DIR) }
  built = built_sites.length
  dirty_sites = SITES.select { |s| site_git_status(s) == :dirty }
  dirty = dirty_sites.length
  clean = total - dirty

  puts "Total sites: #{total.to_s.bold}"

  if built.positive?
    built_names = built_sites.map(&:name).join(', ')
    puts "Built: #{built.to_s.blue} (#{built_names})"
  else
    puts "Built: #{'0'.blue}"
  end

  dirty_info = dirty.positive? ? " (#{dirty_sites.map(&:name).join(', ')})" : ''
  puts "Clean: #{clean.to_s.green} | Dirty: #{dirty.to_s.yellow}#{dirty_info}"

  if verbose
    # Additional info in verbose mode
    puts "\n#{'=== Usage ==='.cyan.bold}"
    puts "Dev server:   #{'rake serve what=<name>'.blue}"
    puts "Build:        #{'rake build what=<name>'.blue}"
    puts "Serve built:  #{'rake serve:build'.blue} (port 8080)"
  end
end
