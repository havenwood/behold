# frozen_string_literal: true

require 'timeout'
require_relative 'behold/arity_range'
require_relative 'behold/version'

module Behold
  using ArityRange

  FORBIDDEN = %i[__binding__ byebug debugger instance_eval pry
                 public_send __send__ send].freeze
  EMPTY_FUZZ = [nil].freeze
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
  DOUBLE_FUZZ = FUZZ.repeated_combination(2).to_a.freeze
  FUZZES = [EMPTY_FUZZ, FUZZ, DOUBLE_FUZZ].freeze
  RESULT_COUNT = 6
  DEFAULT_TIMEOUT = 3

  class << self
    def code(from, to)
      call(from, to).map do |meth, *args|
        "#{from.inspect}.#{meth}#{"(#{args.map(&:inspect).join ', '})" unless args.empty?}"
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

    def best_matches(lazy_tries, matches = [])
      Timeout.timeout DEFAULT_TIMEOUT do
        lazy_matches(lazy_tries).each { |match| matches << match }
      end

      matches
    rescue Timeout::Error
      matches
    end

    def match(from:, to:, fuzz:, arg_count:)
      fuzz.lazy.flat_map do |args|
        found = arg_methods(soft_dup(from), arg_count).select do |meth|
          case arg_count
          when 1
            check_method(meth, args, from: soft_dup(from), to: to)
          else
            check_method(meth, *args, from: soft_dup(from), to: to)
          end
        end
        found = found.with_object(args) if args

        found.map { |*send_this| [*send_this].flatten }
      end
    end

    def black_hole
      File.open File::NULL, File::APPEND do |dev_null|
        $stdout = $stderr = dev_null

        yield
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end
    end

    def lazy_matches(matches)
      matches.reduce(:+).lazy.take(RESULT_COUNT)
    end

    def check_method(meth, *args, from:, to:)
      operator = to.is_a?(Numeric) ? :equal? : :==
      from.public_send(meth, *args).public_send(operator, to)
    rescue StandardError, SyntaxError
      nil
    end

    def soft_dup(from)
      duped_from = from.dup
      return from unless from == from.dup

      duped_from
    rescue FrozenError
      from
    end

    def arg_methods(object, args)
      object.public_methods.select do |meth|
        next if FORBIDDEN.include? meth

        meth_arity_range = object.public_method(meth).arity_range
        next unless meth_arity_range.fetch(:keywords).min.zero?

        mandatory_args, allowable_args = meth_arity_range.fetch(:arguments).minmax

        mandatory_args <= args && allowable_args >= args
      end.lazy
    end
  end
end
