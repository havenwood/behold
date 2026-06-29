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
end
