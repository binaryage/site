# frozen_string_literal: true

require_relative '_shared'

# noinspection RubyResolve
module Jekyll
  class Page
    alias reshaper_orig_write write

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir.match?(/shared\/root/)
        @dir = @dir.gsub('shared/root', '')
        @url = nil
        @destination = nil # reset memoized destination in https://github.com/jekyll/jekyll/commit/920c6f4ddcb47399080204543efebbaa1ca4856d
        new_path = destination(dest)
        if will_be_generated?(@site, self, dest, new_path)
          puts "#{'RESHAPER'.magenta} !skipped rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
          return # skip it, the file already exists in the repo at the root level
        else
          puts "#{'RESHAPER'.magenta} rewriting #{"/shared/root/#{@name}".yellow} -> #{new_path.yellow}"
        end
        output.gsub!(/shared\/root\//, '')
      end
      reshaper_orig_write dest
    end
  end

  class StaticFile
    alias reshaper_orig_write write

    def write(dest)
      # rewrite some paths /shared/root -> /
      # see readme in https://github.com/binaryage/site
      if @dir.match?(/shared\/root/)
        orig_path = path
        @dir = @dir.gsub('shared/root', '')
        @url = nil
        @relative_path = File.join(*[@dir, @name].compact)
        @cleaned_relative_path = nil
        @destination = nil # reset memoized destination in https://github.com/jekyll/jekyll/commit/920c6f4ddcb47399080204543efebbaa1ca4856d
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
    path =~ /shared\/layouts/ || path =~ /shared\/includes/
  end

  # remove some unwanted static files
  site.static_files.delete_if do |file|
    # stylus files should be generated into site.css
    # readme files are for github
    file.path =~ /shared\/includes/ || file.path =~ /\.styl$/ || file.path =~ /readme\./
  end
end
