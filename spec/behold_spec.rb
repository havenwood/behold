# frozen_string_literal: true

require_relative 'helper'
require 'behold/literal'
require 'fileutils'

describe Behold do
  timeout = 20

  cases = [[42, 42], [42, 43], ['shannon', 'Shannon'], [Object, 'Object'],
           [5, 25], [5, Float::INFINITY], [Float::INFINITY, 'Infinity'],
           [:'1.5', 3.0], [[1, 2, 3], '1,2,3'], ['BBQ', %w[B B Q]]]

  cases.each do |from, to|
    it "reproduces #{to.inspect} from #{from.inspect}" do
      sources = Behold.code(from, to, timeout:)
      refute_empty sources
      sources.each { |source| assert_equal to, eval(source) }
    end
  end

  it 'accepts a custom timeout' do
    assert_equal 25, eval(Behold.code(5, 25, timeout:).first)
  end

  it 'caps the number of results' do
    assert_equal 2, Behold.call(5, 25, count: 2, timeout:).size
  end

  it 'narrows to transforms that satisfy every example' do
    results = Behold.call(5, 25, [3, 9], timeout:)
    refute_empty results
    results.each do |result|
      assert_equal 25, result.apply(5)
      assert_equal 9, result.apply(3)
    end
  end

  it 'narrows a string transform across examples' do
    results = Behold.call(+'shannon', 'Shannon', [+'ruby', 'Ruby'], timeout:)
    refute_empty results
    results.each { |result| assert_equal 'Shannon', result.apply(+'shannon') }
  end

  it 'derives separators from the example' do
    sources = Behold.code([1, 2, 3], '1::2::3', timeout:)
    refute_empty sources
    sources.each { |source| assert_equal '1::2::3', eval(source) }
  end

  it 'derives a numeric delta the fuzz list lacks' do
    sources = Behold.code(5, 1_000_000, timeout:)
    refute_empty sources
    sources.each { |source| assert_equal 1_000_000, eval(source) }
  end

  it 'derives a replacement from a string pair' do
    sources = Behold.code('foo bar', 'foo::bar', timeout:)
    refute_empty sources
    sources.each { |source| assert_equal 'foo::bar', eval(source) }
  end

  it 'synthesizes blocks' do
    assert_equal [1, 4, 9], eval(Behold.code([1, 2, 3], [1, 4, 9], timeout:).first)
    assert_equal [1, 2, 3], eval(Behold.code(%w[a bb ccc], [1, 2, 3], timeout:).first)
  end

  it 'falls back to a two-step chain when no single call works' do
    sources = Behold.code('hello', 'OLLEH', ['world', 'DLROW'], timeout:)
    refute_empty sources
    assert_includes sources, '"hello".reverse.upcase'
    sources.each { |source| assert_equal 'OLLEH', eval(source) }
  end

  it 'coerces a stringified number before arithmetic' do
    sources = Behold.code('1.5', 3.0, timeout:)
    refute_empty sources
    assert(sources.any? { |source| source.include?('to_f') })
    sources.each { |source| assert_equal 3.0, eval(source) }
  end

  it 'prefers a direct call over a fallback chain' do
    results = Behold.call('shannon', 'Shannon', ['ruby', 'Ruby'], timeout:)
    refute_empty results
    refute(results.any? { |application| application.is_a?(Behold::Chain) })
  end

  it 'ignores candidates that raise non-standard exceptions' do
    source = Class.new do
      def assert_empty = raise Minitest::Assertion, 'nope'
      def answer = 42
    end.new

    assert_includes Behold.call(source, 42, timeout:), Behold::Call.new(meth: :answer)
  end

  it 'matches numbers by type-exact value' do
    refute Behold.send(:check_method, :*, 1.0, from: 1, to: 1)
    assert Behold.send(:check_method, :*, 1, from: 1, to: 1)
  end

  it 'keeps timeout errors from candidate calls' do
    source = Class.new do
      def stall = sleep
    end.new

    assert_raises Timeout::Error do
      Timeout.timeout(0.01) do
        Behold.send(:check_method, :stall, from: source, to: :never)
      end
    end
  end

  it 'never offers dangerous methods on a module receiver' do
    refute_includes Behold.send(:arg_methods, Kernel, 0).to_a, :exit
    refute_includes Behold.send(:arg_methods, Kernel, 1).to_a, :system
    refute_includes Behold.send(:arg_methods, File, 1).to_a, :unlink
    refute_includes Behold.send(:arg_methods, File, 1).to_a, :open
    refute_includes Behold.send(:arg_methods, File, 1).to_a, :delete
    refute_includes Behold.send(:arg_methods, File, 1).to_a, :binwrite
    refute_includes Behold.send(:arg_methods, IO, 1).to_a, :popen
    refute_includes Behold.send(:arg_methods, Process, 1).to_a, :kill
    refute_includes Behold.send(:arg_methods, Object, 1).to_a, :remove_method
    refute_includes Behold.send(:arg_methods, Object, 1).to_a, :define_method
    refute_includes Behold.send(:arg_methods, Object, 1).to_a, :include
    refute_includes Behold.send(:arg_methods, Object, 1).to_a, :instance_exec
    refute_includes Behold.send(:arg_methods, FileUtils, 1).to_a, :rmtree
    refute_includes Behold.send(:arg_methods, FileUtils, 1).to_a, :remove_entry
    refute_includes Behold.send(:arg_methods, FileUtils, 1).to_a, :touch
  end

  it 'keeps a benign method that shares a name with a dangerous module method' do
    assert_includes Behold.send(:arg_methods, [1, 2, 3], 1).to_a, :delete
  end

  it 'deep-dups so the search cannot mutate a nested from collection' do
    original = [['a'], { k: 'b' }]
    copy = Behold.send(:deep_dup, original)
    copy.first.first << 'x'
    copy.last[:k] << 'y'
    assert_equal [['a'], { k: 'b' }], original
  end

  it 'derives keyword arguments the fuzz list lacks' do
    results = Behold.send(:kwarg_tuples, [[2.5, 3]]).to_a
    assert_includes results, Behold::Call.new(meth: :round, kwargs: { half: :up })
  end

  it 'tries methods with a required keyword' do
    receiver = Class.new { def choose(half:) = half == :up ? 99 : 0 }.new
    results = Behold.send(:kwarg_tuples, [[receiver, 99]]).to_a
    assert_includes results, Behold::Call.new(meth: :choose, kwargs: { half: :up })
  end

  it 'does not mutate a custom receiver with identity equality' do
    counter = Class.new do
      def initialize = @n = 0
      attr_reader :n
      def bump! = @n += 1
    end.new
    Behold.call(counter, 999, timeout: 0.5)
    assert_equal 0, counter.n
  end

  it 'applies a two-step chain' do
    results = Behold.call('hello', 'OLLEH', ['world', 'DLROW'], timeout:)
    chain = results.find { |result| result.is_a?(Behold::Chain) }
    refute_nil chain
    assert_equal 'OLLEH', chain.apply(+'hello')
  end

  it 'returns empty when nothing matches under a tiny timeout' do
    assert_equal [], Behold.call(Object.new, :unreachable, timeout: 0.001)
  end

  it 'routes to the target class through coercion' do
    results = Behold.send(:route_tuples, [[:'1.5', 3.0]]).to_a
    refute_empty results
    results.each { |chain| assert_equal 3.0, chain.apply(:'1.5') }
  end
