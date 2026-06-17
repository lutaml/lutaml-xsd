# frozen_string_literal: true

require "lutaml/store"

module Lutaml
  module Xsd
    # A fully resolved, validated, searchable collection of XSD schemas.
    # Delegates to focused service objects for parsing, querying, loading, and export.
    class SchemaRepository < Lutaml::Model::Serializable
      # Inner classes loaded via autoload
      autoload :TypeIndex, "lutaml/xsd/schema_repository/type_index"
      autoload :NamespaceRegistry, "lutaml/xsd/schema_repository/namespace_registry"
      autoload :QualifiedNameParser, "lutaml/xsd/schema_repository/qualified_name_parser"

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

        SchemaParser.new(self).parse(files || [], glob_mappings, verbose: verbose)

        self
      end

      # --- Resolve ---

      def resolve(verbose: false)
        return self if @resolved

        @verbose = verbose
        all_schemas = self.all_schemas

        if @verbose
          show_resolution_progress(all_schemas)
        end

        register_namespaces_for_resolution(all_schemas)
        @type_index.build_from_schemas(all_schemas)

        @resolved = true
        self
      end

      # --- Validate ---

      def validate(strict: false)
        errors = []

        validate_file_existence(errors, strict)
        validate_parsed_schemas(errors, strict)
        check_circular_imports(errors, strict)
        validate_namespace_mappings(errors, strict)

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

      # --- Query delegation ---

      def find_type(qname)
        SchemaQueryService.new(self).find_type(qname)
      end

      def find_attribute(qualified_name)
        SchemaQueryService.new(self).find_attribute(qualified_name)
      end

      def find_element(qualified_name)
        SchemaQueryService.new(self).find_element(qualified_name)
      end

      def find_group(qualified_name)
        SchemaQueryService.new(self).find_group(qualified_name)
      end

      def find_attribute_group(qualified_name)
        SchemaQueryService.new(self).find_attribute_group(qualified_name)
      end

      def type_exists?(qualified_name)
        SchemaQueryService.new(self).type_exists?(qualified_name)
      end

      def all_type_names(namespace: nil, category: nil)
        SchemaQueryService.new(self).all_type_names(namespace: namespace,
                                                    category: category)
      end

      def parse_qualified_name(qualified_name)
        QualifiedNameParser.parse(qualified_name, @namespace_registry)
      end

      # --- Export delegation ---

      def statistics
        SchemaExporter.new(self).statistics
      end

      def export_statistics(format: :yaml)
        SchemaExporter.new(self).export_statistics(format: format)
      end

      def namespace_summary
        SchemaExporter.new(self).namespace_summary
      end

      def elements_by_namespace(namespace_uri: nil)
        SchemaExporter.new(self).elements_by_namespace(namespace_uri: namespace_uri)
      end

      # --- Schema access ---

      def all_schemas
        @parsed_schemas.all
      end

      def schemas
        all_schemas
      end

      def needs_parsing?
        all_schemas.empty?
      end

      # --- Namespace access ---

      def all_namespaces
        @namespace_registry.all_uris
      end

      def namespace_to_prefix(namespace_uri)
        return nil if namespace_uri.nil? || namespace_uri.empty?

        @namespace_registry.get_primary_prefix(namespace_uri)
      end

      def namespace_prefix_details
        NamespacePrefixManager.new(self).detailed_prefix_info
      end

      def types_in_namespace(namespace_uri)
        @type_index.find_all_in_namespace(namespace_uri)
      end

      # --- File management ---

      def add_schema_file(file_path)
        @files ||= []
        @files << file_path unless @files.include?(file_path)
      end

      def add_schema_files(file_paths)
        file_paths.each { |fp| add_schema_file(fp) }
      end

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

      def classify_schemas
        SchemaClassifier.new(self).classify
      end

      def remap_namespace_prefixes(changes)
        NamespaceRemapper.new(self).remap(changes)
      end

      def analyze_type_hierarchy(qualified_name, depth: 10)
        TypeHierarchyAnalyzer.new(self).analyze(qualified_name, depth: depth)
      end

      def analyze_coverage(entry_types: [])
        CoverageAnalyzer.new(self).analyze(entry_types: entry_types)
      end

      def validate_xsd_spec(version: "1.0")
        XsdSpecValidator.new(self, version: version).validate
      end

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

      def normalize_base_packages_to_configs
        PackageLoader.new(self).normalize_base_packages_to_configs
      end

      def load_base_packages_with_conflict_detection(glob_mappings)
        PackageLoader.new(self).load(glob_mappings)
      end

      def load_package_with_filtering(package_source, glob_mappings)
        PackageLoader.new(self).load_package_with_filtering(package_source, glob_mappings)
      end

      def supports_conflict_detection?
        base_packages&.any? do |pkg|
          pkg.is_a?(Hash) || pkg.is_a?(BasePackageConfig) ||
            (pkg.is_a?(String) && pkg.start_with?("{"))
        end
      end

      def apply_namespace_remapping_to_schemas(schemas, _remappings)
        schemas
      end

      # --- Parse single schema (public for SchemaParser) ---

      def parse_schema_file(file_path, glob_mappings)
        return if @parsed_schemas.exists?(file_path)
        return unless File.exist?(file_path)

        ext = File.extname(file_path).downcase
        parsed_schema = if %w[.rng .rnc].include?(ext)
                          parse_rng_schema(file_path)
                        else
                          parse_xsd_schema(file_path, glob_mappings)
                        end

        @parsed_schemas.set(file_path, parsed_schema)

        import_resolved_schemas
      rescue StandardError => e
        warn "Warning: Failed to parse schema #{file_path}: #{e.message}"
      end

      # --- Class methods ---

      def self.validate_package(zip_path)
        SchemaRepositoryPackage.new(zip_path).validate
      end

      def self.from_package(zip_path)
        SchemaRepositoryPackage.new(zip_path).load_repository
      end

      def self.from_yaml_file(yaml_path)
        yaml_content = File.read(yaml_path)
        base_dir = File.dirname(yaml_path)

        repository = from_yaml(yaml_content)

        resolve_relative_paths(repository, base_dir)
        repository
      end

      def self.from_file(path)
        raise Errno::ENOENT, "No such file or directory - #{path}" unless File.exist?(path)

        case File.extname(path).downcase
        when ".lxr"
          repo = from_package(path)
          repo.resolve unless repo.resolved
          repo
        when ".xsd", ".rng", ".rnc"
          repo = new
          repo.files = [File.expand_path(path)]
          repo.parse.resolve
          repo
        when ".yml", ".yaml"
          repo = from_yaml_file(path)
          repo.parse.resolve if repo.needs_parsing?
          repo
        else
          raise ConfigurationError,
                "Unsupported file type: #{path}. Expected .xsd, .rng, .rnc, .lxr, .yml, or .yaml"
        end
      end

      def self.from_file_cached(source_path, lxr_path: nil)
        lxr_path ||= source_path.sub(/\.(xsd|ya?ml)$/, ".lxr")

        if File.exist?(lxr_path) && File.mtime(lxr_path) >= File.mtime(source_path)
          from_file(lxr_path)
        else
          repo = from_file(source_path)
          repo.to_package(
            lxr_path,
            xsd_mode: :include_all,
            resolution_mode: :resolved,
            serialization_format: :marshal,
          )
          repo
        end
      end

      def self.resolve_relative_paths(repository, base_dir)
        if repository.files
          repository.files = repository.files.map do |file|
            File.absolute_path?(file) ? file : File.expand_path(file, base_dir)
          end
        end

        if repository.base_packages
          repository.base_packages = repository.base_packages.map do |pkg|
            pkg_path = pkg.package
            pkg.package = File.expand_path(pkg_path, base_dir) unless File.absolute_path?(pkg_path)
            pkg
          end
        end

        repository.schema_location_mappings&.each do |mapping|
          next if File.absolute_path?(mapping.to)

          mapping.to = File.expand_path(mapping.to, base_dir)
        end
      end
      private_class_method :resolve_relative_paths

      # --- Instance private methods ---

      # --- Parse helpers ---

      def import_resolved_schemas
        global_cache = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
        global_cache.each do |path, schema|
          @parsed_schemas.set(path, schema) unless @parsed_schemas.exists?(path)
        end
      end

      def parse_xsd_schema(file_path, glob_mappings)
        xsd_content = File.read(file_path)
        Lutaml::Xml::Schema::Xsd.parse(
          xsd_content,
          location: File.dirname(file_path),
          schema_mappings: glob_mappings,
        )
      end

      def parse_rng_schema(file_path)
        require "rng"

        grammar = if file_path.downcase.end_with?(".rnc")
                    Rng.parse_file(file_path)
                  else
                    Rng.parse(File.read(file_path),
                              location: File.dirname(file_path),
                              resolve_external: true)
                  end

        schema = RngToXsdConverter.new(grammar, file_path: file_path).convert

        write_generated_xsd(file_path, schema)
        schema
      end

      def write_generated_xsd(file_path, schema)
        xsd_content = schema.to_formatted_xml
        xsd_path = file_path.sub(/\.(rng|rnc)$/i, ".xsd")

        begin
          File.write(xsd_path, xsd_content)
        rescue StandardError
          require "tmpdir"
          xsd_path = File.join(Dir.tmpdir, "lutaml_xsd_#{File.basename(file_path, '.*')}.xsd")
          File.write(xsd_path, xsd_content)
        end

        update_rng_file_references(file_path, xsd_path)
      end

      def update_rng_file_references(old_path, new_path)
        if @files
          idx = @files.index(old_path)
          @files[idx] = new_path if idx
        end

        if @parsed_schemas.exists?(old_path)
          @parsed_schemas.set(new_path, @parsed_schemas.get(old_path))
          @parsed_schemas.delete(old_path)
        end

        cached = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
        cached[new_path] = cached.delete(old_path) if cached.key?(old_path)
      end

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

        PackageLoader.new(self).load(glob_mappings)
      end

      # --- Resolve helpers ---

      def show_resolution_progress(all_schemas)
        total_imports = all_schemas.values.sum do |schema|
          (schema.import || []).size
        end

        if total_imports.positive?
          puts "Resolving #{total_imports} schema dependencies..."
          processed = 0
          all_schemas.each_value do |schema|
            (schema.import || []).each do |import|
              processed += 1
              print "\r[#{processed}/#{total_imports}] #{import.namespace || 'no namespace'}"
              $stdout.flush
            end
          end
          puts "\n✓ All dependencies resolved"
        else
          puts "✓ No schema dependencies to resolve"
        end
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

      # --- Validate helpers ---

      def validate_file_existence(errors, strict)
        (files || []).each do |file_path|
          next if File.exist?(file_path)

          error = "Schema file not found: #{file_path}"
          errors << error
          raise Error, error if strict
        end
      end

      def validate_parsed_schemas(errors, strict)
        missing_schemas = (files || []).reject { |f| @parsed_schemas.exists?(f) }
        return if missing_schemas.empty?

        error = "Failed to parse schemas: #{missing_schemas.join(', ')}"
        errors << error
        raise Error, error if strict
      end

      def validate_namespace_mappings(errors, strict)
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
      end

      def check_circular_imports(errors, strict)
        dependencies = build_dependency_graph
        visited = {}

        dependencies.each_key do |file|
          next unless has_circular_dependency?(file, dependencies, visited, [])

          error = "Circular import detected involving: #{file}"
          errors << error
          raise Error, error if strict
        end
      end

      def build_dependency_graph
        dependencies = {}
        @parsed_schemas.all.each do |file_path, schema|
          deps = (schema.imports || []).map(&:schema_path)
          (schema.includes || []).each do |inc|
            deps << inc.schema_path
          end
          dependencies[file_path] = deps.compact
        end
        dependencies
      end

      def has_circular_dependency?(file, dependencies, visited, path)
        return false if visited[file] == :permanent
        return true if path.include?(file)

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
