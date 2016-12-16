require_relative '_shared'

# noinspection RubyResolve
module Jekyll

  class Page
    alias_method :reshaper_orig_write, :write

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir =~ /shared\/root/
        @dir = @dir.gsub('shared/root', '')
        @url = nil
        new_path = destination(dest)
        if will_be_generated?(@site, self, dest, new_path)
          puts "#{'RESHAPER'.magenta} !skipped rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
          return # skip it, the file already exists in the repo at the root level
        else
          puts "#{'RESHAPER'.magenta} rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
        end
        self.output.gsub!(/shared\/root\//, '')
      end
      reshaper_orig_write dest
    end
  end

  class StaticFile
    alias_method :reshaper_orig_write, :write

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir =~ /shared\/root/
        orig_path = path
        @dir = @dir.gsub('shared/root', '')
        @url = nil
        new_path = destination(dest)
        if will_be_generated?(@site, self, dest, new_path)
          puts "#{'RESHAPER'.magenta} !skipped rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
          return # skip it, the file already exists in the repo at the root level
        else
          puts "#{'RESHAPER'.magenta} rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
        end
        FileUtils.mkdir_p(File.dirname(new_path))
        FileUtils.cp(orig_path, new_path)
        return
      end
      reshaper_orig_write dest
    end
  end

end

def remove_unwanted_content!(site)

  # remove some unwanted pages
  site.pages.delete_if do |page|
    path = page.destination(site.source)
    path =~ /shared\/layouts/ or path =~ /shared\/includes/
  end

  # remove some unwanted static files
  site.static_files.delete_if do |file|
    # stylus files should be generated into site.css
    # readme files are for github
    file.path =~ /shared\/includes/ or file.path =~ /\.styl$/ or file.path =~ /readme\./
  end

end
