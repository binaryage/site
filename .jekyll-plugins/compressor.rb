require 'colored2'
require 'pathname'

class SimpleLogger
  def error(msg)
    STDERR.puts(msg)
    raise FatalException.new("HtmlPress: #{msg}")
  end
end

def nice_cache_hit(full_path)
  Pathname.new(full_path).relative_path_from(Pathname.new File.join(Dir.pwd, '..')).to_s
end

module Jekyll
  require 'html_press'

  # noinspection RubyResolve,RubyResolve
  class Page
    alias_method :compressor_orig_write, :write

    def write(dest)
      do_press = @site.config['html_press']['compress']
      my_cache_dir = nil
      cache_hit = nil
      if self.html? and do_press
        print "#{'COMPRESS'.magenta} generating #{destination(dest).yellow} "
        res = nil
        cache_dir = @site.config['html_press']['cache']
        if cache_dir
          my_cache_dir = File.join(cache_dir, 'html')
          sha = Digest::SHA1.hexdigest self.output
          cache_hit = File.join(my_cache_dir, sha)
          if File.exists? cache_hit
            print "<= cache @ #{nice_cache_hit(cache_hit).green}"
            res = File.read(cache_hit)
          end
        end
        unless res
          print '=> pressing'
          res = HtmlPress.press(self.output, {
              :strip_crlf => false,
              :logger => SimpleLogger.new,
              :cache => cache_dir
          })
        end
        if cache_hit and not File.exists? cache_hit
          print " @ #{nice_cache_hit(cache_hit).red}"
          FileUtils.mkdir_p(my_cache_dir)
          File.open(cache_hit, 'w') { |f| f.write(res) }
        end
        self.output = res
        print "\n"
      end
      compressor_orig_write(dest)
    end
  end

end
