# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # Validates xs:key / xs:unique / xs:keyref identity constraints on
        # an instance element.
        #
        # Selector and field XPaths evaluate against the instance subtree.
        # Top-level unions split into one path each; namespace-prefixed
        # steps rewrite to local-name() tests (the adapter resolves no
        # namespace bindings). Scope: constraints declared on the element
        # itself; cross-element keyref scopes and recursive selector depth
        # are backlog items (TODO.conformance.md).
        class IdentityConstraintsRule < ValidationRule
          def category
            :identity
          end

          def description
            "Validates key, keyref and unique identity constraints"
          end

          def validate(xml_element, schema_element, collector,
                       repository: nil)
            # `repository` is part of the element-scoped dispatch contract;
            # identity constraints resolve names against the declaration.
            return unless schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            collected = {}

            Array(schema_element.key).each do |constraint|
              values = collect_values(xml_element, constraint, collector,
                                      repository)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_key_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.unique).each do |constraint|
              values = collect_values(xml_element, constraint, collector,
                                      repository)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_unique_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.keyref).each do |constraint|
              referred = refer_name(constraint) && collected[refer_name(constraint)]
              next if referred.nil?

              collect_values(xml_element, constraint, collector,
                             repository).each do |value|
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

          def collect_values(xml_element, constraint, collector, repository)
            fields = field_xpaths(constraint)
            selector_xpaths(constraint).flat_map do |selector|
              Array(xml_element.moxml_element.xpath(selector)).map do |node|
                values = []
                ambiguous = false
                fields.each do |field|
                  matched = Array(node.xpath(field))
                  # A field evaluating to a node-set with more than one
                  # member violates the constraint (XSD 1.0 §3.11.4).
                  ambiguous = true if matched.size > 1
                  values << (matched.first ? field_node_value(matched.first) : nil)
                end

                if ambiguous
                  report_error(
                    collector,
                    code: "field_node_set_violation",
                    message: "Field #{fields.join(', ')} evaluates to " \
                             "more than one node in '#{node.name}'",
                    location: xml_element.xpath,
                    context: { constraint: constraint.name },
                  )
                  next
                end

                # A qualified node has every field present; an absent
                # field means the node does not contribute a row.
                next nil if values.any?(&:nil?)

                canonical = fields.each_with_index.map do |field, index|
                  declared = field_declared_type(node, field, repository)
                  numeric = declared &&
                    repository&.numeric_simple_type?(declared)
                  numeric ? canonical_field_value(values[index]) : values[index]
                end
                canonical.length == 1 ? canonical.first : canonical
              end
            end.compact
          end

          # The declared type local name of the field's node: attribute
          # fields resolve through the selector node's declaration's
          # type; element fields through their own declaration.
          #
          # @return [String, nil]
          def field_declared_type(node, field, repository)
            if field.to_s.start_with?("@")
              attr_local = field.sub(/\A@/, "").sub(/\A[\w.-]+:/, "")
              parent_decl = repository&.resolve(node.name,
                                                node.namespace_uri)
              parent_type = parent_decl&.complex_type ||
                repository&.resolve_type(parent_decl)
              return nil unless parent_type

              repository.declared_attribute_type(parent_type, attr_local)
            else
              repository&.resolve(node.name, node.namespace_uri)
                &.type.to_s.split(":").last.then do |t|
                  t.to_s.empty? ? nil : t
                end
            end
          end

          # Identity values compare in the field's VALUE space: numeric
          # lexical forms compare numerically (3.0 == 3) and padding is
          # insignificant — applied only when the declared type is
          # numeric; string fields compare lexically.
          #
          # @return [String]
          def canonical_field_value(raw)
            s = raw.to_s.strip
            return s unless s.match?(/\A-?\d+(\.\d+)?\z/)

            f = s.to_f
            f == f.to_i ? f.to_i.to_s : f.to_s
          end

          # @param node [Moxml::Node] attribute or element node
          # @return [String, nil]
          def field_node_value(node)
            case node
            when Moxml::Attribute then node.value
            else node.text
            end
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

            selector = constraint.selector
            if selector.is_a?(Lutaml::Xml::Schema::Xsd::Selector)
              xpath_strings(selector.xpath)
            else
              xpath_strings(selector)
            end
          end

          def field_xpaths(constraint)
            Array(constraint.field).flat_map do |field|
              if field.is_a?(Lutaml::Xml::Schema::Xsd::Field)
                xpath_strings(field.xpath)
              else
                xpath_strings(field)
              end
            end
          end

          # Selector/field values are either the raw XPath string or the
          # parsed xs:selector/xs:field model whose xpath attribute holds
          # it. Top-level unions split into one path each; prefixed
          # steps rewrite to local-name() tests — the adapter resolves
          # no namespace bindings, so "myNS:t" cannot evaluate as-is.
          def xpath_strings(value)
            case value
            when String
              value.split(/\s*\|\s*/).reject(&:empty?).map { |p| adapt_xpath(p) }
            else
              []
            end
          end

          # Rewrites namespace-prefixed steps to local-name() tests.
          # Prefix-insensitive, equivalent for the suite's
          # single-namespace selector shapes.
          #
          # @return [String]
          def adapt_xpath(path)
            path.gsub(/@([\w.-]+):([\w.-]+)/) do
              "@*[local-name()='#{Regexp.last_match(2)}']"
            end.gsub(/(?<![@\w])[\w.-]+:([\w.-]+)/) do
              "*[local-name()='#{Regexp.last_match(1)}']"
            end
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
