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

            return if engine_content_check(xml_element, collector) == :handled

            particles = effective_particles(
              xml_element, schema_def, repository
            )
            # nil: an xsi:type override that does not resolve — the type
            # rule already reports it, so no content walk runs here.
            return if particles.nil? || particles.empty?

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

          # Whether a wildcard's namespace constraint admits the child.
          #
          # @param wildcard [Lutaml::Xsd::Any]
          # @param parent [XmlElement] Content-model owner
          # @param child [XmlElement]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Boolean]
          def wildcard_permits?(wildcard, parent, child, repository)
            child_ns = child.namespace_uri.to_s
            case wildcard.namespace.to_s
            when "##any", ""
              true
            when "##other"
              target = content_model_target_namespace(parent, repository)
              !child_ns.empty? && child_ns != target.to_s
            when "##local"
              child_ns.empty?
            when "##targetNamespace"
              child_ns == content_model_target_namespace(parent, repository).to_s
            else
              # space-separated namespace list (##targetNamespace ##local allowed)
              wildcard.namespace.to_s.split(/\s+/).any? do |entry|
                case entry
                when "##local" then child_ns.empty?
                when "##targetNamespace"
                  child_ns == content_model_target_namespace(parent,
                                                             repository).to_s
                else entry == child_ns
                end
              end
            end
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

          # Best-effort target namespace of the schema owning the parent's
          # declaration (via the resolver index).
          #
          # @return [String, nil]
          def content_model_target_namespace(parent, repository)
            return nil unless repository

            declaration = repository.resolve(parent.name, parent.namespace_uri)
            repository.target_namespace_for(declaration) if declaration
          end

          # Collect particles from content model
          #
          # @param content_model [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All]
          # @return [Array]
          def collect_particles(content_model)
            # resolved_element_order preserves declaration order including
            # xs:any particles (which child_elements drops).
            ordered = content_model.resolved_element_order
            return ordered.to_a if ordered.to_a.any?

            particles = []

            # Collect elements
            particles.concat(Array(content_model.element)) if content_model.element.any?

            # Collect wildcards
            particles.concat(Array(content_model.any)) if content_model.any

            # Collect nested sequences
            particles.concat(Array(content_model.sequence)) if content_model.sequence

            # Collect nested choices
            particles.concat(Array(content_model.choice)) if content_model.choice

            # Collect groups
            particles.concat(Array(content_model.group)) if content_model.group

            particles
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
            if xml_element.name == schema_element.name
              return namespaces_match_instance?(
                xml_element,
                resolve_target_namespace(schema_element, repository),
              )
            end

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

            declaration = repository.resolve(
              xml_element.name, xml_element.namespace_uri
            )
            return false unless declaration

            declaration.substitution_group.to_s.split(":").last ==
              expected.to_s.split(":").last
          end

          # @return [Boolean]
          def namespaces_match_instance?(xml_element, target_ns)
            xml_ns = xml_element.namespace_uri
            xml_ns = nil if xml_ns.to_s.empty?
            target_ns = nil if target_ns.to_s.empty?

            xml_ns == target_ns
          end

          # Get particle name for error messages
          #
          # @param particle [Object] The particle
          # @return [String]
          def particle_name(particle)
            particle.name || particle.class.name.split("::").last
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
        end
      end
    end
  end
end
