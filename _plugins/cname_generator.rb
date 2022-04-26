# frozen_string_literal: true

require_relative '_shared'

def generate_cname_file!(site)
  if will_be_generated?(site, nil, site.dest, File.join(site.dest, 'CNAME'))
    puts "#{'CNAME   '.magenta} !skipping CNAME generated by jekyll"
    return
  end

  cname = site.config['cname'] || "stage.#{site.config['target_url'].gsub('http://', '').gsub('https://', '')}"
  cname_path = File.join(site.dest, 'CNAME')
  puts "#{'CNAME   '.magenta} generating #{cname.green} in #{cname_path.yellow}"
  FileUtils.mkdir_p(File.dirname(cname_path))
  File.write(cname_path, cname)
end
