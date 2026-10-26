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
                                            min_occurs: nil, max_occurs: nil)
            return if sequence.element.empty?
            # A container that may occur zero times voids its inner
            # requirements (mgG012: sequence(e1) maxOccurs="0", empty doc
            # is valid).
            return if max_occurs.nil? &&
              parse_max_occurs(sequence.max_occurs, 1).zero?

            # Group-ref bounds: the sequence repeats as a UNIT, so the
            # children are matched against the element list cyclically
            # and the completed iteration count is checked against the
            # ref's bounds. The sequence's OWN bounds get the same
            # treatment when it repeats (V003: sequence{2,4}(e1,e2)
            # legitimately carries two e1s).
            if min_occurs || max_occurs
              validate_sequence_unit_iterations(parent_element, sequence,
                                                collector, repository,
                                                min_occurs || 0, max_occurs)
              return
            end
            if parse_max_occurs(sequence.max_occurs, 1) != 1
              validate_sequence_unit_iterations(
                parent_element, sequence, collector, repository,
                parse_occurs(sequence.min_occurs, 1),
                parse_max_occurs(sequence.max_occurs, 1)
              )
              return
            end

            Array(sequence.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository)
            end

            # Nested particles are deliberately not recursed into: their
            # children interleave by position, which per-element counts
            # cannot see — a repeated inner sequence's elements
            # legitimately exceed their own maxOccurs across iterations
            # (Q003/V003). Structural exactness for nested bounds is the
            # content rule's NFA matcher verdict.
          end

          # Greedy cyclic scan of the children against the sequence's
          # element list; returns the number of COMPLETED iterations.
          # Optional elements complicate this — a mismatch simply ends
          # the scan, which keeps the approximation conservative.
          #
          # @return [Integer]
          def count_sequence_iterations(parent_element, sequence, repository)
            elements = Array(sequence.element)
            return 0 if elements.empty?

            idx = 0
            iterations = 0
            parent_element.children.each do |child|
              candidate = elements[idx]
              next unless candidate

              unless particle_matches_declaration?(child, candidate,
                                                   repository)
                return iterations
              end

              idx += 1
              if idx == elements.size
                iterations += 1
                idx = 0
              end
            end
            iterations
          end

          # @return [void]
          def validate_sequence_unit_iterations(parent_element, sequence,
                                                collector, repository,
                                                min_occurs, max_occurs)
            iterations = count_sequence_iterations(parent_element, sequence,
                                                   repository)

            return if iterations >= min_occurs &&
              (max_occurs == :unbounded || iterations <= max_occurs)

            report_error(
              collector,
              code: if iterations < min_occurs
                      "min_occurs_violation"
                    else
                      "max_occurs_violation"
                    end,
              message: "The model group must occur " \
                       "#{iterations < min_occurs ? 'at least' : 'at most'} " \
                       "#{iterations < min_occurs ? min_occurs : max_occurs} " \
                       "time(s), found #{iterations}",
              location: parent_element.xpath,
              context: { min_occurs: min_occurs, max_occurs: max_occurs,
                         actual: iterations },
            )
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
            return if max_occurs.zero?

            present_count = count_choice_alternatives(parent_element, choice,
                                                      repository)
            occurrence_count = choice_occurrence_count(present_count, choice, repository)

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
          def choice_occurrence_count(present_count, choice, repository)
            if present_count.zero?
              # A choice whose every alternative is optional matches the
              # empty sequence and occurs trivially.
              return 1 if choice_alternatives(choice).all? do |alt|
                parse_occurs(alt.min_occurs, 1).zero?
              end

              return 0
            end

            capacities = choice_alternatives(choice).map do |alt|
              branch_capacity(alt, repository, 0)
            end
            return 1 if capacities.empty?
            return 1 if capacities.include?(:unbounded)
            return 1 if capacities.max >= present_count

            present_count
          end

          # Children one branch iteration can absorb: a branch repeats
          # per its own maxOccurs, and composite branches (group refs,
          # sequences, nested choices) multiply or combine with their
          # contents' capacities — a sequence adds them, a choice takes
          # the largest.
          #
          # @return [Integer, Symbol]
          def branch_capacity(particle, repository, depth)
            return :unbounded if depth > 5

            own = parse_max_occurs(particle.max_occurs, 1)
            return own unless composite_particle?(particle)
            return :unbounded if own == :unbounded

            inner_cap = composite_capacity(particle, repository, depth)
            return :unbounded if inner_cap == :unbounded

            multiplier = own.zero? ? 1 : own
            multiplier * [inner_cap, 1].max
          end

          def composite_particle?(particle)
            particle.is_a?(Lutaml::Xml::Schema::Xsd::Group) ||
              particle.is_a?(Lutaml::Xsd::Sequence) ||
              particle.is_a?(Lutaml::Xsd::Choice)
          end

          def composite_capacity(particle, repository, depth)
            children = if particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
                         container = expand_group_container(particle,
                                                            repository).first
                         container ? choice_alternatives(container) : []
                       else
                         # sequence: capacities add; choice: the largest
                         choice_alternatives(particle)
                       end
            caps = children.map do |child|
              branch_capacity(child, repository, depth + 1)
            end
            return :unbounded if caps.include?(:unbounded)

            if particle.is_a?(Lutaml::Xsd::Sequence)
              caps.sum
            else
              caps.max || 0
            end
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
            return if parse_max_occurs(all.max_occurs, 1).zero?

            # In xs:all, each element can appear 0 or 1 times
            # (or based on its minOccurs/maxOccurs)
            Array(all.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository)
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
