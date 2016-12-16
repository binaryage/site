require_relative '_shared'

def remove_unwanted_files!(site)
  if site.config['prune_files']
    site.config['prune_files'].each do |path|
      absolute_path = File.join(site.dest, path)
      puts "#{'PRUNER'.magenta} removing #{absolute_path.yellow}"
      FileUtils.rm(absolute_path)
    end
  end
end

Jekyll::Hooks.register(:site, :post_write) do |site|
  remove_unwanted_files!(site)
end
