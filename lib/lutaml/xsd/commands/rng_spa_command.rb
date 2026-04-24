# frozen_string_literal: true

require_relative "base_command"
require_relative "../spa/generator"
require_relative "../spa/rng_schema_serializer"

module Lutaml
  module Xsd
    module Commands
      # CLI command for generating SPA documentation
      #
      # Generates interactive HTML Single Page Application documentation
      # from RNG/RNC grammar files with Vue.js frontend.
      class RngSpaCommand < BaseCommand
        attr_reader :config_path, :output_path

        # Initialize spa command
        #
        # @param config_path [String] Path to RNG/RNC configuration YAML file
        # @param options [Hash] Command options
        def initialize(config_path, options = {})
          super(options)
          @config_path = config_path
          @output_path = options[:output] || options["output"]
        end

        # Run SPA generation command
        #
        # @return [void]
        def run
          validate_inputs

          grammars = load_grammars
          generator = create_generator(grammars)
          output_files = generator.generate
          display_results(output_files)
          # rescue StandardError => e
          #   error "SPA generation failed: #{e.message}"
          #   verbose_output e.backtrace.join("\n") if verbose?
          #   exit 1
        end

        private

        # Validate inputs
        #
        # @return [void]
        def validate_inputs
          unless config_path
            error "No RNG config specified"
            error "Usage: lutaml-xsd rng-spa CONFIG --output FILE [options]"
            exit 1
          end

          unless File.exist?(config_path)
            error "RNG config file not found: #{config_path}"
            exit 1
          end

          unless output_path
            error "No output file specified. Use --output option"
            exit 1
          end
        end

        # Load grammars
        #
        # @return [Array<Rng::Schema>] List of parsed RNG schemas
        def load_grammars
          verbose_output "Parsing RNG schemas from config: #{@config_path}"

          serializer = Spa::RngSchemaSerializer.new(@config_path, verbose: verbose?)
          serialized_data = serializer.serialize

          verbose_output "✓ Serialized #{serialized_data[:schemas]&.size || 0} grammar(s)"

          serialized_data
        end

        # Create SPA generator instance
        #
        # @param grammars [Array<Rng::Schema>] List of parsed RNG schemas
        # @return [Spa::Generator] Generator instance
        def create_generator(grammars)
          verbose_output "Initializing SPA generator..."

          mode = options[:mode] || "inlined"

          generator = Spa::Generator.new(
            nil,
            @output_path,
            mode: options[:mode] || "inlined",
            verbose: verbose?,
            pre_serialized_data: grammars,
          )

          verbose_output "✓ Generator initialized in #{mode} mode"
          generator
        end

        # Display generation results
        #
        # @param output_files [Array<String>] List of generated files
        # @return [void]
        def display_results(output_files)
          output ""
          output "SPA Documentation Generated Successfully"
          output "=" * 80
          output ""

          if output_files.size == 1
            output "Output file:"
            output "  #{output_files.first}"
          else
            output "Output files (#{output_files.size} total):"
            output_files.each do |file|
              output "  #{file}"
            end
          end

          output ""
          output "✓ Generation complete"
        end
      end
    end
  end
end
