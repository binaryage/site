module Jekyll

  class BaseIncludeTag < Liquid::Tag
    def initialize(tag_name, file, tokens)
      super
      @file = file.strip
    end

    def render(context)
      includes_dir = File.join(context.registers[:site].source, 'shared', 'includes')

      if File.symlink?(includes_dir)
        return "Includes directory '#{includes_dir}' cannot be a symlink"
      end

      if @file !~ /^[a-zA-Z0-9_\/.-]+$/ || @file =~ /\.\// || @file =~ /\/\./
        return "Include file '#{@file}' contains invalid characters or sequences"
      end

      Dir.chdir(includes_dir) do
        choices = Dir['**/*'].reject { |x| File.symlink?(x) }
        if choices.include?(@file)
          source = File.read(@file) + "\n"
          partial = Liquid::Template.parse(source)
          context.stack do
            partial.render(context)
          end
        else
          "Included file '#{@file}' not found in shared/includes directory"
        end
      end
    end
  end

end

Liquid::Template.register_tag('base_include', Jekyll::BaseIncludeTag)
