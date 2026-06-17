# frozen_string_literal: true

module Lutaml
  module Xsd
    # Provides type/element/attribute search across the repository.
    # Extracted from SchemaRepository to separate query concerns.
    class SchemaQueryService
      def initialize(repository)
        @repository = repository
        @type_index = repository.type_index
        @namespace_registry = repository.namespace_registry
      end

      # Resolve a qualified type name to its definition
      def find_type(qname)
        resolution_path = [qname]

        parsed = QualifiedNameParser.parse(qname, @namespace_registry)
        unless parsed
          return TypeResolutionResult.failure(
            qname: qname,
            error_message: "Failed to parse qualified name: #{qname}",
            resolution_path: resolution_path,
          )
        end

        namespace = parsed[:namespace]
        local_name = parsed[:local_name]

        clark_notation = QualifiedNameParser.to_clark_notation(parsed)
        resolution_path << clark_notation if clark_notation != qname

        if parsed[:prefix] && !namespace
          return TypeResolutionResult.failure(
            qname: qname,
            local_name: local_name,
            error_message: "Namespace prefix '#{parsed[:prefix]}' not registered",
            resolution_path: resolution_path,
          )
        end

        type_info = @type_index.find_by_namespace_and_name(namespace, local_name)

        if type_info
          resolution_path << "#{type_info[:schema_file]}##{local_name}"

          TypeResolutionResult.success(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            definition: type_info[:definition],
            schema_file: type_info[:schema_file],
            resolution_path: resolution_path,
          )
        else
          suggestions = @type_index.suggest_similar(namespace, local_name)
          suggestion_text = suggestions.empty? ? "" : " Did you mean: #{suggestions.join(', ')}?"

          TypeResolutionResult.failure(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            error_message: "Type '#{local_name}' not found in namespace '#{namespace}'.#{suggestion_text}",
            resolution_path: resolution_path,
          )
        end
      end

      # Find an element definition by qualified name
      def find_element(qualified_name)
        parsed = QualifiedNameParser.parse(qualified_name, @namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        all_schemas = @repository.all_schemas

        all_schemas.each_value do |schema|
          next if namespace_uri && schema.target_namespace != namespace_uri

          elements = schema.element
          elements = [elements] unless elements.is_a?(Array)
          elem = elements.compact.find { |e| e.name == local_name }
          return elem if elem
        end

        nil
      end

      # Find an attribute definition by qualified name
      def find_attribute(qualified_name)
        parsed = QualifiedNameParser.parse(qualified_name, @namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        attr_info = @type_index.find_by_namespace_and_name(namespace_uri, local_name)
        return unless attr_info && attr_info[:type] == :attribute

        attr_info[:definition]
      end

      # Find a group definition by qualified name
      def find_group(qualified_name)
        parsed = QualifiedNameParser.parse(qualified_name, @namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        all_schemas = @repository.all_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          grp = schema.group.find { |g| g.name == local_name }
          return grp if grp
        end

        nil
      end

      # Find an attribute group definition by qualified name
      def find_attribute_group(qualified_name)
        parsed = QualifiedNameParser.parse(qualified_name, @namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        all_schemas = @repository.all_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          ag = schema.attribute_group.find { |g| g.name == local_name }
          return ag if ag
        end

        nil
      end

      # Quick type existence check
      def type_exists?(qualified_name)
        find_type(qualified_name).resolved?
      end

      # List all type names with optional filtering
      def all_type_names(namespace: nil, category: nil)
        types = []

        @type_index.all.each_value do |type_info|
          next if namespace && type_info[:namespace] != namespace
          next if category && type_info[:type] != category

          name = type_info[:definition]&.name
          next unless name

          ns = type_info[:namespace]
          prefix = @repository.namespace_to_prefix(ns)
          qualified_name = prefix ? "#{prefix}:#{name}" : name
          types << qualified_name
        end

        types.sort
      end
    end
  end
end
