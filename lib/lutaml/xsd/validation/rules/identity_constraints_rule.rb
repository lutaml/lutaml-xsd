# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # Validates xs:key / xs:unique / xs:keyref identity constraints on
        # an instance element.
        #
        # Selector and field XPaths evaluate against the instance subtree
        # with unprefixed XPath semantics (no-namespace matching), which
        # covers the common no-targetNamespace and local-name selector
        # shapes. Scope: constraints declared on the element itself;
        # cross-element keyref scopes and recursive selector Depth are
        # backlog items (TODO.conformance.md).
        class IdentityConstraintsRule < ValidationRule
          def category
            :identity
          end

          def description
            "Validates key, keyref and unique identity constraints"
          end

          def validate(xml_element, schema_element, collector,
                       repository: nil) # rubocop:disable Lint/UnusedMethodArgument
            # `repository` is part of the element-scoped dispatch contract;
            # identity constraints resolve names against the declaration.
            return unless schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            collected = {}

            Array(schema_element.key).each do |constraint|
              values = collect_values(xml_element, constraint)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_key_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.unique).each do |constraint|
              values = collect_values(xml_element, constraint)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_unique_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.keyref).each do |constraint|
              referred = refer_name(constraint) && collected[refer_name(constraint)]
              next if referred.nil?

              collect_values(xml_element, constraint).each do |value|
                next if referred.include?(value)

                report_error(
                  collector,
                  code: "keyref_violation",
                  message: "Value '#{value}' does not match any " \
                           "'#{refer_name(constraint)}' key",
                  location: xml_element.xpath,
                  context: { value: value, refer: refer_name(constraint) },
                )
              end
            end
          end

          private

          def collect_values(xml_element, constraint)
            selector_xpaths(constraint).flat_map do |selector|
              Array(xml_element.moxml_element.xpath(selector)).map do |node|
                field_xpaths(constraint).filter_map do |field|
                  field_value(node, field)
                end
              end
            end.flatten.compact
          end

          def report_duplicates(collector, xml_element, constraint, values,
                                code)
            values.group_by(&:itself).each do |value, group|
              next unless group.length > 1

              report_error(
                collector,
                code: code,
                message: "Duplicate value '#{value}' for " \
                         "'#{constraint.name}'",
                location: xml_element.xpath,
                context: {
                  value: value,
                  constraint: constraint.name,
                  occurrences: group.length,
                },
              )
            end
          end

          def selector_xpaths(constraint)
            return [] unless constraint.selector

            xpaths = constraint.selector.respond_to?(:xpath) ? constraint.selector.xpath : constraint.selector
            Array(xpaths).map { |x| x.respond_to?(:xpath) ? x.xpath : x.to_s }
          end

          def field_xpaths(constraint)
            Array(constraint.field).map do |field|
              field.respond_to?(:xpath) ? field.xpath : field.to_s
            end
          end

          def field_value(node, field_xpath)
            first = Array(node.xpath(field_xpath)).first
            return nil unless first

            first.respond_to?(:value) && first.value ? first.value : first.text
          end

          # Keyref `refer` as a string; nil when the model left it
          # unmapped (UninitializedClass — a lutaml-model mapping gap for
          # `map_attribute :refer`).
          def refer_name(constraint)
            refer = constraint.refer
            return nil unless refer.is_a?(String)

            text = refer.split(":").last
            text.to_s.empty? ? nil : text
          end
        end
      end
    end
  end
end