end

describe Behold::Literal do
  it 'wraps an invalid regexp literal as ArgumentError' do
    assert_raises(ArgumentError) { Behold::Literal.parse('/\p{Nope}/') }
  end

  it 'rejects an autoloaded constant' do
    scope = Module.new
    scope.autoload(:Pending, '/does/not/exist')
    assert_raises(ArgumentError) { Behold::Literal.send(:constant, scope, :Pending) }
  end

  it 'rejects an IO constant' do
    assert_raises(ArgumentError) { Behold::Literal.parse('STDOUT') }
  end

  it 'wraps a deeply nested literal as ArgumentError' do
    assert_raises(ArgumentError) { Behold::Literal.parse('[' * 5000 + ']' * 5000) }
  end
end

describe Behold::Call do
  it 'applies a no-arg call' do
    assert_equal 'HI', Behold::Call.new(meth: :upcase).apply('hi')
  end

  it 'applies positional args' do
    assert_equal 42, Behold::Call.new(meth: :+, args: [1]).apply(41)
  end

  it 'applies keyword args' do
    assert_equal 3, Behold::Call.new(meth: :round, kwargs: { half: :up }).apply(2.5)
  end

  it 'renders source against a receiver' do
    assert_equal '2.5.round(half: :up)', Behold::Call.new(meth: :round, kwargs: { half: :up }).render('2.5')
  end

  it 'inspects as the call fragment' do
    assert_equal 'round(half: :up)', Behold::Call.new(meth: :round, kwargs: { half: :up }).inspect
  end

  it 'is value-equal under defaults' do
    assert_equal Behold::Call.new(meth: :answer, args: [], kwargs: {}, block: nil), Behold::Call.new(meth: :answer)
  end
end
