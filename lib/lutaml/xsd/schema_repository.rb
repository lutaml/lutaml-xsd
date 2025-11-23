# frozen_string_literal: true

require 'yaml'
require 'zip'
require_relative 'errors'

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
        map 'files', to: :files
        map 'schema_location_mappings', to: :schema_location_mappings
        map 'namespace_mappings', to: :namespace_mappings
      end

      # Internal state (not serialized)
      attr_reader :lazy_load

      def initialize(**attributes)
        # Initialize internal state first
        @parsed_schemas = {}
        @namespace_registry = NamespaceRegistry.new
        @type_index = TypeIndex.new
        @lazy_load = true
        @resolved = false
        @validated = false
        @verbose = false

        # Call super to set attributes from Lutaml::Model::Serializable
        super

        # Register namespace mappings AFTER super sets the attributes
        # This ensures they're available immediately when loading from packages
        return unless namespace_mappings && !namespace_mappings.empty?

        namespace_mappings.each do |mapping|
          @namespace_registry.register(mapping.prefix, mapping.uri)
        end
      end

      # Parse XSD schemas from configured files
      # @param schema_locations [Hash] Additional schema location mappings
      # @param lazy_load [Boolean] Whether to lazy load imported schemas
      # @param verbose [Boolean] Whether to show progress indicators
      # @return [self]
      def parse(schema_locations: {}, lazy_load: true, verbose: false)
        @lazy_load = lazy_load
        @verbose = verbose

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

        # Parse each schema file with progress indicators
        if @verbose
          puts "Parsing #{(files || []).size} schema files..."
          (files || []).each_with_index do |file_path, idx|
            print "\r[#{idx + 1}/#{(files || []).size}] #{File.basename(file_path)}"
            $stdout.flush
            parse_schema_file(file_path, glob_mappings)
          end
          puts "\n✓ All schemas parsed"
        else
          (files || []).each do |file_path|
            parse_schema_file(file_path, glob_mappings)
          end
        end

        self
      end

      # Force full resolution of all imports/includes and build indexes
      # @param verbose [Boolean] Whether to show progress indicators
      # @return [self]
      def resolve(verbose: false)
        return self if @resolved

        @verbose = verbose

        # Get all processed schemas including imports/includes
        all_schemas = get_all_processed_schemas

        if @verbose
          total_imports = count_total_imports(all_schemas)
          if total_imports.positive?
            puts "Resolving #{total_imports} schema dependencies..."

            processed = 0
            all_schemas.each_value do |schema|
              imports = schema.respond_to?(:import) ? schema.import : []
              (imports || []).each do |import|
                processed += 1
                namespace_info = import.respond_to?(:namespace) ? (import.namespace || 'no namespace') : 'unknown'
                print "\r[#{processed}/#{total_imports}] #{namespace_info}"
                $stdout.flush
              end
            end
            puts "\n✓ All dependencies resolved"
          else
            puts '✓ No schema dependencies to resolve'
          end
        end

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
          error = "Failed to parse schemas: #{missing_schemas.join(', ')}"
          errors << error
          raise Error, error if strict
        end

        # Check for circular imports (simple check)
        check_circular_imports(errors, strict)

        # Check that namespace mappings are valid
        (namespace_mappings || []).each do |mapping|
          if mapping.prefix.nil? || mapping.prefix.empty?
            error = 'Invalid namespace mapping: prefix cannot be empty'
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
              prefix = mapping[:prefix] || mapping['prefix']
              uri = mapping[:uri] || mapping['uri']
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

        # Check if namespace was resolved for prefixed names
        # For unprefixed names, namespace can be nil and that's valid
        if parsed[:prefix] && !namespace
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
          suggestion_text = suggestions.empty? ? '' : " Did you mean: #{suggestions.join(', ')}?"

          TypeResolutionResult.failure(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            error_message: "Type '#{local_name}' not found in namespace '#{namespace}'.#{suggestion_text}",
            resolution_path: resolution_path
          )
        end
      end

      # Find an attribute definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified attribute name (e.g., "xml:id")
      # @return [Attribute, nil] The attribute definition or nil if not found
      def find_attribute(qualified_name)
        # Parse the qualified name
        parsed = QualifiedNameParser.parse(qualified_name, @namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Look up attribute in the type index
        attr_info = @type_index.find_by_namespace_and_name(namespace_uri,
                                                           local_name)

        # Return the definition if it's an attribute
        return unless attr_info && attr_info[:type] == :attribute

        attr_info[:definition]
      end

      # Find an element definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified element name (e.g., "gml:FeatureCollection")
      # @return [Element, nil] The element definition or nil if not found
      def find_element(qualified_name)
        # Parse the qualified name
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = get_all_processed_schemas

        # Search all schemas
        all_schemas.each_value do |schema|
          # For unprefixed names (namespace_uri is nil), search in all namespaces
          # For prefixed names, only search in matching namespace
          next if namespace_uri && schema.target_namespace != namespace_uri

          # Search in top-level elements
          elements = schema.element
          elements = [elements] unless elements.is_a?(Array)
          elem = elements.compact.find { |e| e.name == local_name }
          return elem if elem
        end

        nil
      end

      # Find a group definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified group name
      # @return [Group, nil] The group definition or nil if not found
      def find_group(qualified_name)
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = get_all_processed_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          grp = schema.group.find { |g| g.name == local_name }
          return grp if grp
        end

        nil
      end

      # Find an attribute group definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified attribute group name
      # @return [AttributeGroup, nil] The attribute group definition or nil if not found
      def find_attribute_group(qualified_name)
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = get_all_processed_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          ag = schema.attribute_group.find { |g| g.name == local_name }
          return ag if ag
        end

        nil
      end

      # Parse a qualified name into its components
      # @param qualified_name [String] The qualified name to parse
      # @return [Hash, nil] Parsed components with :prefix, :namespace,
      #   :local_name
      def parse_qualified_name(qualified_name)
        QualifiedNameParser.parse(qualified_name, @namespace_registry)
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

      # Classify schemas by role and resolution status
      # @return [Hash] Classification results
      def classify_schemas
        require_relative 'schema_classifier'
        classifier = SchemaClassifier.new(self)
        classifier.classify
      end

      # Get all registered namespace URIs
      # @return [Array<String>]
      def all_namespaces
        @namespace_registry.all_uris
      end

      # Quick type existence check
      # @param qualified_name [String] Qualified name (e.g., "gml:CodeType")
      # @return [Boolean] True if type exists and is resolved
      def type_exists?(qualified_name)
        find_type(qualified_name).resolved?
      end

      # List all type names
      # @param namespace [String, nil] Filter by namespace URI (optional)
      # @param category [Symbol, nil] Filter by category (optional)
      # @return [Array<String>] List of qualified type names
      def all_type_names(namespace: nil, category: nil)
        types = []

        @type_index.all.each_value do |type_info|
          # Filter by namespace if specified
          next if namespace && type_info[:namespace] != namespace

          # Filter by category if specified
          next if category && type_info[:type] != category

          # Build qualified name
          ns = type_info[:namespace]
          name = type_info[:definition]&.name
          next unless name

          prefix = namespace_to_prefix(ns)
          qualified_name = prefix ? "#{prefix}:#{name}" : name
          types << qualified_name
        end

        types.sort
      end

      # Export statistics in different formats
      # @param format [Symbol] Output format (:yaml, :json, or :text)
      # @return [String] Formatted statistics
      def export_statistics(format: :yaml)
        stats = statistics

        case format
        when :yaml
          require 'yaml'
          stats.to_yaml
        when :json
          require 'json'
          JSON.pretty_generate(stats)
        when :text
          format_statistics_as_text(stats)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      # Namespace summary
      # @return [Array<Hash>] Summary of each namespace
      def namespace_summary
        all_namespaces.map do |ns|
          {
            uri: ns,
            prefix: namespace_to_prefix(ns),
            types: types_in_namespace(ns).size
          }
        end
      end

      # Get the namespace prefix for a URI
      # @param namespace_uri [String, nil] The namespace URI
      # @return [String, nil] The prefix or nil
      def namespace_to_prefix(namespace_uri)
        return nil if namespace_uri.nil? || namespace_uri.empty?

        @namespace_registry.get_primary_prefix(namespace_uri)
      end

      # Get detailed namespace prefix information
      # @return [Array<NamespacePrefixInfo>] Detailed prefix information
      def namespace_prefix_details
        manager = NamespacePrefixManager.new(self)
        manager.detailed_prefix_info
      end

      # Remap namespace prefixes
      # @param changes [Hash] Mapping of old_prefix => new_prefix
      # @return [SchemaRepository] New repository with updated prefixes
      def remap_namespace_prefixes(changes)
        remapper = NamespaceRemapper.new(self)
        remapper.remap(changes)
      end

      # Analyze type inheritance hierarchy
      # @param qualified_name [String] The qualified type name (e.g., "gml:AbstractFeatureType")
      # @param depth [Integer] Maximum depth to traverse (default: 10)
      # @return [Hash, nil] Hierarchy analysis result or nil if type not found
      def analyze_type_hierarchy(qualified_name, depth: 10)
        require_relative 'type_hierarchy_analyzer'
        analyzer = TypeHierarchyAnalyzer.new(self)
        analyzer.analyze(qualified_name, depth: depth)
      end

      # Analyze coverage based on entry point types
      # @param entry_types [Array<String>] Entry point type names
      # @return [CoverageReport] Coverage analysis results
      def analyze_coverage(entry_types: [])
        require_relative 'coverage_analyzer'
        analyzer = CoverageAnalyzer.new(self)
        analyzer.analyze(entry_types: entry_types)
      end

      # Validate XSD specification compliance
      # @param version [String] XSD version to validate against ('1.0' or '1.1')
      # @return [SpecComplianceReport] Validation report
      def validate_xsd_spec(version: '1.0')
        require_relative 'xsd_spec_validator'
        validator = XsdSpecValidator.new(self, version: version)
        validator.validate
      end

      # Get all processed schemas (public accessor for validators/analyzers)
      # @return [Hash] All schemas from the global processed_schemas cache
      def all_schemas
        get_all_processed_schemas
      end

      # Get all schemas (alias for compatibility)
      # @return [Hash] All schemas from the global processed_schemas cache
      def schemas
        get_all_processed_schemas
      end

      # Get all elements organized by namespace
      # Returns hash: { namespace_uri => [{element_name, type, minOccurs, maxOccurs, documentation}] }
      # @param namespace_uri [String, nil] Filter by specific namespace URI (optional)
      # @return [Hash{String => Array<Hash>}] Elements grouped by namespace
      def elements_by_namespace(namespace_uri: nil)
        results = {}

        get_all_processed_schemas.each_value do |schema|
          ns = schema.target_namespace
          next if namespace_uri && ns != namespace_uri

          results[ns] ||= []

          (schema.element || []).each do |elem|
            results[ns] << {
              name: elem.name,
              qualified_name: "#{namespace_to_prefix(ns)}:#{elem.name}",
              type: elem.type || '(inline complex type)',
              min_occurs: elem.min_occurs || '1',
              max_occurs: elem.max_occurs || '1',
              documentation: extract_element_documentation(elem)
            }
          end
        end

        results
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

      # Add a schema file to the repository
      # @param file_path [String] Path to the schema file
      # @return [void]
      def add_schema_file(file_path)
        @files ||= []
        @files << file_path unless @files.include?(file_path)
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
          unless File.absolute_path?(mapping.to)
            mapping.instance_variable_set(:@to,
                                          File.expand_path(mapping.to, base_dir))
          end
        end

        repository
      end

      # Auto-detect and load from XSD, LXR, or YAML
      # @param path [String] Path to file (.xsd, .lxr, .yml, or .yaml)
      # @return [SchemaRepository] Loaded repository
      def self.from_file(path)
        # Check file exists first
        raise Errno::ENOENT, "No such file or directory - #{path}" unless File.exist?(path)

        case File.extname(path).downcase
        when '.lxr'
          repo = from_package(path)
          # Ensure loaded repository is resolved
          repo.resolve unless repo.instance_variable_get(:@resolved)
          repo
        when '.xsd'
          repo = new
          repo.instance_variable_set(:@files, [File.expand_path(path)])
          repo.parse.resolve
          repo
        when '.yml', '.yaml'
          repo = from_yaml_file(path)
          # Parse and resolve if needed
          repo.parse.resolve	if repo.needs_parsing?
          repo
        else
          raise ConfigurationError, "Unsupported file type: #{path}. Expected .xsd, .lxr, .yml, or .yaml"
        end
      end

      # Smart caching: only rebuild when source is newer than cache
      # @param source_path [String] Path to source file (.xsd or .yml/.yaml)
      # @param lxr_path [String, nil] Optional path to cache file (default: source with .lxr extension)
      # @return [SchemaRepository] Loaded repository
      def self.from_file_cached(source_path, lxr_path: nil)
        lxr_path ||= source_path.sub(/\.(xsd|ya?ml)$/, '.lxr')

        # Check if cache exists and is fresh
        if File.exist?(lxr_path) &&
           File.mtime(lxr_path) >= File.mtime(source_path)
          # Use from_file to ensure proper resolution
          from_file(lxr_path)
        else
          # Cache missing or stale, rebuild
          repo = from_file(source_path)

          # Create cache package
          repo.to_package(
            lxr_path,
            xsd_mode: :include_all,
            resolution_mode: :resolved,
            serialization_format: :marshal
          )

          repo
        end
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
        # Parse errors are expected for schemas with unresolvable imports
        # The schema still gets added to Schema.processed_schemas by Lutaml::Xsd.parse
        # even if import resolution fails, so local types may still be indexed
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

      # Get all types in a namespace
      # @param namespace_uri [String] The namespace URI
      # @return [Array<Hash>] List of type information
      def types_in_namespace(namespace_uri)
        @type_index.find_all_in_namespace(namespace_uri)
      end

      # Format statistics as human-readable text
      # @param stats [Hash] Statistics hash
      # @return [String] Formatted text
      def format_statistics_as_text(stats)
        lines = []
        lines << 'Schema Repository Statistics'
        lines << ('=' * 40)
        lines << "Total Schemas: #{stats[:total_schemas]}"
        lines << "Total Types: #{stats[:total_types]}"
        lines << "Total Namespaces: #{stats[:total_namespaces]}"
        lines << "Namespace Prefixes: #{stats[:namespace_prefixes]}"
        lines << ''
        lines << 'Types by Category:'
        stats[:types_by_category].each do |type, count|
          lines << "  #{type}: #{count}"
        end
        lines << ''
        lines << "Resolved: #{stats[:resolved]}"
        lines << "Validated: #{stats[:validated]}"
        lines.join("\n")
      end

      # Count total number of imports across all schemas
      # @param schemas [Hash] Hash of schemas
      # @return [Integer] Total import count
      def count_total_imports(schemas)
        schemas.values.sum do |schema|
          imports = schema.respond_to?(:import) ? schema.import : []
          (imports || []).size
        end
      end

      # Extract documentation from an element's annotation
      # @param elem [Element] The element to extract documentation from
      # @return [String] The documentation text or empty string
      def extract_element_documentation(elem)
        return '' unless elem.annotation&.documentation

        docs = elem.annotation.documentation
        docs = [docs] unless docs.is_a?(Array)

        docs.map do |doc|
          content = doc.respond_to?(:content) ? doc.content : doc.to_s
          content&.strip
        end.compact.first || ''
      end
    end
  end
end

require_relative 'schema_repository/namespace_registry'
require_relative 'schema_repository/type_index'
require_relative 'schema_repository/qualified_name_parser'
require_relative 'namespace_prefix_manager'
require_relative 'namespace_remapper'
