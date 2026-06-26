# frozen_string_literal: true

require "forwardable"
require "lutaml/store"

module Lutaml
  module Xsd
    # A fully resolved, validated, searchable collection of XSD schemas.
    # Delegates to focused service objects for parsing, querying, loading, and export.
    class SchemaRepository < Lutaml::Model::Serializable
      extend Forwardable

      # Inner classes loaded via autoload
      autoload :TypeIndex, "lutaml/xsd/schema_repository/type_index"
      autoload :NamespaceRegistry, "lutaml/xsd/schema_repository/namespace_registry"
      autoload :QualifiedNameParser, "lutaml/xsd/schema_repository/qualified_name_parser"
      autoload :Loader, "lutaml/xsd/schema_repository/loader"
      autoload :Validator, "lutaml/xsd/schema_repository/validator"
      autoload :ProgressReporter, "lutaml/xsd/schema_repository/progress_reporter"
      autoload :Metadata, "lutaml/xsd/schema_repository/metadata"
      autoload :Statistics, "lutaml/xsd/schema_repository/statistics"
      autoload :Package, "lutaml/xsd/schema_repository/package"

      # Serializable attributes
      attribute :files, :string, collection: true
      attribute :base_packages, BasePackageConfig, collection: true
      attribute :schema_location_mappings, SchemaLocationMapping,
                collection: true
      attribute :namespace_mappings, NamespaceMapping, collection: true
      attribute :output_package, :string

      yaml do
        map "files", to: :files
        map "base_packages", to: :base_packages
        map "schema_location_mappings", to: :schema_location_mappings
        map "namespace_mappings", to: :namespace_mappings
        map "output_package", to: :output_package
      end

      def base_packages=(value)
        @base_packages = value
      end

      def base_packages
        @base_packages || []
      end

      # Internal state (not serialized)
      attr_accessor :parsed_schemas
      attr_reader :lazy_load, :type_index, :namespace_registry,
                  :resolved, :validated, :verbose

      attr_writer :temp_extraction_dir

      # Copy internal state from another repository (for cloning/remapping)
      def copy_state_from(source)
        @parsed_schemas = source.parsed_schemas
        @resolved = source.resolved
        @validated = source.validated
        @lazy_load = source.lazy_load
        @verbose = source.verbose
      end

      def initialize(**attributes)
        @parsed_schemas = Lutaml::Store::BasicStore.new(adapter_type: :memory)
        @namespace_registry = NamespaceRegistry.new
        @type_index = TypeIndex.new
        @lazy_load = true
        @resolved = false
        @validated = false
        @verbose = false

        super

        return unless namespace_mappings && !namespace_mappings.empty?

        namespace_mappings.each do |mapping|
          @namespace_registry.register(mapping.prefix, mapping.uri)
        end
      end

      # --- Parse ---

      def parse(schema_locations: {}, lazy_load: true, verbose: false)
        @lazy_load = lazy_load
        @verbose = verbose

        register_namespace_mappings

        glob_mappings = build_glob_mappings(schema_locations)

        load_base_packages(glob_mappings)

        parser.parse(files || [], glob_mappings, verbose: verbose)

        self
      end

      # --- Resolve ---

      def resolve(verbose: false)
        return self if @resolved

        @verbose = verbose
        all_schemas = self.all_schemas

        ProgressReporter.new.report_resolve(all_schemas) if @verbose

        register_namespaces_for_resolution(all_schemas)
        @type_index.build_from_schemas(all_schemas)

        @resolved = true
        self
      end

      # --- Validate ---

      def validate(strict: false)
        errors = Validator.new(self).validate(strict: strict)
        @validated = errors.empty?
        errors
      end

      # --- Namespace configuration ---

      def configure_namespace(prefix:, uri:)
        @namespace_mappings ||= []
        @namespace_mappings << NamespaceMapping.new(prefix: prefix, uri: uri)
        @namespace_registry.register(prefix, uri)
        self
      end

      def configure_namespaces(mappings)
        case mappings
        when Hash
          mappings.each { |prefix, uri| configure_namespace(prefix: prefix, uri: uri) }
        when Array
          mappings.each do |mapping|
            if mapping.is_a?(NamespaceMapping)
              configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
            elsif mapping.is_a?(Hash)
              configure_namespace(
                prefix: mapping[:prefix] || mapping["prefix"],
                uri: mapping[:uri] || mapping["uri"],
              )
            end
          end
        end
        self
      end

      # --- Service accessors (memoized) ---

      def query = @query ||= SchemaQueryService.new(self)
      def exporter = @exporter ||= SchemaExporter.new(self)
      def parser = @parser ||= SchemaParser.new(self)

      # --- Query / export delegation ---

      def_delegators :query, :find_type, :find_attribute, :find_element,
                     :find_group, :find_attribute_group, :type_exists?,
                     :all_type_names
      def_delegators :exporter, :statistics, :export_statistics,
                     :namespace_summary, :elements_by_namespace

      def parse_qualified_name(qualified_name)
        QualifiedNameParser.parse(qualified_name, @namespace_registry)
      end

      # --- Schema access ---

      def all_schemas = @parsed_schemas.all
      def schemas = all_schemas
      def needs_parsing? = all_schemas.empty?

      # --- Namespace access ---

      def all_namespaces = @namespace_registry.all_uris

      def namespace_to_prefix(namespace_uri)
        return nil if namespace_uri.nil? || namespace_uri.empty?

        @namespace_registry.get_primary_prefix(namespace_uri)
      end

      def namespace_prefix_details = NamespacePrefixManager.new(self).detailed_prefix_info
      def types_in_namespace(namespace_uri) = @type_index.find_all_in_namespace(namespace_uri)

      # --- File management ---

      def add_schema_file(file_path)
        @files ||= []
        @files << file_path unless @files.include?(file_path)
      end

      def add_schema_files(file_paths) = file_paths.each { |fp| add_schema_file(fp) }

      def add_schema_location_mapping(mapping)
        @schema_location_mappings ||= []
        mapping_obj = if mapping.is_a?(SchemaLocationMapping)
                        mapping
                      elsif mapping.is_a?(Hash)
                        SchemaLocationMapping.from_hash(mapping)
                      else
                        raise ArgumentError,
                              "Expected SchemaLocationMapping or Hash, got #{mapping.class}"
                      end
        @schema_location_mappings << mapping_obj unless @schema_location_mappings.any? { |m| m.from == mapping_obj.from }
      end

      def configure_schema_location_mappings(mappings)
        mappings.each { |m| add_schema_location_mapping(m) }
        self
      end

      # --- Analysis delegation ---

      def classify_schemas = SchemaClassifier.new(self).classify
      def remap_namespace_prefixes(changes) = NamespaceRemapper.new(self).remap(changes)
      def analyze_type_hierarchy(qualified_name, depth: 10) = TypeHierarchyAnalyzer.new(self).analyze(qualified_name, depth: depth)
      def analyze_coverage(entry_types: []) = CoverageAnalyzer.new(self).analyze(entry_types: entry_types)
      def validate_xsd_spec(version: "1.0") = XsdSpecValidator.new(self, version: version).validate

      # --- Package ---

      def to_package(output_path, xsd_mode: :include_all, resolution_mode: :resolved, serialization_format: :marshal,
                     metadata: {})
        resolve unless @resolved || resolution_mode == :bare

        config = PackageConfiguration.new(
          xsd_mode: xsd_mode,
          resolution_mode: resolution_mode,
          serialization_format: serialization_format,
        )

        SchemaRepositoryPackage.create(
          repository: self,
          output_path: output_path,
          config: config,
          metadata: metadata,
        )
      end

      # --- Package loading (public for PackageLoader) ---

      def supports_conflict_detection?
        base_packages&.any? do |pkg|
          pkg.is_a?(Hash) || pkg.is_a?(BasePackageConfig) ||
            (pkg.is_a?(String) && pkg.start_with?("{"))
        end
      end

      # --- Class methods (delegate to Loader) ---

      def self.validate_package(zip_path) = Loader.validate_package(zip_path)
      def self.from_package(zip_path) = Loader.from_package(zip_path)
      def self.from_yaml_file(yaml_path) = Loader.from_yaml_file(yaml_path)
      def self.from_file(path) = Loader.from_file(path)
      def self.from_file_cached(source_path, lxr_path: nil) = Loader.from_file_cached(source_path, lxr_path: lxr_path)

      # --- Instance private methods ---

      # --- Parse orchestration helpers ---

      def register_namespace_mappings
        return unless namespace_mappings && !namespace_mappings.empty?

        namespace_mappings.each do |mapping|
          @namespace_registry.register(mapping.prefix, mapping.uri)
        end
      end

      def build_glob_mappings(schema_locations)
        glob_mappings = (schema_location_mappings || []).map(&:to_glob_format)

        if schema_locations && !schema_locations.empty?
          schema_locations.each do |from, to|
            glob_mappings << { from: from, to: to }
          end
        end

        glob_mappings
      end

      def load_base_packages(glob_mappings)
        return unless base_packages&.any?

        PackageLoader.new(parser: parser, repository: self).load(glob_mappings)
      end

      def register_namespaces_for_resolution(all_schemas)
        if namespace_mappings.nil? || namespace_mappings.empty?
          @namespace_registry.extract_from_schemas(all_schemas.values)
        else
          namespace_mappings.each do |mapping|
            @namespace_registry.register(mapping.prefix, mapping.uri)
          end
        end
      end
    end
  end
end
