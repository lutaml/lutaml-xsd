# frozen_string_literal: true

require_relative "rule_registry"
require_relative "result_collector"
require_relative "schema_definition_resolver"

module Lutaml
  module Xsd
    module Validation
      # RuleEngine executes validation rules by category
      #
      # This class coordinates the execution of validation rules in a
      # specific order, managing the validation workflow and collecting
      # results. It implements the Strategy pattern, delegating actual
      # validation to individual rules.
      #
      # @example Execute validation rules
      #   engine = RuleEngine.new(registry, collector)
      #   engine.execute_category(:structure, document, repository)
      #
      # @example Execute all rules
      #   engine.execute_all(document, repository)
      class RuleEngine
        include WildcardScope

        # @return [RuleRegistry] The rule registry
        attr_reader :registry

        # @return [ResultCollector] The result collector
        attr_reader :collector

        # Initialize a new RuleEngine
        #
        # @param registry [RuleRegistry] The rule registry
        # @param collector [ResultCollector] The result collector
        def initialize(registry, collector)
          @registry = registry
          @collector = collector
        end

        # Execute all rules in a specific category
        #
        # @param category [Symbol] The rule category to execute
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        #
        # @raise [StopValidationError] if stop-on-first-error is enabled
        def execute_category(category, document, repository)
          rules = @registry.rules_for_category(category)
          return if rules.empty?

          resolver = SchemaDefinitionResolver.new(repository)
          walk_elements(document) do |xml_element, parent, subtree_suppressed|
            # A skip wildcard anywhere up the ancestor chain forbids
            # assessment of the whole subtree (XSD 1.0 §3.9.4.2) —
            # suppression is hereditary (QFE1700a1: the skipped e2's
            # empty xs:int child escapes assessment too).
            next true if subtree_suppressed

            skip_here = skip_wildcard_subtree?(parent, xml_element, resolver) ||
              lax_any_type_child?(parent, xml_element, resolver)
            next true if skip_here

            schema_def = resolver.resolve(
              xml_element.name, xml_element.namespace_uri
            )
            # An UNDECLARED element anchored by xsi:type assesses
            # against the named type (XSD assessment semantics,
            # addB188: the root's attributes must be checked against t
            # even though no global declaration names the element).
            if schema_def.nil?
              override_type = resolver.resolve_named_type(
                xsi_type_local(xml_element).to_s,
              )
              schema_def = override_type if override_type
            end
            if parent
              parent_declaration =
                resolver.resolve(parent.name, parent.namespace_uri)
              candidates = resolver.positional_children(parent_declaration,
                                                        xml_element.name)
              positional = candidates[same_name_sibling_index(xml_element,
                                                              parent)]
              # The binding must agree with the child's OWN namespace:
              # an unqualified ref's global namesake never serves a
              # qualified local namesake (particlesQ016).
              child_ns = xml_element.namespace_uri.to_s
              expected_ns =
                resolver.expected_namespace_for(positional).to_s
              if positional &&
                  ((child_ns.empty? && expected_ns.empty?) ||
                   child_ns == expected_ns)
                schema_def = positional
              end
            end
            rules.each do |rule|
              argument = rule.schema_argument(schema_def, repository: resolver)
              next if argument.nil? && !rule.runs_without_schema?

              execute_rule(rule, xml_element, argument, resolver)
            end
            false
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
          raise
        end

        # Execute all registered rules
        #
        # Executes rules in category order: structure, type, constraint,
        # facet, identity.
        #
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_all(document, repository)
          execute_category(:structure, document, repository)
          execute_category(:type, document, repository)
          execute_category(:constraint, document, repository)
          execute_category(:facet, document, repository)
          execute_category(:identity, document, repository)
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Execute a single rule for one instance element
        #
        # @param rule [ValidationRule] The rule to execute
        # @param xml_element [XmlElement] The instance element
        # @param schema_argument [Object, nil] What the rule validates against
        # @param resolver [SchemaDefinitionResolver] Named-type resolver
        # @return [void]
        def execute_rule(rule, xml_element, schema_argument, resolver)
          return unless rule.enabled?

          rule.validate(
            xml_element, schema_argument, @collector, repository: resolver
          )
        rescue StandardError => e
          handle_rule_error(rule, e)
        end

        # Execute rules with a custom order
        #
        # @param categories [Array<Symbol>] Categories in desired order
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_with_order(categories, document, repository)
          categories.each do |category|
            execute_category(category, document, repository)
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Execute only enabled rules
        #
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_enabled(document, repository)
          ValidationRule::CATEGORIES.each do |category|
            execute_category(category, document, repository)
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Get execution statistics
        #
        # @return [Hash] Statistics about rule execution
        def statistics
          {
            total_rules: @registry.all_rules(enabled_only: false).size,
            enabled_rules: @registry.all_rules(enabled_only: true).size,
            categories: @registry.categories.size,
            errors_collected: @collector.errors.size,
            warnings_collected: @collector.warnings.size,
            infos_collected: @collector.infos.size,
          }
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            registry: @registry.to_h,
            statistics: statistics,
          }
        end

        # String representation
        #
        # @return [String]
        def to_s
          stats = statistics
          "RuleEngine(#{stats[:enabled_rules]}/#{stats[:total_rules]} rules)"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "registry=#{@registry.inspect} " \
            "collector=#{@collector.class.name}>"
        end

        private

        # Depth-first walk over instance elements. The block returns
        # whether the element's SUBTREE escapes assessment; the decision
        # is inherited by every descendant.
        #
        # @param node [XmlDocument, XmlElement] Start node
        # @param parent [XmlElement, nil]
        # @param inherited [Boolean] the ancestor suppression decision
        # @yieldparam element [XmlElement]
        # @yieldparam parent [XmlElement, nil]
        # @yieldparam inherited [Boolean]
        # @return [void]
        def walk_elements(node, parent = nil, inherited: false, &)
          element = node.is_a?(XmlDocument) ? node.root_element : node
          return unless element

          suppress = yield(element, parent, inherited) || inherited
          element.children.each do |child|
            walk_elements(child, element, inherited: suppress, &)
          end
        end

        # The local part of the element's xsi:type attribute.
        #
        # @return [String, nil]
        def xsi_type_local(xml_element)
          override = xml_element.attributes.find do |attribute|
            attribute.name == "type" &&
              attribute.namespace_uri ==
                ValidationRule::XSI_NAMESPACE
          end
          override && override.value.to_s.split(":").last
        end

        # The child's position among its same-named siblings — the index
        # the positional binding (duplicate same-named declarations,
        # isDefault079) binds to. Computed on the RAW moxml nodes: the
        # wrapper objects are not identity-stable across accessor calls
        # (the IdUniquenessRule lesson).
        #
        # @return [Integer]
        def same_name_sibling_index(element, parent)
          raw_children = Array(parent.moxml_element.elements)
          position = raw_children.index do |node|
            node.equal?(element.moxml_element)
          end
          return 0 if position.nil?

          raw_children.take(position).count { |node| node.name == element.name }
        end

        # Whether the parent's content model holds a processContents
        # skip wildcard whose namespace range admits the child — the
        # child subtree then escapes assessment entirely (addB125).
        # The content matcher's deterministic assignment overrides it:
        # a child a DECLARED particle claims in the leftmost reading is
        # assessed even though a skip wildcard could also admit it
        # (QFE1700c1: the ref claims the second e2; its content must be
        # validated).
        #
        # @return [Boolean]
        def skip_wildcard_subtree?(parent, child, resolver)
          return false unless parent

          claim = @collector.content_claims[child.moxml_element.native]
          return false if claim && claim.first != :wildcard

          declaration = resolver.resolve(parent.name, parent.namespace_uri)
          return false unless declaration

          model = resolver.content_model_for(declaration)
          return false unless model

          collect_wildcards(model, resolver).any? do |wildcard|
            wildcard_process_mode(wildcard) == "skip" &&
              wildcard_permits?(wildcard, parent, child, resolver)
          end
        end

        # A child of an ANYTYPE element validates only against a
        # declaration in its OWN namespace (anyType content is lax —
        # errC007's contract); a child with no exact-namespace
        # declaration is lax-undeclared and its subtree escapes
        # assessment. The namespace fallback never serves this
        # decision: a targeted schema's global is a DIFFERENT element
        # than the unqualified child.
        #
        # @return [Boolean]
        def lax_any_type_child?(parent, child, resolver)
          return false unless parent

          declaration = resolver.resolve(parent.name, parent.namespace_uri)
          return false unless any_type_declaration?(declaration, resolver)

          resolver.resolve_strict(child.name, child.namespace_uri).nil?
        end

        # Whether the declaration's effective type is xs:anyType:
        # declared by reference, or the implicit default for a typeless
        # declaration.
        #
        # @return [Boolean]
        def any_type_declaration?(declaration, resolver)
          return false unless
            declaration.is_a?(Lutaml::Xml::Schema::Xsd::Element)

          return true if resolver.builtin_any_type?(declaration.type.to_s)

          declaration.type.to_s.empty? &&
            declaration.complex_type.nil? &&
            declaration.simple_type.nil?
        end

        # Handle errors that occur during rule execution
        #
        # @param rule [ValidationRule] The rule that failed
        # @param error [StandardError] The error that occurred
        # @return [void]
        def handle_rule_error(rule, error)
          @collector.add_error(
            ValidationError.new(
              code: "rule_execution_error",
              message: "Error executing #{rule.class.name}: #{error.message}",
              severity: :error,
              context: {
                rule: rule.class.name,
                category: rule.category,
                error_class: error.class.name,
                backtrace: error.backtrace&.first(5),
              },
            ),
          )
        end
      end
    end
  end
end
