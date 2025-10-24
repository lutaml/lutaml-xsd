# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Package management commands
      # Handles build, validate, and info operations for .lxr packages
      class PackageCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "build CONFIG_FILE", "Build a schema repository package from YAML configuration"
        option :output,
               type: :string,
               aliases: "-o",
               desc: "Output package path (default: pkg/<name>.lxr)"
        option :xsd_mode,
               type: :string,
               default: "include_all",
               enum: %w[include_all allow_external],
               desc: "XSD bundling mode"
        option :resolution_mode,
               type: :string,
               default: "resolved",
               enum: %w[resolved bare],
               desc: "Resolution mode"
        option :serialization_format,
               type: :string,
               default: "marshal",
               enum: %w[marshal json yaml parse],
               desc: "Serialization format"
        option :name,
               type: :string,
               desc: "Package name"
        option :version,
               type: :string,
               desc: "Package version"
        option :description,
               type: :string,
               desc: "Package description"
        option :validate,
               type: :boolean,
               default: false,
               desc: "Validate package after building"
        def build(config_file)
          BuildCommand.new(config_file, options).run
        end

        desc "validate PACKAGE_FILE", "Validate a schema repository package"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :strict,
               type: :boolean,
               default: false,
               desc: "Fail on warnings"
        def validate(package_file)
          ValidateCommand.new(package_file, options).run
        end

        desc "info PACKAGE_FILE", "Display package metadata and statistics"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def info(package_file)
          InfoCommand.new(package_file, options).run
        end

        # Build command implementation
        class BuildCommand < BaseCommand
          def initialize(config_file, options)
            super(options)
            @config_file = config_file
          end

          def run
            validate_config_file
            build_package
          end

          private

          def validate_config_file
            return if File.exist?(@config_file)

            error "Configuration file not found: #{@config_file}"
            exit 1
          end

          def build_package
            verbose_output "Loading repository configuration from: #{@config_file}"
            repository = SchemaRepository.from_yaml_file(@config_file)
            verbose_output "✓ Configuration loaded"
            verbose_output "  Files: #{repository.files.size}"
            verbose_output "  Schema Location Mappings: #{repository.schema_location_mappings.size}"
            verbose_output "  Namespace Mappings: #{repository.namespace_mappings.size}"
            verbose_output ""

            verbose_output "Parsing and resolving schemas..."
            repository.parse.resolve
            verbose_output "✓ Schemas parsed and resolved"
            verbose_output ""

            output_path = determine_output_path(repository)
            FileUtils.mkdir_p(File.dirname(output_path))

            verbose_output "Creating package: #{output_path}"
            verbose_output "  XSD Mode: #{options[:xsd_mode]}"
            verbose_output "  Resolution Mode: #{options[:resolution_mode]}"
            verbose_output "  Serialization Format: #{options[:serialization_format]}"

            package = repository.to_package(
              output_path,
              xsd_mode: options[:xsd_mode].to_sym,
              resolution_mode: options[:resolution_mode].to_sym,
              serialization_format: options[:serialization_format].to_sym,
              metadata: build_metadata
            )

            output "✓ Package created: #{output_path}"
            output "  Size: #{File.size(output_path)} bytes"

            validate_package(package) if options[:validate]
          rescue StandardError => e
            error "Failed to build package: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            exit 1
          end

          def determine_output_path(repository)
            return options[:output] if options[:output]

            # Use package name from options or derive from first file
            name = options[:name] || derive_name_from_repository(repository)
            File.expand_path("pkg/#{name}.lxr")
          end

          def derive_name_from_repository(repository)
            return "schema_repository" if repository.files.empty?

            File.basename(repository.files.first, ".*")
          end

          def build_metadata
            metadata = {}
            metadata[:name] = options[:name] if options[:name]
            metadata[:version] = options[:version] if options[:version]
            metadata[:description] = options[:description] if options[:description]
            metadata[:created_by] = "lutaml-xsd CLI"
            metadata
          end

          def validate_package(package)
            verbose_output ""
            verbose_output "Validating package..."
            validation = package.validate

            if validation.valid?
              output "✓ Package is valid"
            else
              error "Package validation failed"
              validation.errors.each { |err| error "  - #{err}" }
              exit 1 if options[:strict]
            end

            return unless validation.warnings.any?

            output "Warnings:"
            validation.warnings.each { |warn| output "  - #{warn}" }
            exit 1 if options[:strict]
          end
        end

        # Validate command implementation
        class ValidateCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists
            perform_validation
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            exit 1
          end

          def perform_validation
            verbose_output "Validating package: #{@package_file}"

            package = SchemaRepositoryPackage.new(@package_file)
            validation = package.validate

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(validation.to_h, format)
            else
              display_text_validation(validation)
            end

            exit 1 if !validation.valid? || (options[:strict] && validation.warnings.any?)
          rescue StandardError => e
            error "Validation error: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            exit 1
          end

          def display_text_validation(validation)
            if validation.valid?
              output "✓ Package is VALID"
            else
              output "✗ Package is INVALID"
            end

            if validation.errors.any?
              output ""
              output "Errors (#{validation.errors.size}):"
              validation.errors.each { |err| output "  - #{err}" }
            end

            if validation.warnings.any?
              output ""
              output "Warnings (#{validation.warnings.size}):"
              validation.warnings.each { |warn| output "  - #{warn}" }
            end

            return unless verbose? && validation.metadata

            output ""
            output "Metadata:"
            validation.metadata.each do |key, value|
              output "  #{key}: #{value.inspect}"
            end
          end
        end

        # Info command implementation
        class InfoCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists
            display_info
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            exit 1
          end

          def display_info
            verbose_output "Loading package metadata: #{@package_file}"

            package = SchemaRepositoryPackage.new(@package_file)
            validation = package.validate

            unless validation.valid?
              error "Cannot display info for invalid package"
              validation.errors.each { |err| error "  - #{err}" }
              exit 1
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(validation.metadata, format)
            else
              display_text_info(validation.metadata)
            end
          rescue StandardError => e
            error "Failed to read package info: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            exit 1
          end

          def display_text_info(metadata)
            output "Package: #{File.basename(@package_file)}"
            output "Size: #{File.size(@package_file)} bytes"
            output ""
            output "Metadata:"
            output "-" * 80

            metadata.each do |key, value|
              if value.is_a?(Array)
                output "#{key}: (#{value.size} items)"
                value.first(3).each { |item| output "  - #{item.inspect}" }
                output "  ..." if value.size > 3
              elsif value.is_a?(Hash)
                output "#{key}:"
                value.each { |k, v| output "  #{k}: #{v}" }
              else
                output "#{key}: #{value}"
              end
            end
          end
        end
      end
    end
  end
end
