# frozen_string_literal: true

require_relative 'configuration_loader'
require_relative 'schema_serializer'
require_relative 'template_renderer'
require_relative 'strategies/single_file_strategy'
require_relative 'strategies/multi_file_strategy'
require_relative 'strategies/api_strategy'
require_relative 'filters/schema_filters'
require_relative 'filters/url_filters'

module Lutaml
  module Xsd
    module Spa
      # Main SPA documentation generator (refactored with dependency injection)
      #
      # Orchestrates the generation of interactive HTML Single Page Application
      # documentation from XSD schemas using proper separation of concerns:
      # - ConfigurationLoader: Loads YAML configurations
      # - SchemaSerializer: Converts schemas to structured data
      # - TemplateRenderer: Renders Liquid templates
      # - OutputStrategy: Writes files based on mode
      #
      # @example Generate single-file SPA
      #   generator = Generator.new(
      #     package,
      #     'output/docs.html',
      #     mode: 'single_file'
      #   )
      #   generator.generate
      #
      # @example Generate multi-file SPA
      #   generator = Generator.new(
      #     package,
      #     'output/docs',
      #     mode: 'multi_file'
      #   )
      #   generator.generate
      class Generator
        attr_reader :package, :output_dir, :options

        # Initialize SPA generator with dependency injection
        #
        # @param package [SchemaRepositoryPackage] Schema repository package
        # @param output_dir [String] Output directory or file path
        # @param options [Hash] Generation options
        # @option options [String] :mode Output mode ('single_file' or 'multi_file')
        # @option options [Boolean] :verbose Enable verbose output
        def initialize(package, output_dir, options = {})
          @package = package
          @output_dir = output_dir
          @options = options
          @config_loader = ConfigurationLoader.new
          @serializer = SchemaSerializer.new(package)
          @renderer = setup_renderer
        end

        # Generate SPA documentation
        #
        # @return [Array<String>] List of generated file paths
        def generate
          log 'Starting SPA generation...'

          # Create output strategy
          strategy = create_strategy
          mode = options[:mode] || 'single_file'
          strategy_name = "#{mode.split('_').map(&:capitalize).join(' ')} Strategy"
          log "✓ Using #{strategy_name}"

          # Serialize schema data
          serialized_data = @serializer.serialize
          log "✓ Serialized #{serialized_data[:schemas]&.size || 0} schema(s)"

          # Generate output using strategy
          output_files = strategy.generate(serialized_data, @renderer)
          log "✓ Generated #{output_files&.size || 0} file(s)"

          output_files
        end

        private

        # Setup template renderer with custom filters
        #
        # @return [TemplateRenderer] Configured renderer
        def setup_renderer
          renderer = TemplateRenderer.new
          renderer.register_filter(Filters::SchemaFilters)
          renderer.register_filter(Filters::UrlFilters)
          renderer
        end

        # Create appropriate output strategy based on mode
        #
        # @return [OutputStrategy] Strategy instance
        def create_strategy
          mode = options[:mode] || 'single_file'

          case mode
          when 'single_file'
            Strategies::SingleFileStrategy.new(
              output_dir,
              @config_loader,
              verbose: verbose?
            )
          when 'multi_file'
            Strategies::MultiFileStrategy.new(
              output_dir,
              @config_loader,
              verbose: verbose?
            )
          when 'api'
            Strategies::ApiStrategy.new(
              output_dir,
              @config_loader,
              verbose: verbose?
            )
          else
            raise ArgumentError, "Unknown mode: #{mode}. Valid modes: single_file, multi_file, api"
          end
        end

        # Check if verbose mode is enabled
        #
        # @return [Boolean] True if verbose
        def verbose?
          options[:verbose] == true
        end

        # Log message if verbose mode is enabled
        #
        # @param message [String] Message to log
        # @return [void]
        def log(message)
          puts message if verbose?
        end
      end
    end
  end
end
