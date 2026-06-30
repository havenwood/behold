# frozen_string_literal: true

require 'prism'

module Behold
  module Literal
    class << self
      def parse(source)
        result = Prism.parse(source)
        raise ArgumentError, "invalid literal: #{source}" unless result.success?

        evaluate result.value.statements.body.first
      end

      private

      def evaluate(node)
        case node
        when Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode
          node.value
        when Prism::StringNode then node.unescaped
        when Prism::SymbolNode then node.unescaped.to_sym
        when Prism::RegularExpressionNode then Regexp.new(node.unescaped, node.options)
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        when Prism::NilNode then nil
        when Prism::ArrayNode then node.elements.map { |element| evaluate element }
        when Prism::HashNode then node.elements.to_h { |assoc| [evaluate(assoc.key), evaluate(assoc.value)] }
        when Prism::RangeNode
          Range.new(node.left && evaluate(node.left), node.right && evaluate(node.right), node.exclude_end?)
        when Prism::ParenthesesNode then evaluate(node.body.body.first)
        when Prism::ConstantReadNode then constant(Object, node.name)
        when Prism::ConstantPathNode then constant(node.parent ? evaluate(node.parent) : Object, node.name)
        else raise ArgumentError, "unsupported literal: #{node&.slice}"
        end
      end

      def constant(scope, name)
        raise ArgumentError, "unknown constant: #{name}" unless scope.is_a?(Module) && scope.const_defined?(name, false)

        scope.const_get(name, false)
      end
    end
  end
end
