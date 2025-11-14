# frozen_string_literal: true

require "canon"

module Lutaml
  module Xsd
    class Base < Model::Serializable
      XML_DECLARATION_REGEX = /<\?xml[^>]+>\s+/
      ELEMENT_ORDER_IGNORABLE = %w[import include].freeze

      def to_formatted_xml(except: [])
        Canon.format_xml(
          to_xml(except: except)
        ).gsub(XML_DECLARATION_REGEX, "")
      end

      def resolved_element_order
        element_order&.each_with_object(element_order.dup) do |element, array|
          next delete_deletables(array, element) if deletable?(element)

          update_element_array(array, element)
        end
      end

      def sequence?
        is_a?(Sequence)
      end

      def any?
        is_a?(Any)
      end

      def all?
        is_a?(All)
      end

      def choice?
        is_a?(Choice)
      end

      def annotation?
        is_a?(Annotation)
      end

      def attribute?
        is_a?(Attribute)
      end

      def attribute_group?
        is_a?(AttributeGroup)
      end

      def simple_content?
        is_a?(SimpleContent)
      end

      def element?
        is_a?(Element)
      end

      def min_occurrences
        return unless respond_to?(:min_occurs)

        @min_occurs&.to_i || 1
      end

      def max_occurrences
        return unless respond_to?(:max_occurs)
        return "*" if @max_occurs == "unbounded"

        @max_occurs&.to_i || 1
      end

      liquid do
        map "to_xml", to: :to_xml
        map "any?", to: :any?
        map "all?", to: :all?
        map "choice?", to: :choice?
        map "element?", to: :element?
        map "sequence?", to: :sequence?
        map "attribute?", to: :attribute?
        map "annotation?", to: :annotation?
        map "min_occurrences", to: :min_occurrences
        map "max_occurrences", to: :max_occurrences
        map "to_formatted_xml", to: :to_formatted_xml
        map "simple_content?", to: :simple_content?
        map "attribute_group?", to: :attribute_group?
        map "resolved_element_order", to: :resolved_element_order
      end

      private

      def deletable?(instance)
        instance.text? ||
          ELEMENT_ORDER_IGNORABLE.include?(instance.name)
      end

      def delete_deletables(array, instance)
        array.delete_if { |ins| ins == instance }
      end

      def update_element_array(array, instance)
        index = 0
        array.each_with_index do |element, i|
          next unless element == instance

          method_name = ::Lutaml::Model::Utils.snake_case(instance.name)
          array[i] = Array(send(method_name))[index]
          index += 1
        end
      end
    end
  end
end
