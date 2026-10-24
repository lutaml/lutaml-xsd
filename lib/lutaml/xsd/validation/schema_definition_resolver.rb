# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Resolves instance elements to their schema declarations for the
      # rule engine's element-scoped dispatch.
      #
      # Indexes top-level and inline element declarations across the
      # repository's schemas. Namespace matching is strict (a target
      # namespace matches only itself; no-namespace schemas match
      # no-namespace instances) with a unique-name fallback for corpora
      # whose instances omit namespaces.
      #
      # Deliberately not resolved here (rule-engine backlog): dynamic
      # typing via xsi:type and derivation closure.
      class SchemaDefinitionResolver
        # Nested particle accessors per container class — all are declared
        # model attributes (lutaml-model 0.8.114+), so dispatch is by
        # class rather than duck-typed probing. Sequence/Choice cannot
        # nest xs:all, and only xs:all carries bare elements.
        CONTAINER_NESTED_KINDS = {
          Lutaml::Xml::Schema::Xsd::ComplexType => %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::ExtensionComplexContent =>
            %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::RestrictionComplexContent =>
            %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::Group => %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::Sequence => %i[sequence choice],
          Lutaml::Xml::Schema::Xsd::Choice => %i[sequence choice],
          Lutaml::Xml::Schema::Xsd::All => [].freeze,
        }.freeze
        CONTAINER_LEAF_KINDS = {
          Lutaml::Xml::Schema::Xsd::Sequence => %i[element any group],
          Lutaml::Xml::Schema::Xsd::Choice => %i[element any group],
          Lutaml::Xml::Schema::Xsd::All => %i[element].freeze,
        }.freeze

        def initialize(repository)
          @repository = repository
          @namespaces = {}.compare_by_identity
          @expected_namespaces = {}.compare_by_identity
          @attributes = Hash.new { |hash, key| hash[key] = [] }
          @elements = index_elements
        end

        # Owner schema's target namespace for a resolved declaration
        # (parsed element models carry no owner-schema link).
        #
        # @param schema_element [Object]
        # @return [String, nil]
        def target_namespace_for(schema_element)
          @namespaces[schema_element]
        end

        # The namespace a conforming instance element carries for this
        # declaration: the owner schema's target namespace for qualified
        # forms, none for unqualified ones. Global declarations are
        # always qualified; local declarations follow form, defaulting
        # to the schema's elementFormDefault.
        #
        # @param element [Object]
        # @return [String, nil]
        def expected_namespace_for(element)
          return @namespaces[element] unless @expected_namespaces.key?(element)

          @expected_namespaces[element]
        end

        # @param name [String] local element name
        # @param namespace_uri [String, nil] instance element namespace
        # @return [Lutaml::Xml::Schema::Xsd::Element, nil]
        def resolve(name, namespace_uri)
          return nil if name.nil? || name.empty?

          candidates = @elements[name]
          return nil if candidates.empty?

          exact = candidates.find do |_element, namespace, _kind|
            namespace_matches?(namespace, namespace_uri)
          end
          return exact&.first if exact

          # Unique-name fallback for instances that omit namespaces even
          # though the schema declares one. A foreign namespace never
          # falls back.
          return nil unless namespace_uri.to_s.empty?

          candidates.length == 1 ? candidates.first.first : nil
        end

        # Named type for an element's `type="prefix:Name"` reference.
        #
        # @param schema_element [Lutaml::Xml::Schema::Xsd::Element]
        # @return [Object, nil]
        def resolve_type(schema_element)
          reference = schema_element.type
          return nil if reference.nil? || reference.to_s.empty?

          resolve_named_type(reference.to_s.split(":").last)
        end

        # Named complex or simple type by local name.
        #
        # @param local_name [String]
        # @return [Object, nil]
        def resolve_named_type(local_name)
          return nil if local_name.nil? || local_name.empty?

          schemas.each do |schema|
            found = Array(schema.complex_type).find { |ct| ct.name == local_name }
            return found if found

            found = Array(schema.simple_type).find { |st| st.name == local_name }
            return found if found
          end
          nil
        end

        # Global attribute declaration by name (for strict xs:anyAttribute
        # checks).
        #
        # @param name [String] local attribute name
        # @param namespace_uri [String, nil] instance attribute namespace
        # @return [Lutaml::Xml::Schema::Xsd::Attribute, nil]
        def resolve_attribute(name, namespace_uri)
          return nil if name.nil? || name.empty?

          candidates = @attributes[name]
          return nil if candidates.empty?

          exact = candidates.find do |_attribute, namespace|
            namespace_matches?(namespace, namespace_uri)
          end
          return exact&.first if exact

          return nil unless namespace_uri.to_s.empty?

          candidates.length == 1 ? candidates.first.first : nil
        end

        # Named group declaration by local name (for xs:group reference
        # expansion in the content and occurrence walks).
        #
        # @param local_name [String]
        # @return [Lutaml::Xml::Schema::Xsd::Group, nil]
        def resolve_group(local_name)
          return nil if local_name.nil? || local_name.empty?

          schemas.each do |schema|
            found = Array(schema.group).find { |g| g.name == local_name }
            return found if found
          end
          nil
        end

        # Content-model particle of the element's type, for occurrence
        # and content-model rules.
        #
        # @param schema_element [Lutaml::Xml::Schema::Xsd::Element]
        # @return [Object, nil]
        def content_model_for(schema_element)
          type = schema_element.complex_type || resolve_type(schema_element)
          particle_for_type(type)
        end

        # Content-model particle of a NAMED type (for xsi:type overrides).
        #
        # @param local_name [String]
        # @return [Object, nil]
        def content_model_for_named(local_name)
          particle_for_type(resolve_named_type(local_name))
        end

        private

        def particle_for_type(type)
          case type
          when Lutaml::Xml::Schema::Xsd::ComplexType
            direct = Array(type.sequence).first ||
              Array(type.choice).first || Array(type.all).first ||
              Array(type.group).first
            return direct if direct

            # Derived types keep their particles under complex_content.
            if type.complex_content
              content = type.complex_content
              part = Array(content.extension).first ||
                Array(content.restriction).first
              return particle_for_type(part) if part
            end

            nil
          when Lutaml::Xml::Schema::Xsd::ExtensionComplexContent,
               Lutaml::Xml::Schema::Xsd::RestrictionComplexContent
            Array(type.sequence).first ||
              Array(type.choice).first || Array(type.all).first
          end
        end

        def schemas
          @schemas ||= @repository.all_schemas.values
        end

        def namespace_matches?(schema_namespace, instance_namespace)
          schema_namespace.to_s.empty? == instance_namespace.to_s.empty? &&
            schema_namespace.to_s == instance_namespace.to_s
        end

        def index_elements
          index = Hash.new { |hash, key| hash[key] = [] }
          schemas.each do |schema|
            index_schema(index, schema)
          rescue StandardError
            # Repositories can carry unparsable entries (broken packages);
            # they contribute no declarations.
            next
          end
          # Prefer top-level declarations over inline ones.
          index.each_value do |candidates|
            candidates.sort_by! { |_element, _ns, kind| kind == :top ? 0 : 1 }
          end
          index
        end

        def index_schema(index, schema)
          namespace = schema.target_namespace
          Array(schema.element).each do |element|
            index_element(index, element, namespace, :top, schema)
          end
          Array(schema.complex_type).each do |complex_type|
            index_type(index, complex_type, namespace, schema)
          end
          Array(schema.attribute).each do |attribute|
            index_attribute(attribute, namespace)
          end
          Array(schema.group).each do |group|
            each_particle_element(group, schema) do |element|
              index_element(index, element, namespace, :inline, schema)
            end
          end
          # lutaml-model nests resolved xs:import / xs:include targets
          # as child Schema objects (raw Import models stay for
          # unresolvable locations); their declarations validate too.
          (Array(schema.import) + Array(schema.include)).each do |nested|
            index_schema(index, nested) if
              nested.is_a?(Lutaml::Xml::Schema::Xsd::Schema)
          end
        end

        def index_attribute(attribute, namespace)
          return unless attribute
          return if attribute.name.nil? || attribute.name.empty?

          @namespaces[attribute] = namespace
          @attributes[attribute.name] << [attribute, namespace]
        end

        def index_element(index, element, namespace, kind, schema)
          return unless element

          @namespaces[element] = namespace
          @expected_namespaces[element] =
            effective_element_namespace(element, namespace, kind, schema)
          unless element.name.nil? || element.name.empty?
            index[element.name] << [element, namespace, kind]
          end
          if element.complex_type
            index_type(index, element.complex_type, namespace, schema)
          end
        end

        # Form-aware expected namespace (XSD 1.0 §3.3.2): explicit form
        # wins, absent form follows elementFormDefault, and top-level
        # declarations are always qualified.
        def effective_element_namespace(element, namespace, kind, schema)
          form = element.form.to_s
          return nil if form == "unqualified"
          return namespace if form == "qualified"
          return namespace if kind == :top

          schema.element_form_default.to_s == "qualified" ? namespace : nil
        end

        def index_type(index, complex_type, namespace, schema)
          return unless complex_type

          each_particle_element(complex_type, schema) do |element|
            index_element(index, element, namespace, :inline, schema)
          end
        end

        def each_particle_element(node, schema, &)
          return unless node

          if node.is_a?(Array)
            node.each { |child| each_particle_element(child, schema, &) }
            return
          end
          return if visited_particle?(node)

          nested = CONTAINER_NESTED_KINDS[node.class]
          return unless nested

          nested.each do |kind|
            Array(node.public_send(kind)).each do |particle|
              each_particle_element(particle, schema, &) if particle
            end
          end
          (CONTAINER_LEAF_KINDS[node.class] || []).each do |kind|
            Array(node.public_send(kind)).each do |leaf|
              # xs:any wildcards and xs:group references are not element
              # declarations; the index holds Element models only.
              yield leaf if leaf.is_a?(Lutaml::Xml::Schema::Xsd::Element)
            end
          end

          if node.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
            walk_complex_content(node, schema, &)
          end
        end

        def walk_complex_content(node, schema, &)
          content = node.complex_content
          return unless content

          %i[extension restriction].each do |kind|
            part = content.public_send(kind)
            each_particle_element(part, schema, &) if part
          end
        end

        # Particle collections can be cyclic in parsed models (a nested
        # sequence pointing back at its container); visit each node once.
        def visited_particle?(node)
          @visited ||= {}.compare_by_identity
          return true if @visited[node]

          @visited[node] = true
          false
        end
      end
    end
  end
end
