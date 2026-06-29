# frozen_string_literal: true

require 'timeout'
require_relative 'behold/arity_range'
require_relative 'behold/version'

module Behold
  using ArityRange

  FORBIDDEN = %i[__binding__ byebug debugger instance_eval pry rake_extension
                 public_send __send__ send
                 shuffle shuffle! sample hash object_id __id__].freeze
  FORBIDDEN_OWNERS = %w[Minitest::Expectations].freeze
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
          Time.now, Object, Module, Kernel,
          *-10..-1, *11..101, *-101..11, 1_000, 10_000, -1_000, -10_000].uniq.freeze
  SINGLE_ARG_FUZZ = FUZZ.map { |arg| [arg] }.freeze
  DOUBLE_ARG_FUZZ = FUZZ.repeated_permutation(2).to_a.freeze
  FUZZES = [NO_ARG_FUZZ, SINGLE_ARG_FUZZ, DOUBLE_ARG_FUZZ].freeze
  RESULT_COUNT = 6
  DEFAULT_TIMEOUT = 3

  class << self
    def code(from, to, *more, timeout: DEFAULT_TIMEOUT)
      call(from, to, *more, timeout: timeout).map do |meth, *args|
        arguments = "(#{args.map(&:inspect).join ', '})" unless args.empty?
        "#{from.inspect}.#{meth}#{arguments}"
      end
    end

    def call(from, to, *more, timeout: DEFAULT_TIMEOUT)
      examples = [[from, to], *more]
      black_hole do
        separators = match(examples: examples, fuzz: derived_args(examples), arg_count: 1)
        no_args, one_arg, two_args = FUZZES.map.with_index do |fuzz, index|
          match(examples: examples, fuzz: fuzz, arg_count: index)
        end

        best_matches([separators, no_args, one_arg, derived_tuples(examples), two_args], timeout)
      end
    end

    private

    def best_matches(lazy_tries, timeout)
      matches = []
      Timeout.timeout timeout do
        lazy_matches(lazy_tries).each { |match| matches << match }
      end

      matches
    rescue Timeout::Error
      matches
    end

    def match(examples:, fuzz:, arg_count:)
      candidates = arg_methods(soft_dup(examples.first.first), arg_count)
      fuzz.lazy.flat_map do |args|
        candidates
          .select { |meth| examples.all? { |from, to| check_method(meth, *args, from: soft_dup(from), to: to) } }
          .map { |meth| [meth, *args] }
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

    def lazy_matches(tries)
      tries.reduce(:+).lazy.uniq.take(RESULT_COUNT)
    end

    def check_method(meth, *args, from:, to:)
      operator = to.is_a?(Numeric) ? :eql? : :==
      from.public_send(meth, *args.map { |arg| soft_dup(arg) }).public_send(operator, to)
    rescue Timeout::Error, Timeout::ExitException, NoMemoryError, SignalException, SystemExit
      raise
    rescue Exception
      nil
    end

    def soft_dup(from)
      duped_from = from.dup
      from == duped_from ? duped_from : from
    rescue StandardError
      from
    end

    def arg_methods(object, arg_count)
      object.public_methods.select do |meth|
        next if FORBIDDEN.include? meth

        method = object.public_method(meth)
        next if FORBIDDEN_OWNERS.include? method.owner.name

        arity = method.arity_range
        arity.fetch(:keywords).min.zero? && arity.fetch(:arguments).cover?(arg_count)
      end.lazy
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
      (numeric_tuples(from, to) + replacement_tuples(from, to)).lazy.select do |meth, *args|
        examples.all? { |ex_from, ex_to| check_method(meth, *args, from: soft_dup(ex_from), to: ex_to) }
      end
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
