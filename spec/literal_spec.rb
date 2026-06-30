# frozen_string_literal: true

require_relative 'helper'
require 'behold/literal'

describe Behold::Literal do
  it 'parses literals' do
    assert_equal [1, 2, 3], Behold::Literal.parse('[1, 2, 3]')
    assert_equal '42', Behold::Literal.parse("'42'")
    assert_equal({ a: 1 }, Behold::Literal.parse('{a: 1}'))
    assert_equal 1..10, Behold::Literal.parse('1..10')
  end

  it 'rejects anything that is not a literal' do
    assert_raises(ArgumentError) { Behold::Literal.parse("system('rm -rf /')") }
    assert_raises(ArgumentError) { Behold::Literal.parse('[1, 2,') }
  end
end
