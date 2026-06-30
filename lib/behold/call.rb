# frozen_string_literal: true

module Behold
  Call = Data.define(:meth, :args, :kwargs, :block) do
    def initialize(meth:, args: [], kwargs: {}, block: nil) = super

    def apply(receiver) = receiver.public_send(meth, *args, **kwargs, &block)

    def render(receiver) = "#{receiver}.#{meth}#{fragment}"

    def inspect = "#{meth}#{fragment}"

    private

    def fragment
      return block.render if block && args.empty? && kwargs.empty?

      parts = args.map(&:inspect) + kwargs.map { |key, value| "#{key}: #{value.inspect}" }
      parts.empty? ? '' : "(#{parts.join ', '})"
    end
  end
end
