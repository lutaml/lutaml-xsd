# frozen_string_literal: true

module Lutaml
  module Xsd
    # Orchestrates package creation using configuration, bundler, and resolver
    # Implements the Strategy pattern for different package types
    class PackageBuilder
      attr_reader :config, :bundler, :resolver, :warnings

      # @param config [PackageConfiguration] Package configuration
      def initialize(config)
        @config = config
        @bundler = XsdBundler.new
        @resolver = SchemaResolver.new
        @warnings = []
      end

      # Build package metadata from repository
      # @param repository [SchemaRepository] Repository to package
      # @param additional_metadata [Hash] Additional metadata fields
      # @return [Hash] Package data ready for ZIP creation
      def build(repository, additional_metadata = {})
        # Collect XSD files based on configuration
        xsd_files = @bundler.collect_xsd_files(repository, @config)

        # Serialize schemas based on format
        serialized_schemas_data = if @config.resolved_package? && !@config.parse_format?
                                    serialize_all_schemas(repository)
                                  else
                                    {}
                                  end

        # Build metadata
        metadata = build_metadata(
          repository,
          additional_metadata,
          serialized_schemas_data
        )

        {
          metadata: metadata,
          xsd_files: xsd_files,
          serialized_schemas: serialized_schemas_data
        }
      end

      # Load package data into repository
      # @param repository [SchemaRepository] Repository to load into
      # @param metadata_hash [Hash] Metadata from package
      def load(repository, metadata_hash)
        # Backward compatibility: check for old serialized_schemas format
        serialized_schemas = metadata_hash['serialized_schemas'] ||
                             metadata_hash[:serialized_schemas]

        return unless serialized_schemas&.any?

        @resolver.load_serialized_schemas(repository, serialized_schemas)
      end

      # Serialize a single schema based on format
      # @param schema [Schema] Schema to serialize
      # @param format [Symbol] Serialization format
      # @return [String, nil] Serialized data or nil for :parse format
      def serialize_schema(schema, format)
        case format
        when :marshal
          Marshal.dump(schema)
        when :json
          schema.to_json
        when :yaml
          schema.to_yaml
        when :parse
          nil
        else
          raise ArgumentError, "Unknown serialization format: #{format}"
        end
      end

      # Deserialize a schema based on format
      # @param data [String] Serialized data
      # @param format [Symbol] Serialization format
      # @return [Schema] Deserialized schema
      def deserialize_schema(data, format)
        case format
        when :marshal
          Marshal.load(data)
        when :json
          Lutaml::Xsd::Schema.from_json(data)
        when :yaml
          Lutaml::Xsd::Schema.from_yaml(data)
        else
          raise ArgumentError, "Unknown serialization format: #{format}"
        end
      end

      # Serialize all schemas from repository
      # @param repository [SchemaRepository] Repository with parsed schemas
      # @return [Hash] Map of file_path => serialized data
      def serialize_all_schemas(repository)
        all_schemas = repository.send(:get_all_processed_schemas)
        glob_mappings = (repository.schema_location_mappings || []).map(&:to_glob_format)
        serialized = {}

        all_schemas.each do |schema_location, schema|
          # Resolve schema location to actual file path
          file_path = if schema_location.start_with?('/')
                        # Already an absolute file path
                        schema_location
                      else
                        # Relative path or HTTP URL - resolve using mappings
                        resolve_schema_location_to_file(schema_location, glob_mappings)
                      end

          # Skip if we couldn't resolve to a file path
          next unless file_path && File.exist?(file_path)

          data = serialize_schema(schema, @config.serialization_format)
          serialized[file_path] = data if data
        end

        # Also serialize entry point schemas from repository.files
        (repository.files || []).each do |file_path|
          next if serialized.key?(file_path)
          next unless File.exist?(file_path)

          schema = repository.instance_variable_get(:@parsed_schemas)&.[](file_path)
          next unless schema

          data = serialize_schema(schema, @config.serialization_format)
          serialized[file_path] = data if data
        end

        serialized
      end

      # Resolve a schema location (possibly HTTP URL) to actual file path
      # @param location [String] Schema location
      # @param glob_mappings [Array<Hash>] Schema mappings in Glob format
      # @return [String, nil] Resolved file path or nil
      def resolve_schema_location_to_file(location, glob_mappings)
        glob_mappings.each do |mapping|
          from = mapping[:from]
          to = mapping[:to]

          if from.is_a?(Regexp)
            return location.gsub(from, to) if location =~ from
          elsif location == from
            return to
          end
        end

        nil
      end

      # Display build warnings
      # @param warnings [Array<Hash>] Array of warning hashes
      def display_warnings(warnings)
        return if warnings.empty?

        puts
        puts "⚠ WARNINGS (#{warnings.size})"
        puts '─' * 70

        warnings.each_with_index do |w, i|
          puts "#{i + 1}. #{w[:type]}: #{w[:reference]}"
          puts "   Location: #{w[:schema]}:#{w[:line]}" if w[:line]
          puts "   Namespace: #{w[:namespace]}" if w[:namespace]
          puts "   Hint: #{w[:hint]}" if w[:hint]
          puts
        end

        puts '━' * 70
        puts "Status: ✓ Package created with #{warnings.size} warning(s)"
        puts 'Action: Review warnings and update config if needed'
        puts
      end

      # Suggest fix for reference error
      # @param error [StandardError] Error that occurred
      # @return [String] Suggestion text
      def suggest_fix(error)
        message = error.message

        if message.include?('not found')
          'Check that all required schemas are included in dependencies'
        elsif message.include?('namespace')
          'Verify namespace URI is correct and schema is imported'
        else
          'Review schema dependencies and imports'
        end
      end

      private

      # Build metadata with package configuration
      # @param repository [SchemaRepository] Repository to package
      # @param additional [Hash] Additional metadata fields
      # @param serialized_schemas_data [Hash] Serialized schema data (deprecated format)
      # @return [SchemaRepositoryMetadata]
      def build_metadata(repository, additional, serialized_schemas_data)
        metadata = SchemaRepositoryMetadata.from_repository(
          repository,
          additional
        )

        # Add package configuration
        metadata.instance_variable_set(:@xsd_mode, @config.xsd_mode)
        metadata.instance_variable_set(:@resolution_mode, @config.resolution_mode)
        metadata.instance_variable_set(:@serialization_format, @config.serialization_format)

        # Backward compatibility: only add serialized_schemas for old format
        # (new format stores them separately in schemas_data/ directory)
        if @config.resolved_package? && serialized_schemas_data.is_a?(Array)
          metadata.instance_variable_set(:@serialized_schemas,
                                         serialized_schemas_data)
        end

        # Clear schema_location_mappings if include_all mode
        # (all XSDs are bundled, mappings not needed and cause validation warnings)
        metadata.instance_variable_set(:@schema_location_mappings, []) if @config.include_all_xsds?

        metadata
      end
    end
  end
end
