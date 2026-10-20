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
        def initialize(repository)
          @repository = repository
          @namespaces = {}.compare_by_identity
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

          local = reference.to_s.split(":").last
          schemas.each do |schema|
            found = Array(schema.complex_type).find { |ct| ct.name == local }
            return found if found

            found = Array(schema.simple_type).find { |st| st.name == local }
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
          return nil unless type.respond_to?(:sequence) || type.respond_to?(:choice) || type.respond_to?(:all)

          type.sequence || type.choice || type.all
        end

        private

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
            namespace = schema.target_namespace
            Array(schema.element).each do |element|
              index_element(index, element, namespace, :top)
            end
            Array(schema.complex_type).each do |complex_type|
              index_type(index, complex_type, namespace)
            end
          end
          # Prefer top-level declarations over inline ones.
          index.each_value do |candidates|
            candidates.sort_by! { |_element, _ns, kind| kind == :top ? 0 : 1 }
          end
          index
        end

        def index_element(index, element, namespace, kind)
          return unless element

          @namespaces[element] = namespace
          unless element.name.nil? || element.name.empty?
            index[element.name] << [element, namespace, kind]
          end
          index_type(index, element.complex_type, namespace) if element.complex_type
        end

        def index_type(index, complex_type, namespace)
          return unless complex_type

          each_particle_element(complex_type) do |element|
            index_element(index, element, namespace, :inline)
          end
        end

        def each_particle_element(node, &)
          return unless node

          %i[sequence choice all].each do |kind|
            next unless node.respond_to?(kind) # optional particle collections

            particle = node.public_send(kind)
            next unless particle

            Array(particle.element).each(&)
            %i[sequence choice all].each do |nested|
              next unless particle.respond_to?(nested)

              Array(particle.public_send(nested)).each do |child|
                each_particle_element(child, &)
              end
            end
          end

          return unless node.respond_to?(:complex_content) && node.complex_content

          %i[extension restriction].each do |kind|
            part = node.complex_content.public_send(kind)
            each_particle_element(part, &) if part
          end
        end
      end
    end
  end
end
