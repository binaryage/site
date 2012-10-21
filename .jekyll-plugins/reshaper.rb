def will_be_generated?(site, me, dest, path)
  return true if site.pages.any? {|f| f!=me and f.destination(dest) == path }
  return true if site.static_files.any? {|f| f!=me and f.destination(dest) == path }
  return false
end

module Jekyll
  class Site
    alias_method :reshaper_orig_cleanup, :cleanup

    # site processing steps:
    #
    # def process
    #   self.reset
    #   self.read
    #   self.generate
    #   self.render
    #   self.cleanup
    #   self.write
    # end
    #
    def cleanup
      reshaper_orig_cleanup

      # remove some unwanted pages
      pages.delete_if do |page|
        path = page.destination(source)
        path =~ /shared\/layouts/ or
        path =~ /shared\/includes/
      end

      # remove some unwanted static files
      static_files.delete_if do |file|
        file.path =~ /shared\/includes/ or
        file.path =~ /\.styl$/ or # stylus files should be generated into site.css
        file.path =~ /readme\./ # readme files are for github
      end

    end
  end

  class Page
    alias_method :reshaper_orig_write, :write

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir =~ /shared\/root/ then
        @dir = @dir.gsub("shared/root", "")
        new_path = destination(dest)
        if will_be_generated?(site, self, dest, new_path)  then
          puts "skipped rewriting /shared/root/#{@name} -> #{new_path}"
          return # skip it, the file already exists in the repo at the root level
        end
        puts "rewriting /shared/root/#{@name} -> #{new_path}"
      end
      reshaper_orig_write dest
    end
  end

  class StaticFile
    alias_method :reshaper_orig_write, :write
    attr_accessor :site

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir =~ /shared\/root/ then
        orig_path = path
        @dir = @dir.gsub("shared/root", "")
        new_path = destination(dest)
        if will_be_generated?(site, self, dest, new_path) then
          puts "rewriting skipped /shared/root/#{@name} -> #{new_path}"
          return # skip it, the file already exists in the repo at the root level
        end
        puts "rewriting /shared/root/#{@name} -> #{new_path}"
        FileUtils.mkdir_p(File.dirname(new_path))
        FileUtils.cp(orig_path, new_path)
        return
      end
      reshaper_orig_write dest
    end
  end

end