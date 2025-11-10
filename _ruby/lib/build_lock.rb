# frozen_string_literal: true

require 'fileutils'

# BuildLock provides process-level locking to prevent concurrent builds
# in the same stage directory (e.g., .stage/build or .stage/serve).
#
# Usage:
#   lock = BuildLock.new('/path/to/stage')
#   lock.acquire!  # Raises error if lock cannot be acquired
#   begin
#     # ... do build work ...
#   ensure
#     lock.release
#   end
#
# The lock is automatically released when:
# - Process exits normally (ensure block)
# - Process crashes (OS releases flock)
# - Process is killed (OS releases flock)
class BuildLock
  def initialize(stage_dir)
    @stage_dir = stage_dir
    @lock_file = File.join(stage_dir, '.build.lock')
    @lock_fd = nil
  end

  # Acquire exclusive lock on stage directory.
  # Raises error if lock cannot be acquired (another build is running).
  def acquire!
    # Ensure stage directory exists
    FileUtils.mkdir_p(@stage_dir)

    # Open lock file (create if doesn't exist)
    @lock_fd = File.open(@lock_file, File::CREAT | File::RDWR)

    # Try to acquire exclusive lock (non-blocking)
    unless @lock_fd.flock(File::LOCK_EX | File::LOCK_NB)
      # Lock failed - another process is holding the lock
      @lock_fd.close
      @lock_fd = nil

      # Try to read PID from lock file for better error message
      existing_pid = read_lock_pid

      error_msg = "Another build is already running in #{@stage_dir}."
      error_msg += "\nProcess PID: #{existing_pid}" if existing_pid
      error_msg += "\n\nWait for it to complete or kill it manually."

      raise error_msg
    end

    # Successfully acquired lock - write our PID to lock file
    @lock_fd.truncate(0)
    @lock_fd.rewind
    @lock_fd.write(Process.pid.to_s)
    @lock_fd.flush
  end

  # Release the lock.
  # Safe to call multiple times or if lock was never acquired.
  def release
    return unless @lock_fd

    begin
      # Release the lock
      @lock_fd.flock(File::LOCK_UN)
      @lock_fd.close

      # Clean up lock file
      FileUtils.rm_f(@lock_file)
    rescue StandardError => e
      # Swallow errors during cleanup (process might be exiting)
      warn "Warning: Failed to release lock: #{e.message}"
    ensure
      @lock_fd = nil
    end
  end

  private

  # Read PID from lock file (best effort).
  # Returns nil if file doesn't exist or can't be read.
  def read_lock_pid
    return nil unless File.exist?(@lock_file)

    content = File.read(@lock_file).strip
    pid = content.to_i
    pid if pid.positive?
  rescue StandardError
    nil
  end
end
