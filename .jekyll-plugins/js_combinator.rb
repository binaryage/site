# based on code from: https://github.com/lyoshenka/jekyll-js-minify-plugin
require 'closure-compiler' # https://github.com/documentcloud/closure-compiler

module Jekyll
  module JsCombinator
    
    class Page
      attr_accessor :dir
    end
    
    class CombinedJsFile < Jekyll::StaticFile
      attr_accessor :list, :minify
      
      def write(dest)
        dest_path = File.join(dest, @dir, @name)
  
        content = []
        @list.each do |thing|
          content << File.read(thing.path) if thing.kind_of?(Jekyll::StaticFile)
          content << thing.output if thing.kind_of?(Jekyll::Page)
        end
        
        # if there is missing semicolon at the end of some file, new line is a safe delimiter
        content = content.join("\n")
        
        FileUtils.mkdir_p(File.dirname(dest_path))
        begin
          content = Closure::Compiler.new.compile(content) if @minify
          File.open(dest_path, 'w') do |f|
            f.write(content)
          end
        rescue => e
          STDERR.puts "Closure Compiler Exception: #{e.message}"
        end

        true
      end
    end
    
    class CombinedJsGenerator < Jekyll::Generator
      safe true

      def generate(site)
        list_file = File.expand_path(File.join(site.source, site.config["combinejs"]["path"]))
        list_file_dir = File.dirname(list_file)
        list = File.read(list_file).split("\n")
        
        list.map! do |path|
          File.expand_path(File.join(list_file_dir, path+".js"))
        end
        
        removed_files = []
        
        # remove list from static files
        site.static_files.delete_if { |sf| sf.path == list_file }
        
        list.each do |file|
          found = false
          # remove listed file from static files (if present)
          site.static_files.each do |sf|
            if file == sf.path then
              site.static_files.delete(sf)
              removed_files << sf
              found = true
              break
            end
          end
          next if found
          # remove listed files from pages (if present)
          # note: some js files may be generated (coffeescript),
          #       that is why we have to go through pages
          site.pages.each do |page|
            if file == page.destination(site.source) then
              site.pages.delete(page)
              removed_files << page
              break
            end
          end
        end
        
        # something.list -> something.js (will contain final concatenated js files)
        name = File.basename(list_file, ".list") + ".js"
        destination = list_file_dir.sub(site.source, '')
        minified_file = CombinedJsFile.new(site, site.source, destination, name)
        minified_file.list = removed_files
        minified_file.minify = site.config["combinejs"]["minify"]
        site.static_files << minified_file
      end
    end

  end
end