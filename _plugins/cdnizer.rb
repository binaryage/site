require 'digest/sha1'
require 'json'
require 'open3'

module Jekyll

  # noinspection RubyResolve
  class Site

    alias_method :cdnizer_process, :process

    def flat_name(path)
      path = path[1..-1] if path[0] == '/'
      path.gsub(/[\/]/, '_').gsub('.._', '_')
    end

    def generate_hash(file)
      return unless File.exists? file
      return if File.directory? file
      sha = Digest::SHA1.hexdigest File.read(file)
      sha[0..7]
    end

    def copy_into_zone(file_path, flat_name)
      zone_dir = config['static_cdn']['zone']
      FileUtils.mkdir_p(zone_dir)
      zone_file = File.join(zone_dir, flat_name)
      return if File.exists? zone_file
      FileUtils.cp(file_path, zone_file)
      puts "#{'STATIC CDN     '.magenta} copied #{file_path.yellow} -> #{zone_file.yellow}"
    end

    def cdnize_fragment(m, dir, m1, m2, m3)
      return m if m2[0..3]=='http'
      return m if m2[0..1]=='//'
      return m if m2.nil? or m2=='/' or m2==''
      m2 = m2.split('?')[0]
      if m2[0] == '/'
        file = File.join(self.dest, m2)
      else
        file = File.join(dir, m2)
      end
      hash = generate_hash(file)
      return m if hash.nil?
      flat = "#{hash}_#{flat_name(m2)}".gsub(/_+/, '_')
      copy_into_zone(file, flat)
      m1 + config['static_cdn']['url'] + flat + m3
    end

    def cdnize_file(path)
      return unless File.exists? path # some files could be deleted by pruner
      puts "#{'STATIC CDN     '.magenta} redirecting asset urls in #{path.yellow} to #{(config['static_cdn']['url']).green}"

      content = File.read(path)
      dir = File.dirname(path)

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

      File.open(path, 'w') { |f| f.write(content) }
    end

    def prepare_static_zone!
      cdnization_list = []
      self.posts.docs.each do |post|
        cdnization_list << post.destination(self.dest)
      end
      self.pages.each do |page|
        cdnization_list << page.destination(self.dest)
      end

      cdnization_list.sort! do |a, b|
        ea = File.extname a
        eb = File.extname b
        ia = ea == '.css' ? 0 : 1
        ib = eb == '.css' ? 0 : 1
        ia <=> ib
      end

      cdnization_list.each do |path|
        cdnize_file path
      end
    end

    def clean_static_zone!
      zone_dir = config['static_cdn']['zone']
      raise Jekyll::Errors::FatalException.new("CDN error: specify config['static_cdn']['zone']") unless zone_dir
      list = Dir.glob(File.join(zone_dir, '*'))
      puts "#{'STATIC CDN     '.magenta} cleaning #{"#{list.size} files".green} in zone folder: #{zone_dir.yellow}"
      FileUtils.rm(list)
    end

    def push_static_zone_to_cdn!
      push_url = config['static_cdn']['push_url'] # "user_xxx@push-1.cdn77.com:/www/"
      unless push_url
        puts "set jekyll config['static_cdn']['push_url']".red
        puts '  => skipping STATIC CDN push'
        return
      end
      zone_dir = File.join(config['static_cdn']['zone'], '') # ensures trailing slash
      puts "#{'STATIC CDN     '.magenta} pushing zone files to STATIC CDN...".blue
      cmd = "rsync -va --ignore-existing -e \"ssh -o StrictHostKeyChecking=no\" \"#{zone_dir}\" \"#{push_url}\""
      unless ENV['HUB_SERVER']
        puts 'set ENV variable HUB_SERVER=1 for pushing to STATIC CDN'.red
        puts "would execute: #{cmd.blue}"
        return
      end
      puts "> #{cmd.blue}"
      unless system(cmd)
        raise Jekyll::Errors::FatalException.new("rsync failed with code #{$?}")
      end
    end

    def push_to_cdn!(generated_web_dir)
      push_url = config['cdn']['push_url'] # "user_xxx@push-1.cdn77.com:/www/"
      unless push_url
        puts "set jekyll config['cdn']['push_url']".red
        puts '  => skipping CDN push'
        return
      end
      zone_dir = File.join(generated_web_dir, '') # ensures trailing slash
      puts "#{'CDN     '.magenta} pushing zone files to CDN...".blue
      cmd = "rsync -va --ignore-existing -e \"ssh -o StrictHostKeyChecking=no\" \"#{zone_dir}\" \"#{push_url}\""
      unless ENV['HUB_SERVER']
        puts 'set ENV variable HUB_SERVER=1 for pushing to CDN'.red
        puts "would execute: #{cmd.blue}"
        return
      end
      puts "> #{cmd.blue}"
      unless system(cmd)
        raise Jekyll::Errors::FatalException.new("rsync failed with code #{$?}")
      end
    end

    def target_url_to_stage(target_url)
      'stage.'+target_url.gsub('http://', '').gsub('https://', '')
    end

    def retrieve_cnd_id(api_login, api_password, target_url)
      cmd ="curl \"https://api.cdn77.com/v2.0/cdn-resource/list?login=#{api_login}&passwd=#{api_password}\""
      puts "> #{cmd.blue}"
      json_string = Open3.popen3(cmd) { |_stdin, stdout, _stderr, _wait_thr| stdout.read }
      unless $? == 0
        raise Jekyll::Errors::FatalException.new("curl failed with code #{$?}")
      end
      stage = target_url_to_stage(target_url)
      begin
        data = JSON.parse(json_string)
        resource = data['cdnResources'].find { |item| item['origin_url'] == stage }
        resource['id']
      rescue => e
        STDERR.puts "Unable to parse JSON data: #{e.message}\n\n#{json_string}"
        raise Jekyll::Errors::FatalException.new("Unable to parse JSON data: #{e.message}\n\n#{json_string}")
      end
    end

    def purge_cdn!
      # see https://client.cdn77.com/support/api/version/2.0/data

      unless ENV['HUB_SERVER']
        puts 'set ENV variable HUB_SERVER=1 for purging CDN'.red
        return
      end

      api_login = ENV['CDN77_API_LOGIN']
      api_password = ENV['CDN77_API_PASSWORD']
      if api_login and api_password
        cdn_id = retrieve_cnd_id(api_login, api_password, @config['target_url'])
        puts "#{'CDN     '.magenta} purging CDN(ID=#{cdn_id}) ...".blue
        cmd = "curl --data \"cdn_id=#{cdn_id}&login=#{api_login}&passwd=#{api_password}\" https://api.cdn77.com/v2.0/data/purge-all"
        puts "> #{cmd.blue}"
        unless system(cmd)
          raise Jekyll::Errors::FatalException.new("curl failed with code #{$?}")
        end
      else
        puts 'set ENV variables CDN77_API_LOGIN and CDN77_API_PASSWORD for purging CDN'.red
        puts '  => https://client.cdn77.com/support/api/version/2.0/data'
      end
    end

    def process
      cdnizer_process # call original process method

      # note cdn is not used at this moment, we mirror gh-pages
      if config['cdn'] and config['cdn']['enabled']
        push_to_cdn!(dest)
      end

      if config['static_cdn'] and config['static_cdn']['enabled']
        clean_static_zone!
        prepare_static_zone!
        push_static_zone_to_cdn!
      end

      purge_cdn! if config['purge_cdn']
    end

  end

end
