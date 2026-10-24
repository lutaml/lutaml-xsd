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
          # Types whose particle accessors type_particles reads — all are
          # declared model attributes (lutaml-model 0.8.114+).
          COMPLEX_PARTICLE_TYPES = [
            Lutaml::Xml::Schema::Xsd::ComplexType,
            Lutaml::Xml::Schema::Xsd::ExtensionComplexContent,
            Lutaml::Xml::Schema::Xsd::RestrictionComplexContent,
          ].freeze
          COMPLEX_PARTICLE_KINDS = %i[sequence choice all group].freeze

          # Objects that can appear in a particle list. Annotation (and
          # other mapped children) leak into resolved_element_order and
          # must not reach the walk.
          PARTICLE_TYPES = [
            Lutaml::Xsd::Element,
            Lutaml::Xsd::Any,
            Lutaml::Xsd::Sequence,
            Lutaml::Xsd::Choice,
            Lutaml::Xsd::All,
            Lutaml::Xml::Schema::Xsd::Group,
          ].freeze

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
          def validate(xml_element, schema_def, collector, repository: nil)
            return unless schema_def

            handled = engine_content_check(xml_element, collector) == :handled

            particles = effective_particles(
              xml_element, schema_def, repository
            )
            # nil: an xsi:type override that does not resolve — the type
            # rule already reports it, so no content walk runs here.
            return if particles.nil? || particles.empty?

            # The engine does not check abstract-element usage; scan for
            # it regardless of whether the engine answered.
            scan_abstract_usage(xml_element, particles, collector,
                                repository)
            return if handled

            validate_particle_sequence(xml_element, particles, collector,
                                       repository)
          end

          private

          # Particles of the effective type: an xsi:type override wins over
          # the declared type; the walk then consumes the list in order.
          #
          # @return [Array, nil] nil when an xsi:type override does not
          #   resolve to a known type
          def effective_particles(xml_element, schema_def, repository)
            xsi = repository && xsi_attribute(xml_element, "type")
            if xsi&.value.to_s.match?(/\S/)
              local = xsi.value.to_s.split(":").last
              named = repository.resolve_named_type(local)
              return nil unless named

              return type_particles(named, repository, {}.compare_by_identity)
            end

            case schema_def
            when Lutaml::Xml::Schema::Xsd::Element
              type_def = resolve_type(schema_def, repository)
              return [] unless type_def

              type_particles(type_def, repository, {}.compare_by_identity)
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
              # A rooted group walks as a single particle: the sequence
              # walk's container handling then matches any leaf in any
              # consecutive run, which is permissive-correct for choice
              # and all without the old ambiguity false positive.
              [schema_def]
            else
              type_particles(schema_def, repository, {}.compare_by_identity)
            end
          end

          # Ordered particles of a type: own sequence/choice/all/group
          # particles plus, for extensions, the base type's particles
          # first. Cycle-guarded. Particles are kept whole — nested
          # containers are expanded by the walk's matching, which
          # preserves their own occurrence constraints.
          #
          # @return [Array]
          def type_particles(type, repository, seen)
            return [] if type.nil? || seen.key?(type)
            return [] unless COMPLEX_PARTICLE_TYPES.any? { |k| type.is_a?(k) }

            seen[type] = true
            particles = []

            COMPLEX_PARTICLE_KINDS.each do |kind|
              Array(type.public_send(kind)).each do |particle|
                next unless particle

                # A sequence's direct particles join the walk in order;
                # choice/all/any/element/group stay whole so their own
                # occurrence constraints survive the walk.
                if particle.is_a?(Lutaml::Xsd::Sequence)
                  particles.concat(collect_particles(particle))
                elsif particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
                  particles.concat(
                    expand_group_container(particle, repository),
                  )
                else
                  particles << particle
                end
              end
            end

            if type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) &&
                type.complex_content
              content = type.complex_content
              extension = Array(content.extension).first
              if extension
                base_local = extension.base.to_s.split(":").last
                base_type = base_local && repository&.resolve_named_type(base_local)
                particles = type_particles(base_type, repository, seen) +
                  particles
                COMPLEX_PARTICLE_KINDS.each do |kind|
                  Array(extension.public_send(kind)).each do |particle|
                    next unless particle

                    if particle.is_a?(Lutaml::Xsd::Sequence)
                      particles.concat(collect_particles(particle))
                    else
                      particles << particle
                    end
                  end
                end
              end
            end

            particles
          end

          # Engine-accepted content still needs the checks the engine
          # lacks: abstract element declarations cannot appear in
          # instances. Containers flatten to their leaf declarations —
          # the walk keeps them whole, the scan needs the leaves.
          def scan_abstract_usage(xml_element, particles, collector,
                                  repository)
            leaves = leaf_particles(particles, repository)
            xml_element.children.each do |child|
              leaves.each do |particle|
                next unless particle.is_a?(Lutaml::Xsd::Element)
                next unless particle_matches?(child, particle, repository,
                                              parent: xml_element)
                next unless element_declaration_abstract?(particle, child,
                                                          repository)

                report_error(
                  collector,
                  code: "abstract_element_used",
                  message: "Element '#{child.qualified_name}' is " \
                           "abstract and cannot appear in the instance",
                  location: child.xpath,
                  context: { element: child.qualified_name },
                )
                break
              end
            end
          end

          def leaf_particles(particles, repository)
            particles.flat_map do |particle|
              case particle
              when Lutaml::Xml::Schema::Xsd::Group
                leaf_particles(expand_group_container(particle, repository),
                               repository)
              when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
                leaf_particles(collect_particles(particle), repository)
              else
                [particle]
              end
            end
          end

          # Sequential walk over a particle list (min/max per particle,
          # recursive matching, wildcard permission for unmatched tails).
          #
          # @return [void]
          def validate_particle_sequence(xml_element, particles, collector,
                                         repository)
            return if particles.empty?

            children = xml_element.children
            child_index = 0

            particles.each do |particle|
              min_occurs = parse_occurs(particle.min_occurs, 1)
              # Container particles (nested sequence/choice/all) consume
              # their whole consecutive run: the walk counts individual
              # children, so a default max of 1 would truncate the group
              # after its first child. Explicit caps on containers are
              # enforced loosely for the same reason.
              container = particle.is_a?(Lutaml::Xsd::Sequence) ||
                particle.is_a?(Lutaml::Xsd::Choice) ||
                particle.is_a?(Lutaml::Xsd::All) ||
                particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
              max_occurs = parse_max_occurs(
                particle.max_occurs, container ? :unbounded : 1
              )
              matched_count = 0

              # Try to match children against this particle
              while child_index < children.size
                child = children[child_index]

                break unless particle_matches?(child, particle, repository,
                                               parent: xml_element)

                if particle.is_a?(Lutaml::Xsd::Any)
                  check_strict_wildcard_child(child, particle, collector,
                                              repository)
                elsif particle.is_a?(Lutaml::Xsd::Element) &&
                    element_declaration_abstract?(particle, child, repository)
                  report_error(
                    collector,
                    code: "abstract_element_used",
                    message: "Element '#{child.qualified_name}' is " \
                             "abstract and cannot appear in the instance",
                    location: child.xpath,
                    context: { element: child.qualified_name },
                  )
                end

                matched_count += 1
                child_index += 1

                # Stop if we've reached max occurrences
                break if max_occurs != :unbounded &&
                  matched_count >= max_occurs

                # Child doesn't match, move to next particle
              end

              # Check minimum occurrence
              next unless matched_count < min_occurs
              next if particle.is_a?(Lutaml::Xsd::Any) && min_occurs.zero?
              # A container whose content can match the empty sequence
              # occurs trivially (all-of with every child optional).
              if container && container_matches_empty?(particle, repository)
                next
              end

              report_min_occurs_violation(particle, xml_element, collector,
                                          min_occurs, matched_count)
            end

            # Check for unexpected children after sequence
            return unless child_index < children.size

            wildcard = particles.find { |p| p.is_a?(Lutaml::Xsd::Any) }
            unexpected = children[child_index..]
            unexpected.each do |child|
              if wildcard && wildcard_permits?(wildcard, xml_element, child,
                                               repository)
                check_strict_wildcard_child(child, wildcard, collector,
                                            repository)
                next
              end

              report_error(
                collector,
                code: "unexpected_element_in_sequence",
                message: "Unexpected element '#{child.qualified_name}' " \
                         "in sequence",
                location: child.xpath,
                context: {
                  element: child.qualified_name,
                },
                suggestion: "Remove this element or check sequence order",
              )
            end
          end

          # Whether the matched declaration is abstract: abstract element
          # declarations cannot appear directly in instances (substitution
          # members remain legal). Direct declarations carry their own
          # abstract flag; references resolve to the global declaration.
          def element_declaration_abstract?(particle, child, repository)
            declaration = declaration_for(particle, child, repository)
            return false unless declaration

            truthy?(declaration.abstract) && child.name == declaration.name
          end

          def declaration_for(particle, child, repository)
            return particle if particle.name.to_s.match?(/\S/)
            return nil unless repository

            local = particle.ref.to_s.split(":").last
            repository.resolve(local, child.namespace_uri) ||
              repository.resolve(local, nil)
          end

          def truthy?(value)
            value.to_s == "true"
          end

          # Report an unsatisfied minimum occurrence: a choice container
          # names its alternatives, anything else reports generically.
          #
          # @return [void]
          def report_min_occurs_violation(particle, xml_element, collector,
                                          min_occurs, matched_count)
            if particle.is_a?(Lutaml::Xsd::Choice)
              alternatives = collect_particles(particle).map do |p|
                particle_name(p)
              end
              report_error(
                collector,
                code: "choice_not_satisfied",
                message: "One of the following elements must be present: " \
                         "#{alternatives.join(', ')}",
                location: xml_element.xpath,
                context: { choices: alternatives },
                suggestion: "Add one of: #{alternatives.join(', ')}",
              )
            else
              report_error(
                collector,
                code: "sequence_min_occurs_violation",
                message: "Element '#{particle_name(particle)}' must occur " \
                         "at least #{min_occurs} time(s)",
                location: xml_element.xpath,
                context: {
                  particle: particle_name(particle),
                  min_occurs: min_occurs,
                  actual: matched_count,
                },
              )
            end
          end

          # Engine-first content-model check for this element.
          #
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Collector for results
          # @return [:handled, :skipped] :skipped lets the Ruby walk run
          def engine_content_check(xml_element, collector)
            engine = @options[:engine_context]
            return :skipped unless engine&.supported?

            answer = engine.content_valid(
              xml_element.name, xml_element.moxml_element.children.to_a
            )
            return :skipped if answer.nil?

            unless answer
              report_error(
                collector,
                code: "content_model_error",
                message: "Content of element '#{xml_element.name}' is not " \
                         "valid against its content model",
                location: xml_element.xpath,
              )
            end

            :handled
          end

          # Resolve type from element
          #
          # @param element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::ComplexType, nil]
          def resolve_type(element, repository = nil)
            return element.complex_type if element.complex_type
            return nil unless element.type

            resolved = repository&.resolve_type(element)
            resolved if resolved.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
          end

          # @return [Boolean]
          def wildcard_child_declared?(child, repository)
            return true if repository.nil?

            !repository.resolve(child.name, child.namespace_uri).nil?
          end

          # processContents="strict" on a wildcard demands the matched
          # child be declared; lax/skip place no declaration requirement.
          #
          # @return [void]
          def check_strict_wildcard_child(child, wildcard, collector,
                                          repository)
            return unless wildcard.process_contents.to_s == "strict"
            return if wildcard_child_declared?(child, repository)

            report_error(
              collector,
              code: "wildcard_undeclared_element",
              message: "Element '#{child.qualified_name}' matches " \
                       "xs:any with processContents=strict but is not " \
                       "declared",
              location: child.xpath,
              context: { element: child.qualified_name },
            )
          end

          # Collect particles from content model
          #
          # @param content_model [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All]
          def collect_particles(content_model)
            # resolved_element_order preserves declaration order including
            # xs:any particles (which child_elements drops).
            ordered = content_model.resolved_element_order.to_a.select do |particle|
              PARTICLE_TYPES.any? { |t| particle.is_a?(t) }
            end
            return ordered if ordered.any?

            case content_model
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice
              Array(content_model.element) +
                Array(content_model.any) +
                Array(content_model.sequence) +
                Array(content_model.choice) +
                Array(content_model.group)
            when Lutaml::Xsd::All
              # xs:all holds bare elements only.
              Array(content_model.element)
            else
              []
            end
          end

          # Check if XML element matches schema particle
          #
          # @param xml_element [XmlElement] The XML element
          # @param particle [Object] The schema particle
          # @param repository [SchemaDefinitionResolver, nil]
          # @param parent [XmlElement, nil] Content-model owner, for
          #   wildcard namespace constraints scoped to the target namespace
          # @return [Boolean]
          def particle_matches?(xml_element, particle, repository = nil,
                                parent: nil, group_depth: 0)
            case particle
            when Lutaml::Xsd::Element
              element_matches?(xml_element, particle, repository)
            when Lutaml::Xsd::Any
              wildcard_permits?(particle, parent || xml_element,
                                xml_element, repository)
            when Lutaml::Xml::Schema::Xsd::Group
              expand_group_container(particle, repository,
                                     group_depth).any? do |container|
                particle_matches?(xml_element, container, repository,
                                  parent: parent,
                                  group_depth: group_depth + 1)
              end
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
              # Nested content model: a child matches the container when it
              # matches any leaf particle inside it. Inner ordering is
              # permissive; the outer walk stays sequential.
              collect_particles(particle).any? do |leaf|
                particle_matches?(xml_element, leaf, repository,
                                  parent: parent,
                                  group_depth: group_depth)
              end
            else
              false
            end
          end

          # Check if XML element matches schema element.
          #
          # A substitution-group member matches a reference to its head.
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Boolean]
          def element_matches?(xml_element, schema_element, repository = nil)
            particle_matches_declaration?(xml_element, schema_element,
                                          repository) ||
              substitution_member?(xml_element, schema_element, repository)
          end

          # Whether the instance element's declaration is in the
          # substitution group headed by the particle's name/ref.
          #
          # @param xml_element [XmlElement]
          # @param particle [Lutaml::Xsd::Element]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Boolean]
          def substitution_member?(xml_element, particle, repository)
            return false unless repository

            expected = particle.name || particle.ref
            return false if expected.to_s.empty?

            head_local = expected.to_s.split(":").last
            declaration = repository.resolve(
              xml_element.name, xml_element.namespace_uri
            )
            return false unless declaration

            return false if substitution_blocked?(declaration, head_local,
                                                  repository)

            declaration.substitution_group.to_s.split(":").last == head_local
          end

          # Get particle name for error messages
          #
          # @param particle [Object] The particle
          # @return [String]
          def particle_name(particle)
            if particle.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              particle.name || particle.ref
            else
              particle.class.name.split("::").last
            end
          end

          # Whether the container's whole content can match the empty
          # sequence — every leaf particle optional.
          #
          # @return [Boolean]
          def container_matches_empty?(particle, repository)
            leaf_particles([particle], repository).all? do |leaf|
              parse_occurs(leaf.min_occurs, 1).zero?
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
        end
      end
    end
  end
end
