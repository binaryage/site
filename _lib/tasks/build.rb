# frozen_string_literal: true

desc 'build site'
task :build do
  what = (ENV['what'] || sites_subdomains(SITES).join(','))
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

desc 'inspect the list of sites currently registered'
task :inspect do
  puts SITES
end
