module Jekyll
  require 'html_press'

  class SimpleLogger
    def error(msg)
      STDERR.puts(msg)
      raise FatalException.new("HtmlPress: #{msg}")
    end
  end

  class Page
    alias_method :html_press_orig_write, :write

    def write(dest)
      return if @dir == "/shared/layouts"
      do_press = @site.config["html_press"]["compress"]

      if self.html? and do_press then
        self.output = HtmlPress.press(self.output, {
          :strip_crlf => false,
          :logger => SimpleLogger.new
        })
      end
      html_press_orig_write(dest)
    end
  end

end