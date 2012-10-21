class SimpleLogger
  def error(msg)
    STDERR.puts(msg)
    raise FatalException.new("HtmlPress: #{msg}")
  end
end

module Jekyll
  require 'html_press'

  class Page
    alias_method :compressor_orig_write, :write

    def write(dest)
      puts "generating > #{destination(dest)}"
      do_press = @site.config["html_press"]["compress"]
      if self.html? and do_press then
        self.output = HtmlPress.press(self.output, {
          :strip_crlf => false,
          :logger => SimpleLogger.new
        })
      end
      compressor_orig_write(dest)
    end
  end

end