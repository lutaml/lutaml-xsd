# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # IdrefResolutionRule enforces built-in xs:IDREF(S) resolution
        #
        # XSD 1.0 §3.3.3: every IDREF/IDREFS value must match the value
        # of some ID in the document. Values come from instance
        # attributes, element text typed IDREF(S), AND a declaration's
        # fixed/default supply when the instance omits the attribute —
        # a defaulted IDREFS still references (idZ012: drefs
        # type="xs:IDREFS" default="abc" against a document declaring
        # no ID). IDREFS values tokenize on whitespace; every token
        # must resolve. The scan is two-phase (all IDs first, then all
        # references), so forward references resolve.
        class IdrefResolutionRule < ValidationRule
          def category
            :identity
          end

          def description
            "Validates built-in xs:IDREF(S) values resolve to document IDs"
          end

          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless repository
            return unless
              schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            # The walk invokes the rule per element and per category;
            # the document is scanned exactly once, from the first
            # (root) invocation — element wrappers are not
            # identity-stable across passes.
            return if @scanned

            @scanned = true
            ids = collect_ids(xml_element, repository)
            check_references(xml_element, ids, collector, repository)
          end

          private

          # Phase 1: every ID value in the document (element text and
          # attributes). Mirrors IdUniquenessRule's walk — IDs come
          # from instances only; a declaration cannot supply an ID that
          # the document does not contain.
          #
          # @return [Set<String>]
          def collect_ids(element, repository)
            ids = []
            declaration = repository.resolve(element.name,
                                             element.namespace_uri)
            if declaration
              collect_element_ids(element, declaration, ids, repository)
              collect_attribute_ids(element, declaration, ids, repository)
            end

            element.children.each do |child|
              ids.concat(collect_ids(child, repository))
            end
            ids.compact
          end

          # @return [void]
          def collect_element_ids(element, declaration, ids, repository)
            return unless builtin_typed?(declaration, repository, "ID")

            # ID/IDREF(S) collapse whitespace (token derivation) — the
            # value space is the collapsed form, never the raw lexical
            # (dtZ107447: " John " both sides).
            ids.concat(element.text_content.to_s.split)
          end

          # @return [void]
          def collect_attribute_ids(element, declaration, ids, repository)
            typed_attributes(declaration, repository, "ID").each do |attr|
              instance = element.attributes.find do |candidate|
                candidate.name == attr.name
              end
              ids.concat(instance.value.to_s.split) if instance
            end
          end

          # Phase 2: every IDREF(S) value the document carries or its
          # declarations SUPPLY, each token matched against the IDs.
          #
          # @return [void]
          def check_references(element, ids, collector, repository)
            declaration = repository.resolve(element.name,
                                             element.namespace_uri)
            if declaration
              check_element_reference(element, declaration, ids, collector,
                                      repository)
              check_attribute_references(element, declaration, ids,
                                         collector, repository)
            end

            element.children.each do |child|
              check_references(child, ids, collector, repository)
            end
          end

          # @return [void]
          def check_element_reference(element, declaration, ids, collector,
                                      repository)
            return unless
              builtin_typed?(declaration, repository, "IDREF") ||
                builtin_typed?(declaration, repository, "IDREFS")

            reference_values(element.text_content.to_s).each do |value|
              next if ids.include?(value)

              report_unresolved(value, element, collector, "element")
            end
          end

          # Instance values, then the declaration's fixed/default supply
          # for ABSENT attributes — a defaulted IDREFS still references
          # (idZ012).
          #
          # @return [void]
          def check_attribute_references(element, declaration, ids, collector,
                                         repository)
            typed_attributes(declaration, repository, "IDREF").each do |attr|
              report_tokens(element, attr, ids, collector,
                            instance_value(element, attr))
            end
            typed_attributes(declaration, repository, "IDREFS").each do |attr|
              report_tokens(element, attr, ids, collector,
                            instance_value(element, attr))
            end
          end

          # @return [String, nil]
          def instance_value(element, attr)
            instance = element.attributes.find do |candidate|
              candidate.name == attr.name
            end
            instance&.value || attr.fixed || attr.default
          end

          # @return [void]
          def report_tokens(element, attr, ids, collector, supplied)
            reference_values(supplied).each do |value|
              next if ids.include?(value)

              report_unresolved(value, element, collector,
                                "attribute '#{attr.name}'")
            end
          end

          # IDREF is a single value; IDREFS tokenizes on whitespace.
          #
          # @return [Array<String>]
          def reference_values(supplied)
            supplied.to_s.strip.empty? ? [] : supplied.to_s.split
          end

          # @return [void]
          def report_unresolved(value, xml_element, collector, subject)
            report_error(
              collector,
              code: "idref_violation",
              message: "#{subject} has IDREF value '#{value}' that " \
                       "does not match any ID in the document",
              location: xml_element.xpath,
              context: { value: value },
            )
          end

          # Whether the declaration's type is the named builtin — a
          # direct reference or an inline restriction of it.
          #
          # @return [Boolean]
          def builtin_typed?(declaration, _repository, name)
            builtin_reference?(declaration.type.to_s, name) ||
              builtin_reference?(
                declaration.simple_type&.restriction&.base.to_s, name
              )
          end

          # @return [Boolean]
          def builtin_reference?(reference, name)
            parts = reference.split(":")
            parts.size == 2 && %w[xs xsd].include?(parts.first) &&
              parts.last == name
          end

          # The declaration's own attribute particles typed the builtin:
          # direct attributes, refs resolved to their declarations, and
          # attributeGroup members.
          #
          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>]
          def typed_attributes(schema_element, repository, name)
            type = schema_element.complex_type ||
              repository.resolve_type(schema_element)
            return [] unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

            particles = Array(type.attribute)
            Array(type.attribute_group).each do |group|
              declaration = repository.resolve_attribute_group(
                (group.ref || group.name).to_s.split(":").last,
              )
              particles.concat(Array(declaration&.attribute))
            end

            particles.filter_map do |particle|
              resolved = particle
              unless particle.ref.to_s.empty?
                resolved = repository.resolve_attribute(
                  particle.ref.split(":").last, nil
                )
              end
              next nil unless resolved && builtin_typed?(resolved, repository,
                                                         name)

              resolved
            end
          end
        end
      end
    end
  end
end
