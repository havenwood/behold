# frozen_string_literal: true

module Behold
  module ArityRange
    refine Method do
      def arity_range
        args = parameters.map(&:first)
        req = args.count :req
        keyreq = args.count :keyreq
        opt = args.include?(:rest) ? Float::INFINITY : args.count(:opt)
        keyopt = args.include?(:keyrest) ? Float::INFINITY : args.count(:key)

        {arguments: req..req + opt, keywords: keyreq..keyreq + keyopt}
      end
    end
  end
end
