# frozen_string_literal: true

require_relative 'helper'

##
# TODO: Tests. These spiked tests arbitrarily fail since Behold writes its own assertions.
describe Behold do
  describe 'calling' do
    it 'works with numbers' do
      assert_equal Behold.call(42, 42), [[:rationalize], [:ord], [:to_int], [:to_i], [:to_f], [:to_r]]
      assert_equal Behold.call(42, 43), [[:next], [:succ], [:|, 1], [:+, 1], [:^, 1], [:|, 3]]
    end

    it 'works with strings' do
      assert_equal Behold.call('shannon', 'Shannon'), [[:capitalize], [:capitalize!]]
    end

    it 'works with classes' do
      assert_equal Behold.call(Object, 'Object'), [[:inspect], [:to_s], [:name]]
    end
  end

  describe 'code' do
    it 'works with numbers' do
      assert_equal Behold.code(42, 42), ['42.rationalize', '42.ord', '42.to_int',
                                         '42.to_i', '42.to_f', '42.to_r']
      assert_equal Behold.code(42, 43), ['42.next', '42.succ', '42.|(1)', '42.+(1)',
                                         '42.^(1)', '42.|(3)']
    end

    it 'works with strings' do
      assert_equal Behold.code('shannon', 'Shannon'), ['"shannon".capitalize', '"shannon".capitalize!']
    end

    it 'works with classes' do
      assert_equal Behold.code(Object, 'Object'), ["Object.inspect", "Object.to_s", "Object.name"]
    end
  end
end
