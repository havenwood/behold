# frozen_string_literal: true

module Behold
  module ArityRange
    refine Method do
      def arity_range
        kinds = parameters.map(&:first)
        req = kinds.count :req
        keyreq = kinds.count :keyreq
        opt = kinds.include?(:rest) ? Float::INFINITY : kinds.count(:opt)

        {arguments: req..req + opt, keywords: keyreq}
      end
    end
  end
end
