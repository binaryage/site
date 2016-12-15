# based on code from: https://github.com/lyoshenka/jekyll-js-minify-plugin
require 'closure-compiler' # https://github.com/documentcloud/closure-compiler
require 'colored2'

module Jekyll
  module JsCombinator

    class CombinedJsFile < Jekyll::StaticFile
      attr_accessor :list, :minify

      # noinspection RubyResolve
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
          if @minify
            print "#{'COMBINE '.magenta} minifying #{dest_path.yellow} "
            res = nil
            cache_hit = nil
            my_cache_dir = nil
            cache_dir = @site.config['html_press']['cache']
            if cache_dir
              my_cache_dir = File.join(cache_dir, 'list')
              sha = Digest::SHA1.hexdigest content
              cache_hit = File.join(my_cache_dir, sha)
              if File.exists? cache_hit
                print "<= cache @ #{relative_cache_file_path(cache_hit).green}"
                res = File.read(cache_hit)
              end
            end
            unless res
              print '=> compiling'
              res = Closure::Compiler.new.compile(content)
            end
            if cache_hit and not File.exists? cache_hit
              print " @ #{relative_cache_file_path(cache_hit).red}"
              FileUtils.mkdir_p(my_cache_dir)
              File.open(cache_hit, 'w') { |f| f.write(res) }
            end
            print "\n"
            content = res
          end

          File.open(dest_path, 'w') do |f|
            f.write(content)
          end
        rescue => e
          STDERR.puts "Closure Compiler Exception: #{e.message}"
          raise FatalException.new("Closure Compiler: #{e.message}")
        end

        true
      end
    end

    class CombinedJsGenerator < Jekyll::Generator
      safe true

      def generate(site)
        list_file = File.expand_path(File.join(site.source, site.config['combinejs']['path']))
        list_file_dir = File.dirname(list_file)
        list = File.read(list_file).split("\n")

        # reject commented-out lines and empty lines
        list.reject! do |path|
          path =~ /^\s*#/ or path =~ /^\s*$/
        end

        list.map! do |path|
          File.expand_path(File.join(list_file_dir, path+'.js'))
        end

        removed_files = []

        # remove list from static files
        site.static_files.delete_if { |sf| sf.path == list_file }

        list.each do |file|
          next if file.strip.empty?
          found = false
          # remove listed file from static files (if present)
          site.static_files.each do |sf|
            if file == sf.path
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
            if page.destination(site.source).end_with? file
              site.pages.delete(page)
              # we need to pre-render the page, generate step goes prior page generation
              page.render(site.layouts, site.site_payload)
              removed_files << page
              break
            end
          end
        end

        # something.list -> something.js (will contain final concatenated js files)
        name = File.basename(list_file, '.list') + '.js'
        destination = list_file_dir.sub(site.source, '')
        minified_file = CombinedJsFile.new(site, site.source, destination, name)
        minified_file.list = removed_files
        minified_file.minify = site.config['combinejs']['minify']
        site.static_files << minified_file
      end
    end

  end
end
