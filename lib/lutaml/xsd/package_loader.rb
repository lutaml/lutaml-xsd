# frozen_string_literal: true

module Lutaml
  module Xsd
    # Handles loading LXR packages into the repository, with conflict detection.
    # Extracted from SchemaRepository to separate package loading concerns.
    class PackageLoader
      def initialize(parser:, repository:)
        @parser = parser
        @repository = repository
      end

      # Load base packages, auto-detecting conflict detection support
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def load(glob_mappings)
        configs = normalize_base_packages_to_configs

        if supports_conflict_detection?
          load_with_conflict_detection(configs)
        else
          load_legacy(configs, glob_mappings)
        end
      end

      # Load a single package source with schema filtering
      # @param package_source [PackageSource] The package to load
      def load_package_with_filtering(package_source)
        repo = package_source.repository

        store = repo.parsed_schemas
        all_schemas = store ? store.all : {}

        filtered_schemas = all_schemas.select do |path, _schema|
          package_source.include_schema?(path)
        end

        if package_source.namespace_remapping.any?
          filtered_schemas = apply_namespace_remapping(filtered_schemas,
                                                       package_source.namespace_remapping)
        end

        @repository.parsed_schemas.bulk_set(filtered_schemas)

        merge_files(repo, package_source)
        merge_namespace_mappings(repo)
        merge_schema_location_mappings(repo)
      end

      # Normalize base_packages to BasePackageConfig objects
      # @return [Array<BasePackageConfig>]
      def normalize_base_packages_to_configs
        (@repository.base_packages || []).map do |pkg|
          case pkg
          when String
            BasePackageConfig.new(package: pkg)
          when Hash
            symbolized = pkg.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
            BasePackageConfig.new(**symbolized)
          when BasePackageConfig
            pkg
          else
            BasePackageConfig.new(package: pkg.to_s)
          end
        end
      end

      private

      def supports_conflict_detection?
        @repository.base_packages&.any? do |pkg|
          pkg.is_a?(Hash) || pkg.is_a?(BasePackageConfig) ||
            (pkg.is_a?(String) && pkg.start_with?("{"))
        end
      end

      def load_with_conflict_detection(configs)
        configs.each do |config|
          result = config.validate
          raise ValidationFailedError, result if result.invalid?
        end

        verbose = @repository.verbose
        if verbose
          puts "Detecting conflicts in #{configs.size} package(s)..."
        end

        detector = PackageConflictDetector.new(configs)
        report = detector.detect_conflicts

        if verbose && report.has_conflicts?
          puts "⚠️  #{report.total_conflicts} conflict(s) detected"
        elsif verbose
          puts "✓ No conflicts detected"
        end

        resolver = PackageConflictResolver.new(report, report.package_sources)
        ordered_sources = resolver.resolve

        if verbose
          puts "Loading #{ordered_sources.size} package(s) in priority order..."
        end

        ordered_sources.each_with_index do |source, idx|
          if verbose
            print "\r[#{idx + 1}/#{ordered_sources.size}] #{File.basename(source.package_path)}"
            $stdout.flush
          end

          load_package_with_filtering(source)
        end

        puts "\n✓ All packages merged successfully" if verbose
      end

      def load_legacy(configs, glob_mappings)
        verbose = @repository.verbose
        puts "Loading #{configs.size} base package(s)..." if verbose

        configs.each_with_index do |config, idx|
          lxr_path = config.package
          resolved_path = if File.absolute_path?(lxr_path)
                            lxr_path
                          else
                            File.expand_path(lxr_path, Dir.pwd)
                          end

          unless File.exist?(resolved_path)
            warn "Warning: Base package not found: #{resolved_path}"
            next
          end

          if verbose
            print "\r[#{idx + 1}/#{configs.size}] Loading #{File.basename(resolved_path)}"
            $stdout.flush
          end

          load_package_schemas(resolved_path, glob_mappings)
        end

        puts "\n✓ All base packages loaded" if verbose
      end

      def load_package_schemas(lxr_path, glob_mappings)
        package_repo = SchemaRepository.from_package(lxr_path)

        package_repo.files&.each do |file_path|
          @repository.add_schema_file(file_path)
          @parser.parse_file(file_path, glob_mappings) if File.exist?(file_path)
        end

        merge_namespace_mappings(package_repo)
        merge_schema_location_mappings(package_repo)
      end

      def merge_files(repo, package_source)
        @repository.files ||= []
        filtered_files = (repo.files || []).select do |file|
          package_source.include_schema?(file)
        end
        @repository.files.concat(filtered_files)
      end

      def merge_namespace_mappings(repo)
        repo.namespace_mappings&.each do |mapping|
          @repository.configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
        end
      end

      def merge_schema_location_mappings(repo)
        repo.schema_location_mappings&.each do |mapping|
          mappings = @repository.schema_location_mappings
          mappings ||= @repository.schema_location_mappings = []
          next if mappings.any? { |m| m.from == mapping.from }

          mappings << mapping
        end
      end

      def apply_namespace_remapping(schemas, _remappings)
        # Namespace remapping is handled during conflict detection
        schemas
      end
    end
  end
end
