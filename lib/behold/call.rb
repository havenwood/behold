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

      parts = args.map { |arg| literal(arg) } + kwargs.map { |key, value| "#{key}: #{literal(value)}" }
      parts.empty? ? '' : "(#{parts.join ', '})"
    end

    def literal(value)
      return value.inspect unless value.is_a?(Float)
      return 'Float::NAN' if value.nan?
      return 'Float::INFINITY' if value == Float::INFINITY
      return '-Float::INFINITY' if value == -Float::INFINITY

      value.inspect
    end
  end
end
