module HtmlPress

  class Html

    DEFAULTS = {
      :logger => false,
      :unquoted_attributes => false,
      :drop_empty_values => false,
      :strip_crlf => false,
      :js_minifier_options => false
    }

    def initialize (options = {})
      @options = DEFAULTS.merge(options)
      if @options.keys.include? :dump_empty_values
        @options[:drop_empty_values] = @options.delete(:dump_empty_values)
        warn "dump_empty_values deprecated use drop_empty_values"
      end
      if @options[:logger] && !@options[:logger].respond_to?(:error)
        raise ArgumentError, 'Logger has no error method'
      end
    end
    
    def extract_code_blocks(html)
      @code_blocks = []
      counter = 0
      html.gsub /<code>(.*?)<\/code>/mi do |_|
        counter+=1
        @code_blocks << $1
        "<code>##HTMLPRESSCODEBLOCK##</code>"
      end
    end

    def return_code_blocks(html)
      counter = 0
      html.gsub "##HTMLPRESSCODEBLOCK##" do |_|
        counter+=1
        @code_blocks[counter-1]
      end
    end

    def extract_pre_blocks(html)
      @pre_blocks = []
      counter = 0
      html.gsub /<pre>(.*?)<\/pre>/mi do |_|
        counter+=1
        @pre_blocks << $1
        "<pre>##HTMLPRESSPREBLOCK##</pre>"
      end
    end

    def return_pre_blocks(html)
      counter = 0
      html.gsub "##HTMLPRESSPREBLOCK##" do |_|
        counter+=1
        @pre_blocks[counter-1]
      end
    end

    def press (html)
      out = html.respond_to?(:read) ? html.read : html.dup

      out = extract_pre_blocks out
      out = extract_code_blocks out
      out.gsub! "\r", ''

      out = process_scripts out
      out = process_styles out

      out = process_html_comments out
      out = trim_lines out
      out = process_block_elements out
      out = process_whitespaces out

      out = process_attributes out
      out = fixup_void_elements out

      out.gsub! /^$\n/, '' # remove empty lines

      out = reindent out
      out = return_code_blocks out
      out = return_pre_blocks out
      out
    end

    # for backward compatibility
    alias :compile :press

    protected

    def reindent (out)
      level = 0
      in_script = 0
      in_style = 0
      in_code = 0
      in_pre = 0
      res = []
      out.split("\n").each do |line|
        pre_level = level

        line.gsub /<([\/]*[a-z\-:]+)([^>]*?)>/i do |m|
          in_code+=1 if $1 == "code"
          in_code-=1 if $1 == "/code"
          in_pre+=1 if $1 == "pre"
          in_pre-=1 if $1 == "/pre"
          if $1 == "script"
            level += 1
            in_script += 1
          end
          in_script -= 1 if $1 == "/script"
          if $1 == "style"
            level += 1
            in_style += 1
          end
          in_style -= 1 if $1 == "/style"

          next if m[1]=="!"
          next if m[-2]=="/"
          next if in_style > 0 or in_script > 0

          m[1]=="/" ? level -= 1 : level += 1
          level = 0 if level < 0
        end

        level < pre_level ? i = level : i = pre_level
        i = 0 if (in_code>0 or in_pre>0) and level <= pre_level
        res << (("  " * i) + line)
      end

      res.join("\n")
    end

    def process_attributes (out)
      out.gsub /<([a-z\-:]+)([^>]*?)([\/]*?)>/i do |_|
        "<"+$1+($2.gsub(/[\n]+/, ' ').gsub(/[ ]+/, ' ').rstrip)+">"
      end
    end

    def fixup_void_elements (out)
      # http://dev.w3.org/html5/spec/syntax.html#void-elements
      out.gsub /<(area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr|path|rect)([^>]*?)[\/]*>/i do |_|
        "<"+$1+$2+"/>"
      end
    end

    def process_scripts (out)
      out.gsub /(<script.*?>)(.*?)(<\/script>)/im do |_|
        pre = $1
        post = $3
        compressed_js = HtmlPress.js_compressor $2, @options[:js_minifier_options], @options[:cache]
        "#{pre}#{compressed_js}#{post}"
      end
    end

    def process_styles (out)
      out.gsub /(<style.*?>)(.*?)(<\/style>)/im do |_|
        pre = $1
        post = $3
        compressed_css = HtmlPress.style_compressor $2, @options[:cache]
        "#{pre}#{compressed_css}#{post}"
      end
    end
    
    # remove html comments (not IE conditional comments)
    def process_html_comments (out)
      out.gsub /<!--([ \t]*?)-->/, ''
    end

    # trim each line
    def trim_lines (out)
      out.gsub(/^[ \t]+|[ \t]+$/m, '')
    end

    # remove whitespaces outside of block elements
    def process_block_elements (out)
      re = '[ \t]+(<\\/?(?:area|base(?:font)?|blockquote|body' +
        '|caption|center|cite|col(?:group)?|dd|dir|div|dl|dt|fieldset|form' +
        '|frame(?:set)?|h[1-6]|head|hr|html|legend|li|link|map|menu|meta' +
        '|ol|opt(?:group|ion)|p|param|t(?:able|body|head|d|h|r|foot|itle)' +
        '|ul)\\b[^>]*>)'

      re = Regexp.new(re)
      out.gsub!(re, '\\1')

      # remove whitespaces outside of all elements
      out.gsub! />([^<]+)</ do |m|
        m.gsub(/^[ \t]+|[ \t]+$/, ' ')
      end

      out
    end

    # replace two or more whitespaces with one
    def process_whitespaces (out)
      out.gsub!(/[\r\n]+/, "\n")

      in_code = 0
      in_pre = 0
      res = []
      out.split("\n").each do |line|
        line.gsub /<([\/]*[a-z\-:]+)([^>]*?)>/i do |_|
          in_code+=1 if $1 == "code"
          in_code-=1 if $1 == "/code"
          in_pre+=1 if $1 == "pre"
          in_pre-=1 if $1 == "/pre"
        end

        line.gsub!(/[ \t]+/, ' ') unless in_code>0 or in_pre>0
        res << line
      end

      res.join("\n")
    end

    def log (text)
      @options[:logger].error text if @options[:logger]
    end

  end
end
