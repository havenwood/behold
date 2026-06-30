# frozen_string_literal: true

require_relative 'helper'
require 'behold/literal'

describe Behold::Literal do
  it 'parses literals' do
    assert_equal [1, 2, 3], Behold::Literal.parse('[1, 2, 3]')
    assert_equal '42', Behold::Literal.parse("'42'")
    assert_equal({ a: 1 }, Behold::Literal.parse('{a: 1}'))
    assert_equal 1..10, Behold::Literal.parse('1..10')
    assert_equal(/\h+/i, Behold::Literal.parse('/\h+/i'))
  end

  it 'resolves constants' do
    assert_equal Object, Behold::Literal.parse('Object')
    assert_equal Float::INFINITY, Behold::Literal.parse('Float::INFINITY')
  end

  it 'rejects anything that is not a literal or constant' do
    assert_raises(ArgumentError) { Behold::Literal.parse("system('rm -rf /')") }
    assert_raises(ArgumentError) { Behold::Literal.parse('[1, 2,') }
    assert_raises(ArgumentError) { Behold::Literal.parse('Nope::Nope') }
    assert_raises(ArgumentError) { Behold::Literal.parse('1; 2') }
  end
end
