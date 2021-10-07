# typed: true
# frozen_string_literal: true

# Performs {Formula#mktemp}'s functionality, and tracks the results.
# Each instance is only intended to be used once.
class Mktemp
  extend T::Sig

  include FileUtils

  # Path to the tmpdir used in this run, as a {Pathname}.
  sig { returns(T.nilable(Pathname)) }
  attr_reader :tmpdir

  sig { params(prefix: String, opts: T::Hash[Symbol, T::Boolean]).void }
  def initialize(prefix, opts = {})
    @prefix = prefix
    @retain = opts.fetch(:retain, false)
    @quiet = false
  end

  # Instructs this {Mktemp} to retain the staged files.
  sig { void }
  def retain!
    @retain = true
  end

  # True if the staged temporary files should be retained.
  sig { returns(T::Boolean) }
  def retain?
    @retain
  end

  # Instructs this Mktemp to not emit messages when retention is triggered.
  sig { void }
  def quiet!
    @quiet = true
  end

  sig { returns(String) }
  def to_s
    "[Mktemp: #{tmpdir} retain=#{@retain} quiet=#{@quiet}]"
  end

  sig { params(_block: Proc).returns(T.untyped) }
  def run(&_block)
    @tmpdir = Pathname.new(Dir.mktmpdir("#{@prefix.tr "@", "AT"}-", HOMEBREW_TEMP))

    # Make sure files inside the temporary directory have the same group as the
    # brew instance.
    #
    # Reference from `man 2 open`
    # > When a new file is created, it is given the group of the directory which
    # contains it.
    group_id = if HOMEBREW_BREW_FILE.grpowned?
      HOMEBREW_BREW_FILE.stat.gid
    else
      Process.gid
    end
    begin
      chown(nil, group_id, @tmpdir)
    rescue Errno::EPERM
      # TODO: print integer ID if no group found?
      opoo "Failed setting group \"#{T.must(Etc.getgrgid(group_id)).name}\" on #{@tmpdir}"
    end

    begin
      Dir.chdir(@tmpdir) { yield self }
    ensure
      ignore_interrupts { chmod_rm_rf(@tmpdir) } unless retain?
    end
  ensure
    ohai "Temporary files retained at:", @tmpdir.to_s if retain? && !@tmpdir.nil? && !@quiet
  end

  private

  sig { params(path: Pathname).void }
  def chmod_rm_rf(path)
    if path.directory? && !path.symlink?
      chmod("u+rw", path) if path.owned? # Need permissions in order to see the contents
      path.children.each { |child| chmod_rm_rf(child) }
      rmdir(path)
    else
      rm_f(path)
    end
  rescue
    nil # Just skip this directory.
  end
end
