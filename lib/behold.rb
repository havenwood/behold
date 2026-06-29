# frozen_string_literal: true

require 'timeout'
require_relative 'behold/arity_range'
require_relative 'behold/version'

module Behold
  using ArityRange

  FORBIDDEN = %i[__binding__ byebug debugger instance_eval pry
                 public_send __send__ send].freeze
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
          *-10..-1, *11..101, *-101..11, 1_000, 10_000, -1_000, -10_000].freeze
  SINGLE_ARG_FUZZ = FUZZ.map { |arg| [arg] }.freeze
  DOUBLE_ARG_FUZZ = FUZZ.repeated_permutation(2).to_a.freeze
  FUZZES = [NO_ARG_FUZZ, SINGLE_ARG_FUZZ, DOUBLE_ARG_FUZZ].freeze
  RESULT_COUNT = 6
  DEFAULT_TIMEOUT = 3

  class << self
    def code(from, to)
      call(from, to).map do |meth, *args|
        arguments = "(#{args.map(&:inspect).join ', '})" unless args.empty?
        "#{from.inspect}.#{meth}#{arguments}"
      end
    end

    def call(from, to)
      black_hole do
        lazy_tries = FUZZES.map.with_index do |fuzz, index|
          match(from: from, to: to, fuzz: fuzz, arg_count: index)
        end

        best_matches(lazy_tries)
      end
    end

    private

    def best_matches(lazy_tries)
      matches = []
      Timeout.timeout DEFAULT_TIMEOUT do
        lazy_matches(lazy_tries).each { |match| matches << match }
      end

      matches
    rescue Timeout::Error
      matches
    end

    def match(from:, to:, fuzz:, arg_count:)
      candidates = arg_methods(soft_dup(from), arg_count)
      fuzz.lazy.flat_map do |args|
        candidates
          .select { |meth| check_method(meth, *args, from: soft_dup(from), to: to) }
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
      tries.reduce(:+).lazy.take(RESULT_COUNT)
    end

    def check_method(meth, *args, from:, to:)
      operator = to.is_a?(Numeric) ? :eql? : :==
      from.public_send(meth, *args.map { |arg| soft_dup(arg) }).public_send(operator, to)
    rescue StandardError, SyntaxError
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

        arity = object.public_method(meth).arity_range
        arity.fetch(:keywords).min.zero? && arity.fetch(:arguments).cover?(arg_count)
      end.lazy
    end
  end
end
