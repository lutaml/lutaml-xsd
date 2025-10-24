# frozen_string_literal: true

require "yaml"
require "zip"

module Lutaml
  module Xsd
    # A fully resolved, validated, searchable collection of XSD schemas
    # Provides namespace-aware type resolution across multiple schemas
    class SchemaRepository < Lutaml::Model::Serializable
      # Serializable attributes
      attribute :files, :string, collection: true
      attribute :schema_location_mappings, SchemaLocationMapping, collection: true
      attribute :namespace_mappings, NamespaceMapping, collection: true

      yaml do
        map "files", to: :files
        map "schema_location_mappings", to: :schema_location_mappings
        map "namespace_mappings", to: :namespace_mappings
      end

      # Internal state (not serialized)
      attr_reader :lazy_load

      def initialize(**attributes)
        super
        @parsed_schemas = {}
        @namespace_registry = NamespaceRegistry.new
        @type_index = TypeIndex.new
        @lazy_load = true
        @resolved = false
        @validated = false
      end

      # Parse XSD schemas from configured files
      # @param schema_locations [Hash] Additional schema location mappings
      # @param lazy_load [Boolean] Whether to lazy load imported schemas
      # @return [self]
      def parse(schema_locations: {}, lazy_load: true)
        @lazy_load = lazy_load

        # Register namespace mappings loaded from YAML with the namespace registry
        if namespace_mappings && !namespace_mappings.empty?
          namespace_mappings.each do |mapping|
            @namespace_registry.register(mapping.prefix, mapping.uri)
          end
        end

        # Convert schema_location_mappings to Glob format
        glob_mappings = (schema_location_mappings || []).map(&:to_glob_format)

        # Add any additional schema locations
        if schema_locations && !schema_locations.empty?
          schema_locations.each do |from, to|
            glob_mappings << { from: from, to: to }
          end
        end

        # Parse each schema file
        (files || []).each do |file_path|
          parse_schema_file(file_path, glob_mappings)
        end

        self
      end

      # Force full resolution of all imports/includes and build indexes
      # @return [self]
      def resolve
        return self if @resolved

        # Get all processed schemas including imports/includes
        all_schemas = get_all_processed_schemas

        # Extract namespaces from parsed schemas if not configured
        if namespace_mappings.nil? || namespace_mappings.empty?
          @namespace_registry.extract_from_schemas(all_schemas.values)
        else
          # Register namespace mappings from configuration
          namespace_mappings.each do |mapping|
            @namespace_registry.register(mapping.prefix, mapping.uri)
          end
        end

        # Build type index from all parsed schemas (including imported/included)
        @type_index.build_from_schemas(all_schemas)

        @resolved = true
        self
      end

      # Validate the repository
      # @param strict [Boolean] Whether to fail on first error or collect all
      # @return [Array<String>] List of validation errors (empty if valid)
      def validate(strict: false)
        errors = []

        # Check that all files exist and are accessible
        (files || []).each do |file_path|
          next if File.exist?(file_path)

          error = "Schema file not found: #{file_path}"
          errors << error
          raise Error, error if strict
        end

        # Check that all schemas were parsed successfully
        missing_schemas = (files || []).reject { |f| @parsed_schemas.key?(f) }
        unless missing_schemas.empty?
          error = "Failed to parse schemas: #{missing_schemas.join(", ")}"
          errors << error
          raise Error, error if strict
        end

        # Check for circular imports (simple check)
        check_circular_imports(errors, strict)

        # Check that namespace mappings are valid
        (namespace_mappings || []).each do |mapping|
          if mapping.prefix.nil? || mapping.prefix.empty?
            error = "Invalid namespace mapping: prefix cannot be empty"
            errors << error
            raise Error, error if strict
          end
          next unless mapping.uri.nil? || mapping.uri.empty?

          error = "Invalid namespace mapping for prefix '#{mapping.prefix}': URI cannot be empty"
          errors << error
          raise Error, error if strict
        end

        @validated = errors.empty?
        errors
      end

      # Configure a single namespace prefix mapping
      # @param prefix [String] The namespace prefix (e.g., "gml")
      # @param uri [String] The namespace URI
      # @return [self]
      def configure_namespace(prefix:, uri:)
        @namespace_mappings ||= []
        @namespace_mappings << NamespaceMapping.new(prefix: prefix, uri: uri)
        @namespace_registry.register(prefix, uri)
        self
      end

      # Configure multiple namespace prefix mappings
      # @param mappings [Hash, Array] Prefix-to-URI mappings
      # @return [self]
      def configure_namespaces(mappings)
        case mappings
        when Hash
          mappings.each { |prefix, uri| configure_namespace(prefix: prefix, uri: uri) }
        when Array
          mappings.each do |mapping|
            if mapping.is_a?(NamespaceMapping)
              configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
            elsif mapping.is_a?(Hash)
              prefix = mapping[:prefix] || mapping["prefix"]
              uri = mapping[:uri] || mapping["uri"]
              configure_namespace(prefix: prefix, uri: uri)
            end
          end
        end
        self
      end

      # Resolve a qualified type name to its definition
      # @param qname [String] Qualified name (e.g., "gml:CodeType", "{http://...}CodeType")
      # @return [TypeResolutionResult]
      def find_type(qname)
        resolution_path = [qname]

        # Parse the qualified name
        parsed = QualifiedNameParser.parse(qname, @namespace_registry)
        unless parsed
          return TypeResolutionResult.failure(
            qname: qname,
            error_message: "Failed to parse qualified name: #{qname}",
            resolution_path: resolution_path
          )
        end

        namespace = parsed[:namespace]
        local_name = parsed[:local_name]

        # Add Clark notation to resolution path
        clark_notation = QualifiedNameParser.to_clark_notation(parsed)
        resolution_path << clark_notation if clark_notation != qname

        # Check if namespace was resolved
        unless namespace
          return TypeResolutionResult.failure(
            qname: qname,
            local_name: local_name,
            error_message: "Namespace prefix '#{parsed[:prefix]}' not registered",
            resolution_path: resolution_path
          )
        end

        # Look up type in index
        type_info = @type_index.find_by_namespace_and_name(namespace, local_name)

        if type_info
          resolution_path << "#{type_info[:schema_file]}##{local_name}"

          TypeResolutionResult.success(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            definition: type_info[:definition],
            schema_file: type_info[:schema_file],
            resolution_path: resolution_path
          )
        else
          # Provide suggestions for similar types
          suggestions = @type_index.suggest_similar(namespace, local_name)
          suggestion_text = suggestions.empty? ? "" : " Did you mean: #{suggestions.join(", ")}?"

          TypeResolutionResult.failure(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            error_message: "Type '#{local_name}' not found in namespace '#{namespace}'.#{suggestion_text}",
            resolution_path: resolution_path
          )
        end
      end

      # Get repository statistics
      # @return [Hash] Statistics about the repository
      def statistics
        type_stats = @type_index.statistics

        {
          total_schemas: @parsed_schemas.size,
          total_types: type_stats[:total_types],
          types_by_category: type_stats[:by_type],
          total_namespaces: type_stats[:namespaces],
          namespace_prefixes: @namespace_registry.all_prefixes.size,
          resolved: @resolved,
          validated: @validated
        }
      end

      # Get all registered namespace URIs
      # @return [Array<String>]
      def all_namespaces
        @namespace_registry.all_uris
      end

      # Export repository as a ZIP package with schemas and metadata
      # @param output_path [String] Path to output ZIP file
      # @param xsd_mode [Symbol] :include_all or :allow_external
      # @param resolution_mode [Symbol] :bare or :resolved
      # @param serialization_format [Symbol] :marshal, :json, :yaml, or :parse
      # @param metadata [Hash] Additional metadata to include
      # @return [SchemaRepositoryPackage] Created package
      def to_package(output_path, xsd_mode: :include_all, resolution_mode: :resolved, serialization_format: :marshal,
                     metadata: {})
        # Ensure repository is resolved if creating resolved package
        resolve unless @resolved || resolution_mode == :bare

        # Create package configuration
        config = PackageConfiguration.new(
          xsd_mode: xsd_mode,
          resolution_mode: resolution_mode,
          serialization_format: serialization_format
        )

        # Delegate to SchemaRepositoryPackage
        SchemaRepositoryPackage.create(
          repository: self,
          output_path: output_path,
          config: config,
          metadata: metadata
        )
      end

      # Check if repository needs parsing
      # Used by demo scripts to determine if parse() should be called
      # @return [Boolean] True if schemas need to be parsed from XSD files
      def needs_parsing?
        # Check if schemas are already in the global cache
        # (either from package loading or previous parse)
        get_all_processed_schemas.empty?
      end

      # Validate a schema repository package
      # @param zip_path [String] Path to ZIP package file
      # @return [SchemaRepositoryPackage::ValidationResult] Validation results
      def self.validate_package(zip_path)
        package = SchemaRepositoryPackage.new(zip_path)
        package.validate
      end

      # Load repository from a ZIP package
      # @param zip_path [String] Path to ZIP package file
      # @return [SchemaRepository] Loaded repository
      def self.from_package(zip_path)
        package = SchemaRepositoryPackage.new(zip_path)
        package.load_repository
      end

      # Load repository configuration from a YAML file
      # @param yaml_path [String] Path to YAML configuration file
      # @return [SchemaRepository] Configured repository
      def self.from_yaml_file(yaml_path)
        yaml_content = File.read(yaml_path)
        base_dir = File.dirname(yaml_path)

        # Use Lutaml::Model's from_yaml to deserialize
        repository = from_yaml(yaml_content)

        # Resolve relative paths in files attribute
        if repository.files
          repository.instance_variable_set(
            :@files,
            repository.files.map do |file|
              File.absolute_path?(file) ? file : File.expand_path(file, base_dir)
            end
          )
        end

        # Resolve relative paths in schema_location_mappings
        repository.schema_location_mappings&.each do |mapping|
          mapping.instance_variable_set(:@to, File.expand_path(mapping.to, base_dir)) unless File.absolute_path?(mapping.to)
        end

        repository
      end

      private

      # Get all processed schemas including imported/included schemas
      # @return [Hash] All schemas from the global processed_schemas cache
      def get_all_processed_schemas
        # Access the global processed_schemas cache from Schema class
        Schema.processed_schemas
      end

      # Parse a single schema file
      # @param file_path [String] Path to schema file
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def parse_schema_file(file_path, glob_mappings)
        return if @parsed_schemas.key?(file_path)
        return unless File.exist?(file_path)

        xsd_content = File.read(file_path)
        parsed_schema = Lutaml::Xsd.parse(
          xsd_content,
          location: File.dirname(file_path),
          schema_mappings: glob_mappings
        )

        @parsed_schemas[file_path] = parsed_schema
      rescue StandardError => e
        warn "Warning: Failed to parse schema #{file_path}: #{e.message}"
      end

      # Check for circular imports (simplified check)
      # @param errors [Array<String>] Array to collect errors
      # @param strict [Boolean] Whether to raise on first error
      def check_circular_imports(errors, strict)
        # Track schema dependencies
        dependencies = {}

        @parsed_schemas.each do |file_path, schema|
          deps = []
          (schema.imports || []).each do |import|
            deps << import.schema_path if import.respond_to?(:schema_path)
          end
          (schema.includes || []).each do |include|
            deps << include.schema_path if include.respond_to?(:schema_path)
          end
          dependencies[file_path] = deps.compact
        end

        # Simple circular dependency check using DFS
        visited = {}
        dependencies.each_key do |file|
          next unless has_circular_dependency?(file, dependencies, visited, [])

          error = "Circular import detected involving: #{file}"
          errors << error
          raise Error, error if strict
        end
      end

      # Check for circular dependency using depth-first search
      # @param file [String] Current file to check
      # @param dependencies [Hash] Dependency graph
      # @param visited [Hash] Visited nodes tracking
      # @param path [Array<String>] Current path being explored
      # @return [Boolean] True if circular dependency found
      def has_circular_dependency?(file, dependencies, visited, path)
        return false if visited[file] == :permanent

        if path.include?(file)
          return true # Circular dependency found
        end

        visited[file] = :temporary
        path.push(file)

        (dependencies[file] || []).each do |dep|
          return true if has_circular_dependency?(dep, dependencies, visited, path)
        end

        path.pop
        visited[file] = :permanent
        false
      end
    end
  end
end

require_relative "schema_repository/namespace_registry"
require_relative "schema_repository/type_index"
require_relative "schema_repository/qualified_name_parser"
