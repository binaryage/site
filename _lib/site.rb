require_relative 'utils.rb'

class Site
  attr_reader :dir, :port, :name, :subdomain, :domain

  def initialize(dir, port, domain)
    @dir = dir
    @port = port
    @name = extract_name(dir)
    @subdomain = extract_subdomain(dir)
    @domain = @subdomain+'.'+domain
  end

  def to_s
    self.inspect
  end

  private
  # "some/path/to/repo" => "repo"
  def extract_name(path)
    path.split('/').last # get last component of the path
  end

  # "totalfinder-web" => "totalfinder"
  def extract_subdomain(path)
    extract_name(path).split('-')[0] # strips -web postfixes
  end

end
