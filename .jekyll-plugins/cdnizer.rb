require 'digest/sha1'

module Jekyll

  class Site

    alias_method :cdnizer_process, :process

    def flat_name(path)
      path = path[1..-1] if path[0] == "/"
      path.gsub(/[\/\.]/, "_")
    end

    def generate_hash file
      return if not File.exists? file
      return if File.directory? file
      sha = Digest::SHA1.hexdigest File.read(file)
      sha[0..7]
    end

    def copy_into_zone(file_path, flat_name)
      zone_dir = config["cdn"]["zone"]
      FileUtils.mkdir_p(zone_dir)
      zone_file = File.join(zone_dir, flat_name)
      return if File.exists? zone_file
      FileUtils.cp(file_path, zone_file)
      puts "#{"CDN     ".magenta} copied #{file_path.yellow} -> #{zone_file.yellow}"
    end

    def cdnize_fragment(m, dir, m1, m2, m3)
      return m if m2[0..3]=="http"
      return m if m2[0..1]=="//"
      return m if m2.nil? or m2=="/" or m2==""
      m2 = m2.split("?")[0]
      if m2[0] == "/" then
        file = File.join(self.dest, m2)
      else
        file = File.join(dir, m2)
      end
      hash = generate_hash(file)
      return m if hash.nil?
      flat = "#{hash}_#{flat_name(m2)}".gsub(/_+/, "_")
      copy_into_zone(file, flat)
      m1 + config["cdn"]["url"] + flat + m3
    end

    def cdnize_file(path)
      puts "#{"CDN     ".magenta} redirecting asset urls in #{path.yellow} to #{(config["cdn"]["url"]).green}"

      dir = File.dirname(path)

      content = File.read(path)

      # css
      content.gsub!(/(url\(["'])(.*?)(["']\))/) do |m|
        cdnize_fragment m, dir, $1, $2, $3
      end

      # html
      content.gsub!(/(src=["'])(.*?)(["'])/) do |m|
        cdnize_fragment m, dir, $1, $2, $3
      end
      content.gsub!(/(href=["'])(.*?)(["'])/) do |m|
        cdnize_fragment m, dir, $1, $2, $3
      end

      File.open(path, 'w') {|f| f.write(content) }
    end

    def cdnize_site!
      cdnization_list = []
      self.posts.each do |post|
        cdnization_list << post.destination(self.dest)
      end
      self.pages.each do |page|
        cdnization_list << page.destination(self.dest)
      end

      cdnization_list.sort! do |a, b|
        ea = File.extname a
        eb = File.extname b
        ia = ea == ".css" ? 0 : 1
        ib = eb == ".css" ? 0 : 1
        ia <=> ib
      end

      cdnization_list.each do |path|
        cdnize_file path
      end
    end

    def cdnizer_clean_zone!
      zone_dir = config["cdn"]["zone"]
      raise FatalException.new("CDN error: specify config[\"cdn\"][\"zone\"]") unless zone_dir
      list = Dir.glob(File.join(zone_dir, "*"))
      puts "#{"CDN     ".magenta} cleaning #{"#{list.size} files".green} in zone folder: #{zone_dir.yellow}"
      FileUtils.rm(list)
    end

    def push_zone_to_cdn_via_rsync!
      url = ENV["CDN_RSYNC_URL"] # "rsync://user_ho054rw1@push-1.cdn77.com/user_ho054rw1/"
      password = ENV["CDN_RSYNC_PASSWORD"]
      unless (url and password)
        puts "set ENV variables CDN_RSYNC_URL and CDN_RSYNC_PASSWORD".red
        puts "  => skipping CDN push"
        return
      end
      zone_dir = config["cdn"]["zone"]
      puts "#{"CDN     ".magenta} pushing zone files to CDN...".blue
      Dir.chdir zone_dir do
        ENV["RSYNC_PASSWORD"] = password
        cmd = "sshpass -p \"#{password}\" rsync -va --ignore-existing -e \"ssh -o StrictHostKeyChecking=no\" . #{url}"
        unless system(cmd) then
          raise FatalException.new("rsync failed with code #{$?}")
        end
      end
    end

    def push_zone_to_cdn_via_ftp!
      url = ENV["CDN_FTP_URL"]
      user = ENV["CDN_FTP_USER"]
      password = ENV["CDN_FTP_PASSWORD"]
      path = ENV["CDN_FTP_PATH"]
      unless (url and password and user and path)
        puts "set ENV variables CDN_FTP_URL and CDN_FTP_USER and CDN_FTP_PASSWORD and CDN_FTP_PATH".red
        puts "  => skipping CDN push"
        return
      end
      zone_dir = config["cdn"]["zone"]
      puts "#{"CDN     ".magenta} pushing zone files to CDN...".blue
      Dir.chdir zone_dir do
        cmd = "ncftpput -R -v -u \"#{user}\" -p \"#{password}\" #{url} #{path} ."
        unless system(cmd) then
          raise FatalException.new("ncftpput failed with code #{$?}")
        end
      end
    end

    def process
      cdnizer_process # call original process method
      return unless config["cdn"]["enabled"]
      cdnizer_clean_zone!
      cdnize_site!
      push_zone_to_cdn_via_rsync!
      # push_zone_to_cdn_via_ftp!
    end

  end

end