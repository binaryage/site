def will_be_generated?(site, me, dest, path)
  return true if site.pages.any? { |f| f!=me and f.destination(dest) == path }
  return true if site.static_files.any? { |f| f!=me and f.destination(dest) == path }
  false
end

def generate_cname_file!(site)
  if will_be_generated?(site, nil, site.dest, File.join(site.dest, 'CNAME'))
    puts "#{'CNAME   '.magenta} !skipping CNAME generated by jekyll"
    return
  end

  cname = site.config['cname'] || 'stage.'+site.config['target_url'].gsub('http://', '').gsub('https://', '')
  cname_path = File.join(site.dest, 'CNAME')
  puts "#{'CNAME   '.magenta} generating #{cname.green} in #{cname_path}"
  FileUtils.mkdir_p(File.dirname(cname_path))
  File.open(cname_path, 'w') { |f| f.write(cname) }
end

Jekyll::Hooks.register(:site, :post_write) do |site|
  generate_cname_file!(site)
end
