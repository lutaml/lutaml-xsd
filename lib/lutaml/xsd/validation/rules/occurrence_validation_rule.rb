# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # OccurrenceValidationRule validates occurrence constraints
        #
        # This rule checks:
        # - minOccurs constraint is satisfied
        # - maxOccurs constraint is satisfied (including unbounded)
        # - Element occurrence counts
        # - Reports violations with expected vs actual counts
        #
        # Based on Jing validator occurrence validation algorithm.
        #
        # @example Using the rule
        #   rule = OccurrenceValidationRule.new
        #   rule.validate(parent_element, schema_particle, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Occurrence Validation
        class OccurrenceValidationRule < ValidationRule
          # Rule category
          #
          # @return [Symbol] :constraint
          def category
            :constraint
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates minOccurs and maxOccurs constraints on elements"
          end

          # Validate occurrence constraints
          #
          # Validates that elements appear the correct number of times
          # according to their minOccurs and maxOccurs constraints.
          #
          # @param parent_element [XmlElement] The parent XML element
          # @param schema_particle [Lutaml::Xsd::Element, Lutaml::Xsd::Sequence,
          #   Lutaml::Xsd::Choice, Lutaml::Xsd::All] The schema particle
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(parent_element, schema_particle, collector,
                       repository: nil)
            return unless schema_particle
            return unless parent_element

            # Handle different particle types
            case schema_particle
            when Lutaml::Xsd::Element
              validate_element_occurrence(parent_element, schema_particle,
                                          collector, repository: repository)
            when Lutaml::Xsd::Sequence
              validate_sequence_occurrences(parent_element, schema_particle,
                                            collector, repository: repository)
            when Lutaml::Xsd::Choice
              validate_choice_occurrences(parent_element, schema_particle,
                                          collector, repository: repository)
            when Lutaml::Xsd::All
              validate_all_occurrences(parent_element, schema_particle,
                                       collector, repository: repository)
            when Lutaml::Xml::Schema::Xsd::Group
              expand_group_container(schema_particle, repository).each do |container|
                validate(parent_element, container, collector,
                         repository: repository)
              end
            end
          end

          # This rule validates the element's children against the
          # content-model particle of the element's type.
          #
          # @param schema_def [Object, nil] Resolved schema declaration
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Object, nil]
          def schema_argument(schema_def, repository: nil)
            return nil unless schema_def && repository

            repository.content_model_for(schema_def)
          end

          private

          # Validate element occurrence
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_element_occurrence(parent_element, schema_element,
                                          collector, repository: nil)
            min_occurs = parse_occurs(schema_element.min_occurs, 1)
            max_occurs = parse_max_occurs(schema_element.max_occurs, 1)

            # Count actual occurrences
            actual_count = count_element_occurrences(
              parent_element, schema_element, repository
            )

            # Check minimum occurrence
            validate_min_occurs(parent_element, schema_element, actual_count,
                                min_occurs, collector)

            # Check maximum occurrence
            validate_max_occurs(parent_element, schema_element, actual_count,
                                max_occurs, collector)
          end

          # Validate sequence particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param sequence [Lutaml::Xsd::Sequence] Schema sequence
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_sequence_occurrences(parent_element, sequence,
                                            collector, repository: nil)
            return if sequence.element.empty?

            Array(sequence.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository)
            end

            # Also check nested sequences, choices, groups
            validate_nested_particles(parent_element, sequence, collector,
                                      repository: repository)
          end

          # Validate choice particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param choice [Lutaml::Xsd::Choice] Schema choice
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_choice_occurrences(parent_element, choice, collector,
                                          repository: nil)
            min_occurs = parse_occurs(choice.min_occurs, 1)
            max_occurs = parse_max_occurs(choice.max_occurs, 1)

            # For choice, at least one alternative should be present
            # Count how many alternatives are present
            present_count = count_choice_alternatives(parent_element, choice,
                                                      repository)

            if present_count < min_occurs
              report_error(
                collector,
                code: "choice_min_occurs_violation",
                message: "Choice must have at least #{min_occurs} " \
                         "alternative(s), found #{present_count}",
                location: parent_element.xpath,
                context: {
                  min_occurs: min_occurs,
                  actual: present_count,
                },
              )
            end

            return unless max_occurs != :unbounded && present_count > max_occurs

            report_error(
              collector,
              code: "choice_max_occurs_violation",
              message: "Choice must have at most #{max_occurs} " \
                       "alternative(s), found #{present_count}",
              location: parent_element.xpath,
              context: {
                max_occurs: max_occurs,
                actual: present_count,
              },
            )
          end

          # Validate all particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param all [Lutaml::Xsd::All] Schema all
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_all_occurrences(parent_element, all, collector,
                                       repository: nil)
            return if all.element.empty?

            # In xs:all, each element can appear 0 or 1 times
            # (or based on its minOccurs/maxOccurs)
            Array(all.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository)
            end
          end

          # Validate nested particles (sequences, choices within sequences)
          #
          # @param parent_element [XmlElement] Parent element
          # @param particle [Object] Schema particle
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_nested_particles(parent_element, particle, collector,
                                        repository: nil)
            # Check for nested sequences
            if particle.sequence
              Array(particle.sequence).each do |seq|
                validate_sequence_occurrences(parent_element, seq, collector,
                                              repository: repository)
              end
            end

            # Check for nested choices
            if particle.choice
              Array(particle.choice).each do |choice|
                validate_choice_occurrences(parent_element, choice, collector,
                                            repository: repository)
              end
            end

            # Check for groups
            return unless particle.group

            Array(particle.group).each do |group|
              # TODO: Resolve and validate group reference
            end
          end

          # Count element occurrences in parent
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Integer]
          def count_element_occurrences(parent_element, schema_element,
                                        repository = nil)
            element_name = schema_element.name ||
              schema_element.ref.to_s.split(":").last
            target_ns = resolve_target_namespace(schema_element, repository)

            parent_element.children.count do |child|
              name_matches = child.name == element_name &&
                namespaces_match?(child.namespace_uri, target_ns)
              name_matches ||
                substitution_member?(child, schema_element, repository)
            end
          end

          # Whether the child's declaration is a member of the
          # substitution group headed by the particle's name/ref.
          #
          # @return [Boolean]
          def substitution_member?(child, schema_element, repository)
            return false unless repository

            head = schema_element.ref
            return false if head.to_s.empty?

            declaration = repository.resolve(child.name, child.namespace_uri)
            return false unless declaration

            declaration.substitution_group.to_s.split(":").last ==
              head.to_s.split(":").last
          end

          # Count how many choice alternatives are present
          #
          # @param parent_element [XmlElement] Parent element
          # @param choice [Lutaml::Xsd::Choice] Schema choice
          # @return [Integer]
          def count_choice_alternatives(parent_element, choice,
                                        repository = nil)
            alternatives = Array(choice.element) + Array(choice.any)
            return 0 if alternatives.empty? || parent_element.children.empty?

            # Count instance elements that matched the choice — a single
            # child matching several identical alternatives counts once.
            parent_element.children.count do |child|
              alternatives.any? do |alt_element|
                if alt_element.is_a?(Lutaml::Xml::Schema::Xsd::Any)
                  wildcard_permits?(alt_element, parent_element, child,
                                    repository)
                else
                  count_element_occurrences_for_child(child, alt_element,
                                                      parent_element,
                                                      repository)
                end
              end
            end
          end

          # Whether one instance child matches one alternative declaration.
          def count_element_occurrences_for_child(child, schema_element,
                                                  _parent_element,
                                                  repository)
            element_name = schema_element.name ||
              schema_element.ref.to_s.split(":").last
            target_ns = resolve_target_namespace(schema_element, repository)

            (child.name == element_name &&
              namespaces_match?(child.namespace_uri, target_ns)) ||
              substitution_member?(child, schema_element, repository)
          end

          # Validate minimum occurrence constraint
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param actual_count [Integer] Actual count
          # @param min_occurs [Integer] Minimum occurrences
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_min_occurs(parent_element, schema_element, actual_count,
                                  min_occurs, collector)
            return if actual_count >= min_occurs

            report_error(
              collector,
              code: "min_occurs_violation",
              message: "Element '#{schema_element.name}' must occur at " \
                       "least #{min_occurs} time(s), found #{actual_count}",
              location: parent_element.xpath,
              context: {
                element: schema_element.name,
                min_occurs: min_occurs,
                actual: actual_count,
              },
              suggestion: build_min_occurs_suggestion(schema_element,
                                                      min_occurs, actual_count),
            )
          end

          # Validate maximum occurrence constraint
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param actual_count [Integer] Actual count
          # @param max_occurs [Integer, Symbol] Maximum occurrences
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_max_occurs(parent_element, schema_element, actual_count,
                                  max_occurs, collector)
            return if max_occurs == :unbounded
            return if actual_count <= max_occurs

            report_error(
              collector,
              code: "max_occurs_violation",
              message: "Element '#{schema_element.name}' must occur at " \
                       "most #{max_occurs} time(s), found #{actual_count}",
              location: parent_element.xpath,
              context: {
                element: schema_element.name,
                max_occurs: max_occurs,
                actual: actual_count,
              },
              suggestion: "Remove #{actual_count - max_occurs} " \
                          "occurrence(s) of '#{schema_element.name}'",
            )
          end

          # Parse occurrence value
          #
          # @param value [String, Integer, nil] Occurrence value
          # @param default [Integer] Default value
          # @return [Integer]
          def parse_occurs(value, default)
            return default if value.nil? || value.to_s.empty?

            value.to_i
          end

          # Parse maximum occurrence value (handles "unbounded")
          #
          # @param value [String, Integer, nil] Max occurrence value
          # @param default [Integer] Default value
          # @return [Integer, Symbol]
          def parse_max_occurs(value, default)
            return default if value.nil? || value.to_s.empty?
            return :unbounded if value.to_s == "unbounded"

            value.to_i
          end

          # Resolve target namespace for element
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [String, nil]
          def resolve_target_namespace(schema_element, repository = nil)
            # Inline declarations carry no namespace of their own; the
            # resolver knows the owning schema's target namespace.
            from_index = repository&.target_namespace_for(schema_element)
            return from_index unless from_index.nil?

            schema_element.target_namespace
          end

          # Check if namespaces match
          #
          # @param ns1 [String, nil] First namespace
          # @param ns2 [String, nil] Second namespace
          # @return [Boolean]
          def namespaces_match?(ns1, ns2)
            # Normalize empty strings to nil
            normalized_ns1 = ns1.to_s.empty? ? nil : ns1
            normalized_ns2 = ns2.to_s.empty? ? nil : ns2

            normalized_ns1 == normalized_ns2
          end

          # Build suggestion for min occurs violation
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param min_occurs [Integer] Minimum occurrences
          # @param actual_count [Integer] Actual count
          # @return [String]
          def build_min_occurs_suggestion(schema_element, min_occurs,
                                          actual_count)
            missing = min_occurs - actual_count
            if missing == 1
              "Add 1 occurrence of element '#{schema_element.name}'"
            else
              "Add #{missing} occurrences of element '#{schema_element.name}'"
            end
          end
        end
      end
    end
  end
end
