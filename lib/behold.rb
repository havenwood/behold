# frozen_string_literal: true

require 'timeout'
require_relative 'behold/arity_range'
require_relative 'behold/call'
require_relative 'behold/chain'
require_relative 'behold/version'

module Behold
  using ArityRange

  FORBIDDEN = %i[__binding__ byebug debugger pry rake_extension
                 public_send __send__ send
                 eval instance_eval module_eval class_eval instance_exec module_exec class_exec `
                 system exec spawn fork syscall exit exit! abort at_exit trap
                 load require require_relative autoload
                 open write display unlink mkdir rmdir chmod chown
                 rm rm_rf rm_r remove_entry_secure
                 define_method define_singleton_method alias_method remove_method undef_method
                 attr attr_reader attr_writer attr_accessor
                 include prepend extend using refine
                 const_set remove_const class_variable_set instance_variable_set
                 remove_class_variable remove_instance_variable
                 private public protected module_function private_constant public_constant
                 private_class_method public_class_method
                 freeze deprecate_constant set_temporary_name
                 shuffle shuffle! sample hash object_id __id__].freeze
  FORBIDDEN_OWNERS = %w[Minitest::Expectations].freeze
  FORBIDDEN_OWNER_NAMES = %w[Dir File IO Process FileUtils].freeze
  NO_ARG_FUZZ = [[]].freeze
  FUZZ = [*0..10,
          -1.0, 0.0, 1.0,
          [], {},
          Float::INFINITY, Float::NAN,
          '', *' '..'~', '  ', ', ', "\n", "\t", "\r",
          'lowercase words', 'Capitalized Words', 'UPPERCASE WORDS',
          //, /.+/, /\h+/,
          :to_s, :to_i, :to_h, :to_a,
          :join, :<<, :+, :-, :*, :inject, :new,
          nil, true, false,
          nil..nil, 1..10, 'a'..'f',
          Object, Module, Kernel,
          *-10..-1, *11..101, *-101..11, 1_000, 10_000, -1_000, -10_000].uniq.freeze
  SINGLE_ARG_FUZZ = FUZZ.map { |arg| [arg] }.freeze
  DOUBLE_ARG_FUZZ = FUZZ.repeated_permutation(2).freeze
  FUZZES = [NO_ARG_FUZZ, SINGLE_ARG_FUZZ, DOUBLE_ARG_FUZZ].freeze
  RESULT_COUNT = 6
  DEFAULT_TIMEOUT = 3

  BLOCK_METHODS = %i[map flat_map select reject filter_map sort_by min_by max_by
                     find count take_while drop_while].freeze
  Block = Data.define(:source, :to_proc) do
    def inspect = source
    def render = source.start_with?('&') ? "(#{source})" : " #{source}"
  end
  BLOCKS = [*%i[upcase downcase capitalize swapcase reverse to_s to_i to_a chars
                length size abs succ pred even? odd? zero? positive? negative?
                ord chr strip chomp sort uniq sum min max first last]
              .map { |sym| Block.new("&:#{sym}", sym.to_proc) },
            Block.new('{ _1 ** 2 }', ->(element) { element**2 }),
            Block.new('{ _1 * 2 }', ->(element) { element * 2 }),
            Block.new('{ _1 + 1 }', ->(element) { element + 1 }),
            Block.new('{ -_1 }', ->(element) { -element })].freeze

  FIRST_STEPS = %i[to_f to_r to_c reverse upcase downcase capitalize swapcase sort
                   chars bytes to_a to_s to_i flatten compact uniq abs chr ord strip
                   chomp succ pred first last min max sum].freeze
  CHAIN_RESULT_COUNT = 3
  KWARGS = [{ half: :up }, { half: :down }, { half: :even }, { chomp: true }].freeze

  class << self
    def code(from, to, *more, count: RESULT_COUNT, timeout: DEFAULT_TIMEOUT)
      receiver = Call.literal(from)
      call(from, to, *more, count:, timeout:).map { |result| result.render(receiver) }
    end

    def call(from, to, *more, count: RESULT_COUNT, timeout: DEFAULT_TIMEOUT)
      examples = [[from, to], *more]
      black_hole do
        separators = match(examples:, fuzz: derived_args(examples), arg_count: 1)
        no_args, one_arg, two_args = FUZZES.map.with_index do |fuzz, index|
          match(examples:, fuzz:, arg_count: index)
        end

        cheap = [separators, no_args, block_tuples(examples), one_arg, derived_tuples(examples), kwarg_tuples(examples)]
        best_matches([cheap, [chain_tuples(examples)], [two_args]], count, timeout)
      end
    end

    private

    def best_matches(tiers, count, timeout)
      matches = []
      Timeout.timeout timeout do
        tiers.each do |tier|
          lazy_matches(tier, count).each { |match| matches << match }
          break unless matches.empty?
        end
      end

      matches
    rescue Timeout::Error
      matches
    end

    def match(examples:, fuzz:, arg_count:)
      candidates = arg_methods(soft_dup(examples.dig(0, 0)), arg_count)
      fuzz.lazy.flat_map do |args|
        candidates
          .select { |meth| examples.all? { |from, to| check_method(meth, *args, from: deep_dup(from), to:) } }
          .map { |meth| Call.new(meth:, args:) }
      end
    end

    def black_hole
      old_stdout = $stdout
      old_stderr = $stderr
      File.open File::NULL, File::APPEND do |dev_null|
        $stdout = $stderr = dev_null

        yield
      ensure
        $stdout = old_stdout
        $stderr = old_stderr
      end
    end

    def lazy_matches(tries, count)
      tries.reduce(:+).lazy.uniq.take(count)
    end

    def check_method(meth, *args, from:, to:, kwargs: {}, &block)
      operator = to.is_a?(Numeric) ? :eql? : :==
      from.public_send(meth, *args.map { |arg| soft_dup(arg) }, **kwargs, &block).public_send(operator, to)
    rescue Timeout::Error, Timeout::ExitException, NoMemoryError, SignalException, SystemExit
      raise
    rescue Exception
      nil
    end

    def soft_dup(from)
      return from if from.is_a?(Module)

      duped_from = from.dup
      duped_from.equal?(from) ? from : duped_from
    rescue StandardError
      from
    end

    def deep_dup(from)
      case from
      when Array then from.map { |element| deep_dup(element) }
      when Hash then from.to_h { |key, value| [deep_dup(key), deep_dup(value)] }
      else soft_dup(from)
      end
    end

    def arg_methods(object, arg_count, keywords: 0)
      object.public_methods.select do |meth|
        next if FORBIDDEN.include? meth

        method = object.public_method(meth)
        next if forbidden_owner?(method.owner)

        arity = method.arity_range
        arity.fetch(:keywords) <= keywords && arity.fetch(:arguments).cover?(arg_count)
      end.lazy
    end

    def forbidden_owner?(owner)
      return true if FORBIDDEN_OWNERS.include?(owner.name)

      owner.singleton_class? && (attached = owner.attached_object).is_a?(Module) && FORBIDDEN_OWNER_NAMES.include?(attached.name)
    end

    def derived_args(examples)
      examples.flat_map { |from, to| [join_separator(from, to), split_separator(from, to)] }
              .compact.uniq.map { |arg| [arg] }
    end

    def join_separator(from, to)
      return unless to.is_a?(String) && from.respond_to?(:map)

      parts = from.map(&:to_s)
      head = parts.first
      return unless parts.size >= 2 && parts.none?(&:empty?) && to.start_with?(head)

      finish = to.index(parts[1], head.length)
      to[head.length...finish] if finish
    end

    def split_separator(from, to)
      return unless from.is_a?(String) && to.is_a?(Array) && to.size >= 2

      head, nxt = to[0].to_s, to[1].to_s
      return unless from.start_with?(head)

      finish = from.index(nxt, head.length)
      from[head.length...finish] if finish
    end

    def derived_tuples(examples)
      from, to = examples.first
      (numeric_tuples(from, to) + replacement_tuples(from, to)).lazy.filter_map do |meth, *args|
        Call.new(meth:, args:) if examples.all? { |ex_from, ex_to| check_method(meth, *args, from: soft_dup(ex_from), to: ex_to) }
      end
    end

    def block_tuples(examples)
      return [] unless examples.dig(0, 0).respond_to?(:map)

      BLOCK_METHODS.product(BLOCKS).lazy.filter_map do |meth, block|
        Call.new(meth:, block:) if examples.all? { |from, to| check_method(meth, from: soft_dup(from), to:, &block) }
      end
    end

    def kwarg_tuples(examples)
      candidates = arg_methods(soft_dup(examples.dig(0, 0)), 0, keywords: KWARGS.map(&:size).max)
      candidates.flat_map do |meth|
        KWARGS.filter_map do |kwargs|
          Call.new(meth:, kwargs:) if examples.all? { |from, to| check_method(meth, from: deep_dup(from), to:, kwargs:) }
        end
      end
    end

    def chain_tuples(examples)
      receiver = examples.dig(0, 0)
      FIRST_STEPS.select { |step| receiver.respond_to?(step) }.lazy.flat_map do |step|
        stepped = step_examples(examples, step)
        next [] unless stepped

        separators = match(examples: stepped, fuzz: derived_args(stepped), arg_count: 1)
        no_args, one_arg = FUZZES.first(2).map.with_index { |fuzz, index| match(examples: stepped, fuzz:, arg_count: index) }
        lazy_matches([separators, no_args, one_arg], CHAIN_RESULT_COUNT).map { |second| Chain.new([Call.new(meth: step), second]) }
      end
    end

    def step_examples(examples, step)
      examples.map do |from, to|
        mid = step_value(deep_dup(from), step)
        return nil if mid.nil? || mid == from || mid == to

        [mid, to]
      end
    end

    def step_value(from, step)
      from.public_send(step)
    rescue StandardError
      nil
    end

    def numeric_tuples(from, to)
      return [] unless from.is_a?(Numeric) && to.is_a?(Numeric)

      tuples = [[:+, to - from], [:-, from - to]]
      tuples << [:*, to / from] unless from.zero?
      tuples << [:/, from / to] unless to.zero?
      tuples
    end

    def replacement_tuples(from, to)
      return [] unless from.is_a?(String) && to.is_a?(String) && from != to

      old, new = diff_span(from, to)
      old.empty? ? [] : [[:gsub, old, new], [:sub, old, new]]
    end

    def diff_span(from, to)
      prefix = 0
      prefix += 1 while prefix < from.length && prefix < to.length && from[prefix] == to[prefix]
      suffix = 0
      suffix += 1 while suffix < from.length - prefix && suffix < to.length - prefix && from[-1 - suffix] == to[-1 - suffix]
      [from[prefix...(from.length - suffix)], to[prefix...(to.length - suffix)]]
    end
  end
end
