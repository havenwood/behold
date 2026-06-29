# frozen_string_literal: true

require_relative 'helper'

describe Behold do
  cases = [[42, 42], [42, 43], ['shannon', 'Shannon'], [Object, 'Object'],
           [5, 25], [[1, 2, 3], '1,2,3'], ['BBQ', %w[B B Q]]]

  cases.each do |from, to|
    it "reproduces #{to.inspect} from #{from.inspect}" do
      sources = Behold.code(from, to)
      refute_empty sources
      sources.each { |source| assert_equal to, eval(source) }
    end
  end

  it 'accepts a custom timeout' do
    assert_equal 25, eval(Behold.code(5, 25, timeout: 1).first)
  end

  it 'narrows to transforms that satisfy every example' do
    tuples = Behold.call(5, 25, [3, 9])
    refute_empty tuples
    tuples.each do |meth, *args|
      assert_equal 25, 5.public_send(meth, *args)
      assert_equal 9, 3.public_send(meth, *args)
    end
  end

  it 'derives separators from the example' do
    sources = Behold.code([1, 2, 3], '1::2::3')
    refute_empty sources
    sources.each { |source| assert_equal '1::2::3', eval(source) }
  end
end
