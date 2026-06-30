# frozen_string_literal: true

require_relative 'helper'

describe Behold do
  timeout = 1.5

  cases = [[42, 42], [42, 43], ['shannon', 'Shannon'], [Object, 'Object'],
           [5, 25], [[1, 2, 3], '1,2,3'], ['BBQ', %w[B B Q]]]

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
    tuples = Behold.call(5, 25, [3, 9], timeout:)
    refute_empty tuples
    tuples.each do |meth, *args|
      assert_equal 25, 5.public_send(meth, *args)
      assert_equal 9, 3.public_send(meth, *args)
    end
  end

  it 'narrows a string transform across examples' do
    tuples = Behold.call(+'shannon', 'Shannon', [+'ruby', 'Ruby'], timeout:)
    refute_empty tuples
    tuples.each { |meth, *args| assert_equal 'Shannon', (+'shannon').public_send(meth, *args) }
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
    tuples = Behold.call('shannon', 'Shannon', ['ruby', 'Ruby'], timeout:)
    refute_empty tuples
    refute(tuples.any? { |application| application.is_a?(Behold::Chain) })
  end

  it 'ignores candidates that raise non-standard exceptions' do
    source = Class.new do
      def assert_empty = raise Minitest::Assertion, 'nope'
      def answer = 42
    end.new

    assert_includes Behold.call(source, 42, timeout:), [:answer]
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
  end

  it 'deep-dups so the search cannot mutate a nested from collection' do
    original = [['a'], { k: 'b' }]
    copy = Behold.send(:deep_dup, original)
    copy.first.first << 'x'
    copy.last[:k] << 'y'
    assert_equal [['a'], { k: 'b' }], original
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
