# frozen_string_literal: true

module Lutaml
  module Xsd
    # Analyzes schema dependencies and builds dependency trees
    class SchemaDependencyAnalyzer
      attr_reader :package

      # @param package [SchemaRepositoryPackage] Package to analyze
      def initialize(package)
        @package = package
      end

      # Build dependency tree from entrypoints
      # @param entrypoints [Array<Hash>] Entrypoint information
      # @param depth [Integer, nil] Maximum depth (nil for unlimited)
      # @return [Array<Hash>] Tree structure
      def build_dependency_tree(entrypoints, depth: nil)
        repository = package.load_repository
        visited = Set.new

        entrypoints.map do |entrypoint|
          build_tree_node(repository, entrypoint[:schema], entrypoint[:file],
                          visited, 0, depth)
        end
      end

      private

      # Build a tree node for a schema
      # @param repository [SchemaRepository] Repository for schema lookups
      # @param schema [Schema] Schema to analyze
      # @param filename [String] Schema filename
      # @param visited [Set] Set of visited schema locations
      # @param current_depth [Integer] Current depth in tree
      # @param max_depth [Integer, nil] Maximum depth
      # @return [Hash] Tree node
      def build_tree_node(repository, schema, filename, visited, current_depth,
                          max_depth)
        node = {
          file: filename,
          namespace: schema.target_namespace,
          dependencies: [],
        }

        # Stop if we've reached max depth
        return node if max_depth && current_depth >= max_depth

        # Mark as visited to detect circular dependencies
        schema_key = "#{filename}:#{schema.target_namespace}"
        if visited.include?(schema_key)
          node[:circular] = true
          return node
        end

        visited.add(schema_key)

        # Process imports
        schema.imports.each do |import|
          import_schema = find_imported_schema(repository, import)
          next unless import_schema

          import_file = find_schema_filename(repository, import_schema)
          node[:dependencies] << {
            type: "import",
            namespace: import.namespace,
            file: import_file,
            schema: import_schema,
            children: build_tree_node(repository, import_schema, import_file,
                                      visited.dup, current_depth + 1, max_depth),
          }
        end

        # Process includes
        schema.includes.each do |include|
          include_schema = find_included_schema(repository, include)
          next unless include_schema

          include_file = find_schema_filename(repository, include_schema)
          node[:dependencies] << {
            type: "include",
            file: include_file,
            schema: include_schema,
            children: build_tree_node(repository, include_schema, include_file,
                                      visited.dup, current_depth + 1, max_depth),
          }
        end

        node
      end

      # Find imported schema
      # @param repository [SchemaRepository] Repository for schema lookups
      # @param import [Import] Import directive
      # @return [Schema, nil] Imported schema or nil
      def find_imported_schema(repository, import)
        return nil unless import.schema_path

        all_schemas = repository.all_schemas

        # Try to find by schema location
        schema = all_schemas[import.schema_path]
        return schema if schema

        # Try to find by namespace
        all_schemas.each_value do |s|
          return s if s.target_namespace == import.namespace
        end

        nil
      end

      # Find included schema
      # @param repository [SchemaRepository] Repository for schema lookups
      # @param include [Include] Include directive
      # @return [Schema, nil] Included schema or nil
      def find_included_schema(repository, include)
        return nil unless include.schema_path

        repository.all_schemas[include.schema_path]
      end

      # Find filename for a schema
      # @param repository [SchemaRepository] Repository for schema lookups
      # @param schema [Schema] Schema to find filename for
      # @return [String] Filename
      def find_schema_filename(repository, schema)
        repository.all_schemas.each do |location, s|
          return File.basename(location) if s == schema
        end

        "unknown.xsd"
      end
    end
  end
end
