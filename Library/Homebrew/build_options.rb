# typed: strict
# frozen_string_literal: true

# Options for a formula build.
#
# @api private
class BuildOptions
  extend T::Sig

  # @private
  sig { params(args: Options, options: Options).void }
  def initialize(args, options)
    @args = args
    @options = options
  end

  # True if a {Formula} is being built with a specific option.
  # <pre>args << "--i-want-spam" if build.with? "spam"
  #
  # args << "--qt-gui" if build.with? "qt" # "--with-qt" ==> build.with? "qt"
  #
  # # If a formula presents a user with a choice, but the choice must be fulfilled:
  # if build.with? "example2"
  #   args << "--with-example2"
  # else
  #   args << "--with-example1"
  # end</pre>
  sig { params(val: T.any(Dependable, String)).returns(T::Boolean) }
  def with?(val)
    option_names = val.is_a?(Dependable) ? val.option_names : [val]

    option_names.any? do |name|
      if option_defined? "with-#{name}"
        include? "with-#{name}"
      elsif option_defined? "without-#{name}"
        !include? "without-#{name}" # rubocop:disable Rails/NegateInclude
      else
        false
      end
    end
  end

  # True if a {Formula} is being built without a specific option.
  # <pre>args << "--no-spam-plz" if build.without? "spam"</pre>
  sig { params(val: T.any(Dependable, String)).returns(T::Boolean) }
  def without?(val)
    !with?(val)
  end

  # True if a {Formula} is being built as a bottle (i.e. binary package).
  sig { returns(T::Boolean) }
  def bottle?
    include? "build-bottle"
  end

  # True if a {Formula} is being built with {Formula.head} instead of {Formula.stable}.
  # <pre>args << "--some-new-stuff" if build.head?</pre>
  # <pre># If there are multiple conditional arguments use a block instead of lines.
  # if build.head?
  #   args << "--i-want-pizza"
  #   args << "--and-a-cold-beer" if build.with? "cold-beer"
  sig { returns(T::Boolean) }
  # end</pre>
  def head?
    include? "HEAD"
  end

  # True if a {Formula} is being built with {Formula.stable} instead of {Formula.head}.
  # This is the default.
  # <pre>args << "--some-beta" if build.head?</pre>
  sig { returns(T::Boolean) }
  def stable?
    !head?
  end

  # True if the build has any arguments or options specified.
  sig { returns(T::Boolean) }
  def any_args_or_options?
    !@args.empty? || !@options.empty?
  end

  # @private
  sig { returns(Options) }
  def used_options
    @options & @args
  end

  # @private
  sig { returns(Options) }
  def unused_options
    @options - @args
  end

  private

  sig { params(name: String).returns(T::Boolean) }
  def include?(name)
    @args.include?("--#{name}")
  end

  sig { params(name: String).returns(T::Boolean) }
  def option_defined?(name)
    @options.include? name
  end
end
