require 'colored2'

require_relative 'utils.rb'
require_relative 'build.rb'

def prune_shared(dir)
  img_dir = File.join(dir, 'img')
  img2_dir = File.join(dir, 'img2')
  css_dir = File.join(dir, 'css')
  sys("rm -rf \"#{img2_dir}/overlay\"*")
  sys("rm -rf \"#{img2_dir}/asset\"*")
  sys("rm -rf \"#{img_dir}/overlay\"")
  sys("rm -rf \"#{img_dir}/scrollable\"")
  sys("rm -rf \"#{img_dir}/tabs\"")
  sys("rm -rf \"#{img_dir}/flags\"")
  sys("rm -rf \"#{img_dir}/icons\"")
  sys("rm -rf \"#{img_dir}/os/\"")
  sys("rm -rf \"#{css_dir}/nib\"")
  sys("rm \"#{css_dir}/\"syntax.css")
  sys("rm \"#{img_dir}/totalterminal-\"*")
  sys("rm \"#{img_dir}/totalfinder-\"*")
  sys("rm \"#{img_dir}/asepsis-\"*")
  sys("rm \"#{img_dir}/visor-\"*")
  sys("rm \"#{img_dir}/firequery-\"*")
  sys("rm \"#{img_dir}/drydrop-\"*")
  sys("rm \"#{img_dir}/xrefresh-\"*")
  sys("rm \"#{img_dir}/firelogger-\"*")
  sys("rm \"#{img_dir}/firepython-\"*")
  sys("rm \"#{img_dir}/firerainbow-\"*")
  sys("rm \"#{img_dir}/restatic-\"*")
  sys("rm \"#{img_dir}/firelogger4php-\"*")
  sys("rm \"#{img_dir}/osx\"*")
  sys("rm \"#{img_dir}/ffintro\"*")
  sys("rm \"#{img_dir}/about-photo\"*")
  sys("rm \"#{img_dir}/howto\"*")
  sys("rm \"#{img_dir}/nbair\"*")
  sys("rm \"#{img_dir}/matrix\"*")
  sys("rm \"#{img_dir}/chimp\"*")
end

def build_store(site, opts)
  # build the site using jekyll
  stage = opts[:stage]
  sys("rm -rf \"#{stage}\"")
  build_site(site, opts) # no cache busters, no cdn

  build_path = File.join(stage, site.name)
  template_path = File.join(build_path, (ENV['STORE_TEMPLATE'] or 'store-template.html'))
  working_dir = File.join(stage, '_storetemplate')
  window_template = "#{working_dir}/window.xhtml"

  # copy interesting parts
  sys("rm -rf \"#{working_dir}\"")
  sys("mkdir -p \"#{working_dir}\"")
  sys("cp -r \"#{build_path}/shared\" \"#{working_dir}\"")
  sys("cp \"#{template_path}\" \"#{window_template}\"")
  sys("cp \"#{build_path}/favicon.ico\" \"#{working_dir}\"")
  sys("cp \"#{build_path}/robots.txt\" \"#{working_dir}\"")

  # make our HTML valid XHTML
  patch(window_template, [
      ['<!DOCTYPE html>', ''],
      ['<html ', "<html xmlns=\"http://www.w3.org/1999/xhtml\"\n      "],
      [/<body(.*?)>/, "<body\\1><div id=\"page-store-template\">"],
      ['</body>', '</div></body>'],
      [/<script(.*?)>/, "<script\\1>//<![CDATA[\n"],
      [/<\/script>/, "\n//]]></script>"],
      [/href="\/([^\/])/, "href=\"\\1"],
      [/src="\/([^\/])/, "src=\"\\1"],
      ['&nbsp;', '&#160;'],
      ['&copy;', '&#169;'],
      ['##INSERT STORE CONTENT HERE##', "\n<!-- TemplateBeginEditable name=\"Content\" -->\n\n<!-- TemplateEndEditable -->"],
      ['</title>', "</title>\n<link title=\"main\" rel=\"stylesheet\" href=\"http://resource.fastspring.com/app/s/style/base.css\" media=\"screen,projection\" type=\"text/css\" />\n<link title=\"main\" rel=\"stylesheet\" href=\"http://resource.fastspring.com/app/store/style/base.css\" media=\"screen,projection\" type=\"text/css\" />"]
  ])

  content = File.read(window_template)
  content.gsub!(/<!-- SCRIPTS START -->(.*?)<!-- SCRIPTS END -->(.*?)<body(.*?)>/m, "\\2<body\\3>\\1")
  content.gsub!(/src="http:/m, "src=\"https:")

  File.open(window_template, 'w') do |f|
    f << content
  end

  # fix paths in CSS
  patch("#{working_dir}/shared/css/site.css", [
      [/\/shared\//, '../']
  ])

  # clean up shared folder to reduce size
  prune_shared("#{working_dir}/shared")

  # zip it!
  zip_path = opts[:zip_path]
  sys("rm \"#{zip_path}\"") if File.exists? zip_path
  Dir.chdir(working_dir) do
    sys("zip -r -du \"#{zip_path}\" .")
    sys("du -sh \"#{zip_path}\"")
  end

  # noinspection RubyResolve
  puts 'Store template is in ' + zip_path.yellow + '. ' + "Don't forget to upload it to FastSpring".green
end
