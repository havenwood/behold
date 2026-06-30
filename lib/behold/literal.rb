# frozen_string_literal: true

require 'prism'

module Behold
  module Literal
    class << self
      def parse(source)
        result = Prism.parse(source)
        raise ArgumentError, "invalid literal: #{source}" unless result.success?

        evaluate single_statement(result.value.statements)
      end

      private

      def evaluate(node)
        case node
        when Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode
          node.value
        when Prism::StringNode then node.unescaped
        when Prism::SymbolNode then node.unescaped.to_sym
        when Prism::RegularExpressionNode then regexp(node)
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        when Prism::NilNode then nil
        when Prism::ArrayNode then node.elements.map { |element| evaluate element }
        when Prism::HashNode
          node.elements.to_h { |assoc| assoc.is_a?(Prism::AssocNode) ? [evaluate(assoc.key), evaluate(assoc.value)] : evaluate(assoc) }
        when Prism::RangeNode
          Range.new(node.left && evaluate(node.left), node.right && evaluate(node.right), node.exclude_end?)
        when Prism::ParenthesesNode then evaluate(single_statement(node.body))
        when Prism::ConstantReadNode then constant(Object, node.name)
        when Prism::ConstantPathNode then constant(node.parent ? evaluate(node.parent) : Object, node.name)
        else raise ArgumentError, "unsupported literal: #{node&.slice}"
        end
      end

      def regexp(node)
        Regexp.new(node.unescaped, node.options)
      rescue RegexpError => error
        raise ArgumentError, error.message
      end

      def constant(scope, name)
        raise ArgumentError, "unknown constant: #{name}" unless scope.is_a?(Module) && scope.const_defined?(name, false) && !scope.autoload?(name, false)

        scope.const_get(name, false)
      end

      def single_statement(statements)
        raise ArgumentError, 'expected a single expression' unless statements.is_a?(Prism::StatementsNode) && statements.body.one?

        statements.body.first
      end
    end
  end
end
