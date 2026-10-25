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
              # The group REF carries the occurrence bounds; the expanded
              # declaration itself has none.
              expand_group_container(schema_particle, repository).each do |container|
                validate_container_occurrences(
                  parent_element, container, collector,
                  repository: repository,
                  min_occurs: parse_occurs(schema_particle.min_occurs, 1),
                  max_occurs: parse_max_occurs(schema_particle.max_occurs, 1)
                )
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
          def validate_container_occurrences(parent_element, container,
                                             collector, repository:,
                                             min_occurs:, max_occurs:)
            case container
            when Lutaml::Xsd::Sequence
              validate_sequence_occurrences(parent_element, container,
                                            collector, repository: repository,
                                                       min_occurs: min_occurs,
                                                       max_occurs: max_occurs)
            when Lutaml::Xsd::Choice
              validate_choice_occurrences(parent_element, container,
                                          collector, repository: repository,
                                                     min_occurs: min_occurs,
                                                     max_occurs: max_occurs)
            when Lutaml::Xsd::All
              validate_all_occurrences(parent_element, container, collector,
                                       repository: repository,
                                       min_occurs: min_occurs,
                                       max_occurs: max_occurs)
            end
          end

          def validate_sequence_occurrences(parent_element, sequence,
                                            collector, repository: nil,
                                            **)
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
                                          repository: nil, min_occurs: nil,
                                          max_occurs: nil)
            min_occurs ||= parse_occurs(choice.min_occurs, 1)
            max_occurs ||= parse_max_occurs(choice.max_occurs, 1)

            present_count = count_choice_alternatives(parent_element, choice,
                                                      repository)
            occurrence_count = choice_occurrence_count(present_count, choice)

            if occurrence_count < min_occurs
              report_error(
                collector,
                code: "choice_min_occurs_violation",
                message: "Choice must have at least #{min_occurs} " \
                         "alternative(s), found #{occurrence_count}",
                location: parent_element.xpath,
                context: {
                  min_occurs: min_occurs,
                  actual: occurrence_count,
                },
              )
            end

            return unless max_occurs != :unbounded &&
              occurrence_count > max_occurs

            report_error(
              collector,
              code: "choice_max_occurs_violation",
              message: "Choice must have at most #{max_occurs} " \
                       "alternative(s), found #{occurrence_count}",
              location: parent_element.xpath,
              context: {
                max_occurs: max_occurs,
                actual: occurrence_count,
              },
            )
          end

          # One choice occurrence consumes one alternative branch, where
          # the branch particle repeats per its own occurrence bounds —
          # a wildcard with 4..6 absorbs four children in a single
          # choice occurrence. Matched children beyond one branch's
          # capacity imply repeated choice occurrences.
          #
          # @return [Integer]
          def choice_occurrence_count(present_count, choice)
            return present_count if present_count.zero?

            capacities = choice_alternatives(choice).map do |alt|
              parse_max_occurs(alt.max_occurs, 1)
            end
            return 1 if capacities.empty?
            return 1 if capacities.include?(:unbounded)
            return 1 if capacities.max >= present_count

            present_count
          end

          # Choice alternatives are particles of any kind.
          #
          # @return [Array]
          def choice_alternatives(choice)
            Array(choice.element) + Array(choice.any) +
              Array(choice.sequence) + Array(choice.choice) +
              Array(choice.group)
          end

          # Validate all particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param all [Lutaml::Xsd::All] Schema all
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_all_occurrences(parent_element, all, collector,
                                       repository: nil, **)
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
            parent_element.children.count do |child|
              particle_matches_declaration?(child, schema_element,
                                            repository) ||
                substitution_member?(child, schema_element, repository)
            end
          end

          # Whether the child's declaration is a member of the
          # substitution group headed by the particle's name/ref.
          #
          # @return [Boolean]
          def substitution_member?(child, schema_element, repository)
            return false unless repository

            head = schema_element.ref || schema_element.name
            return false if head.to_s.empty?

            head_local = head.to_s.split(":").last
            declaration = repository.resolve(child.name, child.namespace_uri)
            return false unless declaration

            resolved_head = repository.resolve(head_local, nil)
            return false unless resolved_head

            return false if substitution_blocked?(declaration, resolved_head,
                                                  head_local, repository)

            declaration.substitution_group.to_s.split(":").last == head_local
          end

          # Count how many choice alternatives are present
          #
          # @param parent_element [XmlElement] Parent element
          # @param choice [Lutaml::Xsd::Choice] Schema choice
          # @return [Integer]
          def count_choice_alternatives(parent_element, choice,
                                        repository = nil)
            alternatives = choice_alternatives(choice)
            return 0 if alternatives.empty? || parent_element.children.empty?

            # Count instance elements that matched the choice — a single
            # child matching several identical alternatives counts once.
            parent_element.children.count do |child|
              alternatives.any? do |alt_element|
                if alt_element.is_a?(Lutaml::Xml::Schema::Xsd::Any)
                  wildcard_permits?(alt_element, parent_element, child,
                                    repository)
                else
                  particle_matches_child?(child, alt_element, repository,
                                          parent: parent_element)
                end
              end
            end
          end

          # Whether one instance child matches one alternative declaration.
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

            name = schema_element.name.to_s
            display_name = if name.match?(/\S/)
                             name
                           else
                             "ref:#{schema_element.ref}"
                           end
            report_error(
              collector,
              code: "min_occurs_violation",
              message: "Element '#{display_name}' must occur at " \
                       "least #{min_occurs} time(s), found #{actual_count}",
              location: parent_element.xpath,
              context: {
                element: display_name,
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
