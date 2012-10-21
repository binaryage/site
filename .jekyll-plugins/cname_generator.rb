def will_be_generated?(site, me, dest, path)
  return true if site.pages.any? {|f| f!=me and f.destination(dest) == path }
  return true if site.static_files.any? {|f| f!=me and f.destination(dest) == path }
  return false
end

module Jekyll

  class CnamePageGenerator < Generator
    safe true

    def generate(site)
      if will_be_generated?(site, nil, site.dest, File.join(site.dest, "CNAME")) then
        puts "!skipping generating CNAME"
        return
      end

      cname = site.config["url"].gsub("http://", "")
      cname_path = File.join(site.dest, "CNAME")
      puts "generating CNAME: #{cname}"
      FileUtils.mkdir_p(File.dirname(cname_path))
      File.open(cname_path, 'w') {|f| f.write(cname) }
    end

  end

end