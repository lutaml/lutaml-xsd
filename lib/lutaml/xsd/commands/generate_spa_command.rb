# frozen_string_literal: true

require_relative 'base_command'
require_relative '../spa/generator'

module Lutaml
  module Xsd
    module Commands
      # CLI command for generating SPA documentation
      #
      # Generates interactive HTML Single Page Application documentation
      # from XSD schemas with support for:
      # - Single-file (embedded) output mode
      # - Multi-file (distributed) output mode
      # - Three-tier navigation system
      # - Dynamic content loading
      # - Responsive design
      class GenerateSpaCommand < BaseCommand
        attr_reader :package_path, :output_path, :output_dir

        # Initialize generate-spa command
        #
        # @param package_path [String] Path to LXR package file
        # @param options [Hash] Command options
        def initialize(package_path, options = {})
          super(options)
          @package_path = package_path
          @output_path = options[:output]
          @output_dir = options[:output_dir]
        end

        # Run SPA generation command
        #
        # @return [void]
        def run
          validate_inputs
          package = load_package
          generator = create_generator(package)

          output_files = generator.generate
          display_results(output_files)
        rescue StandardError => e
          error "SPA generation failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          exit 1
        end

        private

        # Validate command inputs
        #
        # @return [void]
        def validate_inputs
          unless package_path
            error 'No package file specified'
            error 'Usage: lutaml-xsd generate-spa PACKAGE [options]'
            exit 1
          end

          unless File.exist?(package_path)
            error "Package file not found: #{package_path}"
            exit 1
          end

          validate_output_options
        end

        # Validate output options
        #
        # @return [void]
        def validate_output_options
          mode = options[:mode] || 'single_file'

          case mode
          when 'single_file'
            unless output_path
              error 'Single-file mode requires --output option'
              exit 1
            end
          when 'multi_file', 'api'
            unless output_dir
              mode_name = mode.tr('_', '-').capitalize
              error "#{mode_name} mode requires --output-dir option"
              exit 1
            end
          else
            error "Invalid mode: #{mode}. Use 'single_file', 'multi_file', or 'api'"
            exit 1
          end
        end

        # Load package
        #
        # @return [SchemaRepositoryPackage] Package instance
        def load_package
          verbose_output "Loading package: #{package_path}"

          package_obj = SchemaRepositoryPackage.load(package_path)

          verbose_output '✓ Package loaded successfully'
          package_obj
        end

        # Create SPA generator instance
        #
        # @param package [SchemaRepositoryPackage] Schema package
        # @return [Spa::Generator] Generator instance
        def create_generator(package)
          verbose_output 'Initializing SPA generator...'

          # Determine output path based on mode
          mode = options[:mode] || 'single_file'
          output_location = mode == 'single_file' ? output_path : output_dir

          generator = Spa::Generator.new(
            package,
            output_location,
            mode: mode,
            verbose: verbose?
          )

          verbose_output "✓ Generator initialized in #{mode} mode"
          generator
        end

        # Display generation results
        #
        # @param output_files [Array<String>] List of generated files
        # @return [void]
        def display_results(output_files)
          output ''
          output 'SPA Documentation Generated Successfully'
          output '=' * 80
          output ''

          if output_files.size == 1
            output 'Output file:'
            output "  #{output_files.first}"
          else
            output "Output files (#{output_files.size} total):"
            output_files.each do |file|
              output "  #{file}"
            end
          end

          output ''
          output '✓ Generation complete'
        end
      end
    end
  end
end
