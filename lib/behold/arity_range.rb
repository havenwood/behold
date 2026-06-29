# frozen_string_literal: true

module Behold
  module ArityRange
    refine Method do
      def arity_range
        kinds = parameters.map(&:first)
        req = kinds.count :req
        keyreq = kinds.count :keyreq
        opt = kinds.include?(:rest) ? Float::INFINITY : kinds.count(:opt)
        keyopt = kinds.include?(:keyrest) ? Float::INFINITY : kinds.count(:key)

        {arguments: req..req + opt, keywords: keyreq..keyreq + keyopt}
      end
    end
  end
end
