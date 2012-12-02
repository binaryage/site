require 'digest/sha1'

module Jekyll

  class Site

    alias_method :busterizer_process, :process

    def generate_buster file
      return if not File.exists? file
      return if File.directory? file
      sha = Digest::SHA1.hexdigest File.read(file)
      sha[0..7]
    end

    def cache_busting(m, dir, m1, m2, m3)
      return m if m1[0..4]=="http"
      return m if m2.nil? or m2=="/" or m2==""
      m2 = m2.split("?")[0]
      if m2[0] == "/" then
        file = File.join(self.dest, m2)
      else
        file = File.join(dir, m2)
      end
      buster = generate_buster(file)
      return m if buster.nil?
      m1 + m2 + "?#{buster}" + m3
    end

    def busterize_file(path)
      puts "#{"BUSTER  ".magenta} adding cache busters to #{path.yellow}"

      dir = File.dirname(path)

      content = File.read(path)

      # css
      content.gsub!(/(url\(")(.*?)("\))/) do |m|
        cache_busting m, dir, $1, $2, $3
      end

      # html
      content.gsub!(/(src=")(.*?)(")/) do |m|
        cache_busting m, dir, $1, $2, $3
      end
      content.gsub!(/(href=")(.*?)(")/) do |m|
        cache_busting m, dir, $1, $2, $3
      end

      File.open(path, 'w') {|f| f.write(content) }
    end

    def busterize_site
      busterization_list = []
      self.posts.each do |post|
        busterization_list << post.destination(self.dest)
      end
      self.pages.each do |page|
        busterization_list << page.destination(self.dest)
      end

      busterization_list.sort! do |a, b|
        ea = File.extname a
        eb = File.extname b
        ia = ea == ".css" ? 0 : 1
        ib = eb == ".css" ? 0 : 1
        ia <=> ib
      end

      busterization_list.each do |path|
        ext = File.extname path
        if config["busterizer"][ext[1..-1]] then
          busterize_file path
        end
      end
    end

    def process
      busterizer_process
      busterize_site
    end

  end

end