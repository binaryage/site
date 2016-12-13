def will_be_generated?(site, me, dest, path)
  return true if site.pages.any? { |f| f!=me and f.destination(dest) == path }
  return true if site.static_files.any? { |f| f!=me and f.destination(dest) == path }
  false
end

module Jekyll

  # noinspection RubyResolve
  class Site
    alias_method :cname_orig_cleanup, :cleanup

    def cleanup
      cname_orig_cleanup

      if will_be_generated?(self, nil, @dest, File.join(@dest, 'CNAME'))
        puts "#{'CNAME   '.magenta} !skipping generating CNAME"
        return
      end

      cname = @config['cname'] || 'stage.'+@config['target_url'].gsub('http://', '').gsub('https://', '')
      cname_path = File.join(@dest, 'CNAME')
      puts "\n#{'CNAME   '.magenta} generating #{cname.green}"
      FileUtils.mkdir_p(File.dirname(cname_path))
      File.open(cname_path, 'w') { |f| f.write(cname) }
    end
  end

end
