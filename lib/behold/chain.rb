# frozen_string_literal: true

module Behold
  Chain = Data.define(:steps) do
    def inspect = steps.map(&:inspect).join('.')

    def apply(from) = steps.reduce(from) { |receiver, step| step.apply(receiver) }

    def render(receiver) = steps.reduce(receiver) { |rendered, step| step.render(rendered) }
  end
end
