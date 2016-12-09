module Jekyll

  # even years after my attempt[1] to make Jekyll smarter about what it spits out, it is still insufficient
  # this hack is needed for browser-sync [2]
  #
  # [1] https://github.com/jekyll/jekyll/commit/f91954be7635fe2354c11d45981d5c0045f22010
  # [2] https://github.com/BrowserSync/browser-sync
  class Regenerator
    attr_reader :site
    alias_method :silencer_orig_regenerate?, :regenerate?

    def regenerate?(item)
      unless silencer_orig_regenerate?(item)
        return false # early exit
      end

      if item.respond_to?(:destination)
        path = item.destination(@site.dest)
        begin
          if File.exists?(path) and File.size(path) == item.output.size and File.read(path)==item.output
            puts "Jekyll silencer: skipping write to #{path.blue} (same content)"
            return false
          end
        rescue
          # ignored
        end
      end

      true
    end
  end

end
