# frozen_string_literal: true

module Behold
  Chain = Data.define(:steps) do
    def inspect = steps.inspect

    def render
      steps.map do |step, *args|
        arguments = "(#{args.map(&:inspect).join ', '})" unless args.empty?
        ".#{step}#{arguments}"
      end.join
    end
  end
end
