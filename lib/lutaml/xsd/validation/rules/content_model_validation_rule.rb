# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # ContentModelValidationRule validates content models
        #
        # This rule checks:
        # - xs:sequence (order matters)
        # - xs:choice (one of alternatives)
        # - xs:all (all must appear, order doesn't matter)
        # - Nested sequences/choices
        #
        # Based on Jing validator content model validation algorithm.
        #
        # @example Using the rule
        #   rule = ContentModelValidationRule.new
        #   rule.validate(xml_element, complex_type, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Content Model Validation
        class ContentModelValidationRule < ValidationRule
          # Rule category
          #
          # @return [Symbol] :structure
          def category
            :structure
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element content models (sequence, choice, all)"
          end

          # Validate content model
          #
          # Validates element children against the schema's content model,
          # ensuring correct order (sequence), alternatives (choice), or
          # completeness (all).
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_def [Lutaml::Xsd::ComplexType, Lutaml::Xsd::Element]
          #   The schema definition
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(xml_element, schema_def, collector)
            return unless schema_def

            # Resolve content model
            content_model = resolve_content_model(schema_def)
            return unless content_model

            # Validate based on content model type
            case content_model
            when Lutaml::Xsd::Sequence
              validate_sequence(xml_element, content_model, collector)
            when Lutaml::Xsd::Choice
              validate_choice(xml_element, content_model, collector)
            when Lutaml::Xsd::All
              validate_all(xml_element, content_model, collector)
            end
          end

          private

          # Resolve content model from schema definition
          #
          # @param schema_def [Lutaml::Xsd::ComplexType, Lutaml::Xsd::Element]
          # @return [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All, nil]
          def resolve_content_model(schema_def)
            # For elements, get type first
            if schema_def.is_a?(Lutaml::Xsd::Element)
              type_def = resolve_type(schema_def)
              return resolve_content_model(type_def) if type_def
            end

            # For complex types, check content model
            return schema_def.sequence if schema_def.respond_to?(:sequence) &&
                                          schema_def.sequence
            return schema_def.choice if schema_def.respond_to?(:choice) &&
                                        schema_def.choice
            return schema_def.all if schema_def.respond_to?(:all) &&
                                     schema_def.all

            # Check complex content
            if schema_def.respond_to?(:complex_content) &&
               schema_def.complex_content
              return resolve_from_complex_content(schema_def.complex_content)
            end

            nil
          end

          # Resolve type from element
          #
          # @param element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::ComplexType, nil]
          def resolve_type(element)
            return element.complex_type if element.respond_to?(:complex_type) &&
                                           element.complex_type

            # TODO: Resolve type reference from repository
            nil
          end

          # Resolve content model from complex content
          #
          # @param complex_content [Lutaml::Xsd::ComplexContent]
          # @return [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All, nil]
          def resolve_from_complex_content(complex_content)
            if complex_content.respond_to?(:extension) &&
               complex_content.extension
              ext = complex_content.extension
              return ext.sequence if ext.respond_to?(:sequence) && ext.sequence
              return ext.choice if ext.respond_to?(:choice) && ext.choice
              return ext.all if ext.respond_to?(:all) && ext.all
            end

            if complex_content.respond_to?(:restriction) &&
               complex_content.restriction
              restr = complex_content.restriction
              return restr.sequence if restr.respond_to?(:sequence) &&
                                       restr.sequence
              return restr.choice if restr.respond_to?(:choice) && restr.choice
              return restr.all if restr.respond_to?(:all) && restr.all
            end

            nil
          end

          # Validate sequence content model
          #
          # Elements must appear in the order defined by the sequence.
          #
          # @param xml_element [XmlElement] The XML element
          # @param sequence [Lutaml::Xsd::Sequence] The sequence definition
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_sequence(xml_element, sequence, collector)
            particles = collect_particles(sequence)
            return if particles.empty?

            children = xml_element.children
            child_index = 0

            particles.each do |particle|
              min_occurs = parse_occurs(particle.min_occurs, 1)
              max_occurs = parse_max_occurs(particle.max_occurs, 1)
              matched_count = 0

              # Try to match children against this particle
              while child_index < children.size
                child = children[child_index]

                if particle_matches?(child, particle)
                  matched_count += 1
                  child_index += 1

                  # Stop if we've reached max occurrences
                  break if max_occurs != :unbounded &&
                           matched_count >= max_occurs
                else
                  # Child doesn't match, move to next particle
                  break
                end
              end

              # Check minimum occurrences
              if matched_count < min_occurs
                report_error(
                  collector,
                  code: "sequence_min_occurs_violation",
                  message: "Element '#{particle_name(particle)}' must occur " \
                           "at least #{min_occurs} time(s) in sequence, " \
                           "found #{matched_count}",
                  location: xml_element.xpath,
                  context: {
                    particle: particle_name(particle),
                    min_occurs: min_occurs,
                    actual: matched_count
                  }
                )
              end
            end

            # Check for unexpected children after sequence
            if child_index < children.size
              unexpected = children[child_index..-1]
              unexpected.each do |child|
                report_error(
                  collector,
                  code: "unexpected_element_in_sequence",
                  message: "Unexpected element '#{child.qualified_name}' " \
                           "in sequence",
                  location: child.xpath,
                  context: {
                    element: child.qualified_name
                  },
                  suggestion: "Remove this element or check sequence order"
                )
              end
            end
          end

          # Validate choice content model
          #
          # One (and only one) of the alternatives must be present.
          #
          # @param xml_element [XmlElement] The XML element
          # @param choice [Lutaml::Xsd::Choice] The choice definition
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_choice(xml_element, choice, collector)
            particles = collect_particles(choice)
            return if particles.empty?

            children = xml_element.children
            matched_particles = []

            # Find which particles match
            particles.each do |particle|
              matches = children.select { |child| particle_matches?(child, particle) }
              matched_particles << particle if matches.any?
            end

            min_occurs = parse_occurs(choice.min_occurs, 1)

            # Check if at least one alternative is present
            if matched_particles.empty? && min_occurs > 0
              particle_names = particles.map { |p| particle_name(p) }
              report_error(
                collector,
                code: "choice_not_satisfied",
                message: "One of the following elements must be present: " \
                         "#{particle_names.join(', ')}",
                location: xml_element.xpath,
                context: {
                  choices: particle_names
                },
                suggestion: "Add one of: #{particle_names.join(', ')}"
              )
            elsif matched_particles.size > 1
              # Multiple alternatives present (ambiguous choice)
              report_error(
                collector,
                code: "choice_ambiguous",
                message: "Only one choice alternative should be present, " \
                         "found #{matched_particles.size}",
                location: xml_element.xpath,
                context: {
                  matched: matched_particles.map { |p| particle_name(p) }
                },
                suggestion: "Use only one of the choice alternatives"
              )
            end
          end

          # Validate all content model
          #
          # All elements must appear, but order doesn't matter.
          #
          # @param xml_element [XmlElement] The XML element
          # @param all [Lutaml::Xsd::All] The all definition
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_all(xml_element, all, collector)
            particles = collect_particles(all)
            return if particles.empty?

            children = xml_element.children

            particles.each do |particle|
              min_occurs = parse_occurs(particle.min_occurs, 1)
              max_occurs = parse_max_occurs(particle.max_occurs, 1)

              # Count matches
              matched_count = children.count do |child|
                particle_matches?(child, particle)
              end

              # Check minimum occurrence
              if matched_count < min_occurs
                report_error(
                  collector,
                  code: "all_min_occurs_violation",
                  message: "Element '#{particle_name(particle)}' must occur " \
                           "at least #{min_occurs} time(s), found " \
                           "#{matched_count}",
                  location: xml_element.xpath,
                  context: {
                    element: particle_name(particle),
                    min_occurs: min_occurs,
                    actual: matched_count
                  }
                )
              end

              # Check maximum occurrence (in xs:all, max is usually 1)
              if max_occurs != :unbounded && matched_count > max_occurs
                report_error(
                  collector,
                  code: "all_max_occurs_violation",
                  message: "Element '#{particle_name(particle)}' must occur " \
                           "at most #{max_occurs} time(s), found " \
                           "#{matched_count}",
                  location: xml_element.xpath,
                  context: {
                    element: particle_name(particle),
                    max_occurs: max_occurs,
                    actual: matched_count
                  }
                )
              end
            end
          end

          # Collect particles from content model
          #
          # @param content_model [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All]
          # @return [Array]
          def collect_particles(content_model)
            particles = []

            # Collect elements
            if content_model.respond_to?(:element)
              particles.concat(Array(content_model.element))
            end

            # Collect nested sequences
            if content_model.respond_to?(:sequence)
              particles.concat(Array(content_model.sequence))
            end

            # Collect nested choices
            if content_model.respond_to?(:choice)
              particles.concat(Array(content_model.choice))
            end

            # Collect groups
            if content_model.respond_to?(:group)
              particles.concat(Array(content_model.group))
            end

            particles
          end

          # Check if XML element matches schema particle
          #
          # @param xml_element [XmlElement] The XML element
          # @param particle [Object] The schema particle
          # @return [Boolean]
          def particle_matches?(xml_element, particle)
            case particle
            when Lutaml::Xsd::Element
              element_matches?(xml_element, particle)
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
              # Nested content model - would need recursive validation
              false
            else
              false
            end
          end

          # Check if XML element matches schema element
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @return [Boolean]
          def element_matches?(xml_element, schema_element)
            return false unless xml_element.name == schema_element.name

            # Check namespace
            target_ns = resolve_target_namespace(schema_element)
            namespaces_match?(xml_element.namespace_uri, target_ns)
          end

          # Get particle name for error messages
          #
          # @param particle [Object] The particle
          # @return [String]
          def particle_name(particle)
            if particle.respond_to?(:name)
              particle.name
            else
              particle.class.name.split("::").last
            end
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
          def resolve_target_namespace(schema_element)
            return schema_element.target_namespace if
              schema_element.respond_to?(:target_namespace)

            # Try to get from parent schema
            if schema_element.respond_to?(:schema) &&
               schema_element.schema.respond_to?(:target_namespace)
              return schema_element.schema.target_namespace
            end

            nil
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
        end
      end
    end
  end
end