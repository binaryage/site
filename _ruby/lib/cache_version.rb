require 'digest'
require 'fileutils'

module CacheVersion
  CACHE_VERSION_FILE = 'CACHE_VERSION'

  # Calculate SHA256 hash from all files that affect build output
  # Returns: String (64-char hex hash)
  def self.calculate_cache_version_hash
    # Get ROOT constant from config (or use current directory as fallback)
    root_dir = defined?(ROOT) ? ROOT : File.expand_path(File.join(File.dirname(__FILE__), '../..'))

    files_to_hash = []

    # Collect all plugin files
    plugins_dir = File.join(root_dir, '_ruby/jekyll-plugins')
    if Dir.exist?(plugins_dir)
      files_to_hash += Dir.glob(File.join(plugins_dir, '**', '*.rb')).sort
    end

    # Collect all lib files
    lib_dir = File.join(root_dir, '_ruby/lib')
    if Dir.exist?(lib_dir)
      files_to_hash += Dir.glob(File.join(lib_dir, '**', '*.rb')).sort
    end

    # Add dependency lock files
    gemfile_lock = File.join(root_dir, '_ruby/Gemfile.lock')
    files_to_hash << gemfile_lock if File.exist?(gemfile_lock)

    package_lock = File.join(root_dir, '_node', 'package-lock.json')
    files_to_hash << package_lock if File.exist?(package_lock)

    # Calculate combined hash
    hasher = Digest::SHA256.new

    files_to_hash.each do |file|
      # Include file path and content in hash
      hasher.update(file)
      hasher.update(File.read(file)) if File.exist?(file)
    end

    hasher.hexdigest
  end

  # Read stored cache version from cache directory
  # Returns: String (hash) or nil if not found
  def self.read_stored_cache_version(cache_dir)
    version_file = File.join(cache_dir, CACHE_VERSION_FILE)
    return nil unless File.exist?(version_file)

    File.read(version_file).strip
  end

  # Write cache version to cache directory
  def self.write_cache_version(cache_dir, hash)
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    version_file = File.join(cache_dir, CACHE_VERSION_FILE)
    File.write(version_file, hash)
  end

  # Check if cache is valid for given cache directory
  # Returns: Boolean
  def self.cache_valid?(cache_dir)
    return false unless Dir.exist?(cache_dir)

    current_hash = calculate_cache_version_hash
    stored_hash = read_stored_cache_version(cache_dir)

    return false if stored_hash.nil?

    current_hash == stored_hash
  end

  # Invalidate and delete all cache directories
  # Parameters:
  #   custom_cache_dir - Optional path to additional cache directory (e.g., from custom stage path)
  # Returns: Array of deleted directories
  def self.invalidate_all_caches(custom_cache_dir = nil)
    root_dir = defined?(ROOT) ? ROOT : File.expand_path(File.join(File.dirname(__FILE__), '../..'))
    deleted = []

    # Clean custom cache directory (e.g., from hookgun with custom stage path)
    if custom_cache_dir && Dir.exist?(custom_cache_dir)
      FileUtils.rm_rf(custom_cache_dir)
      deleted << custom_cache_dir
    end

    # Clean build cache
    build_cache = File.join(root_dir, '.stage', 'build', '_cache')
    if Dir.exist?(build_cache)
      FileUtils.rm_rf(build_cache)
      deleted << build_cache
    end

    # Clean serve cache
    serve_cache = File.join(root_dir, '.stage', 'serve', '_cache')
    if Dir.exist?(serve_cache)
      FileUtils.rm_rf(serve_cache)
      deleted << serve_cache
    end

    # Clean old Jekyll caches in site submodules (for migration/cleanup)
    # Note: New builds use centralized cache in .stage/{build|serve}/_cache/jekyll/
    if defined?(SITES)
      SITES.each do |site|
        jekyll_cache = File.join(site.dir, '.jekyll-cache')
        if Dir.exist?(jekyll_cache)
          FileUtils.rm_rf(jekyll_cache)
          deleted << jekyll_cache
        end
      end
    end

    deleted
  end

  # Check cache validity and invalidate if needed
  # Returns: Hash with status info
  def self.check_and_invalidate_if_needed(cache_dir, logger: method(:puts))
    root_dir = defined?(ROOT) ? ROOT : File.expand_path(File.join(File.dirname(__FILE__), '../..'))
    current_hash = calculate_cache_version_hash
    stored_hash = read_stored_cache_version(cache_dir)

    if stored_hash.nil?
      logger.call "⚠️  No cache version found - invalidating existing cache"

      deleted = invalidate_all_caches(cache_dir)

      deleted.each do |dir|
        logger.call "   🗑️  Deleted: #{dir.sub(root_dir + '/', '')}"
      end

      # Write new cache version to all cache directories after cleaning
      [File.join(root_dir, '.stage', 'build', '_cache'),
       File.join(root_dir, '.stage', 'serve', '_cache'),
       cache_dir].uniq.each do |dir|
        write_cache_version(dir, current_hash)
      end

      return { valid: false, reason: :no_version, deleted: deleted }
    end

    if current_hash == stored_hash
      logger.call "✅ Cache is valid (version: #{current_hash[0..7]})"
      return { valid: true, reason: nil, deleted: [] }
    end

    # Cache is invalid - need to clean
    logger.call "⚠️  Cache invalidated - plugins/dependencies changed"
    logger.call "   Old version: #{stored_hash[0..7]}"
    logger.call "   New version: #{current_hash[0..7]}"

    deleted = invalidate_all_caches(cache_dir)

    deleted.each do |dir|
      logger.call "   🗑️  Deleted: #{dir.sub(root_dir + '/', '')}"
    end

    # Write new version to all cache directories
    [File.join(root_dir, '.stage', 'build', '_cache'),
     File.join(root_dir, '.stage', 'serve', '_cache'),
     cache_dir].uniq.each do |dir|
      write_cache_version(dir, current_hash)
    end

    { valid: false, reason: :version_mismatch, deleted: deleted }
  end
end
