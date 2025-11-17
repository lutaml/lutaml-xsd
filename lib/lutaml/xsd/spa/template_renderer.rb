# frozen_string_literal: true

require "liquid"

module Lutaml
  module Xsd
    module Spa
      # Template renderer for Liquid templates
      #
      # Manages loading, caching, and rendering of Liquid templates with
      # custom filters and variable contexts. Provides a clean interface
      # for template-based HTML generation.
      #
      # @example Render a template
      #   renderer = TemplateRenderer.new
      #   html = renderer.render('layout', {
      #     title: 'My Schema',
      #     content: main_content
      #   })
      #
      # @example Register custom filters
      #   renderer = TemplateRenderer.new
      #   renderer.register_filter(SchemaFilters)
      #   renderer.register_filter(TextFilters)
      class TemplateRenderer
        # Default template directory
        DEFAULT_TEMPLATE_DIR = File.expand_path("templates", __dir__)

        attr_reader :template_dir, :environment

        # Get file system from environment
        def file_system
          @environment.file_system
        end

        # Initialize template renderer
        #
        # @param template_dir [String] Directory containing template files
        # @param cache_enabled [Boolean] Enable template caching
        def initialize(template_dir: DEFAULT_TEMPLATE_DIR, cache_enabled: true)
          @template_dir = template_dir
          @cache_enabled = cache_enabled
          @template_cache = {}
          @filters = []
          @environment = create_liquid_environment

          configure_liquid
        end

        # Render a template with given context
        #
        # @param template_name [String] Template name (without .liquid extension)
        # @param context [Hash] Variables to pass to template
        # @return [String] Rendered template
        # @raise [Liquid::Error] if template rendering fails
        def render(template_name, context = {})
          template = load_template(template_name)
          template.render(
            stringify_keys(context),
            registers: { file_system: @environment.file_system }
          )
        end

        # Render a template string (not from file)
        #
        # @param template_str [String] Template content
        # @param context [Hash] Variables to pass to template
        # @return [String] Rendered template
        def render_string(template_str, context = {})
          template = Liquid::Template.parse(template_str)
          template.render(stringify_keys(context), registers: { file_system: @environment.file_system })
        end

        # Register custom filter module
        #
        # @param filter_module [Module] Module containing filter methods
        # @return [void]
        def register_filter(filter_module)
          @filters << filter_module unless @filters.include?(filter_module)
          @environment.register_filter(filter_module)
          # Also register on Liquid::Template for render_string to work
          Liquid::Template.register_filter(filter_module)
        end

        # Clear template cache
        #
        # @return [void]
        def clear_cache
          @template_cache.clear
        end

        # Check if template exists
        #
        # @param template_name [String] Template name
        # @return [Boolean] True if template file exists
        def template_exists?(template_name)
          File.exist?(template_path(template_name))
        end

        # Get template path
        #
        # @param template_name [String] Template name
        # @return [String] Full path to template file
        def template_path(template_name)
          # Return as-is if already has an extension
          if template_name.end_with?(".liquid") || template_name.end_with?(".html.liquid")
            return File.join(template_dir, template_name)
          end

          # Try .html.liquid first, then .liquid
          html_liquid_path = File.join(template_dir, "#{template_name}.html.liquid")
          return html_liquid_path if File.exist?(html_liquid_path)

          File.join(template_dir, "#{template_name}.liquid")
        end

        # Render partial template
        #
        # @param partial_name [String] Partial name
        # @param context [Hash] Variables to pass to partial
        # @return [String] Rendered partial
        def render_partial(partial_name, context = {})
          render("components/#{partial_name}", context)
        end

        private

        # Create Liquid environment with configuration
        #
        # @return [Liquid::Environment] Configured environment
        def create_liquid_environment
          env = Liquid::Environment.new
          env.file_system = Liquid::LocalFileSystem.new(template_dir)
          env.error_mode = :strict
          env
        end

        # Configure Liquid settings (kept for compatibility)
        #
        # @return [void]
        def configure_liquid
          # Configuration now done in create_liquid_environment
        end

        # Load template from file or cache
        #
        # @param template_name [String] Template name
        # @return [Liquid::Template] Compiled template
        # @raise [ArgumentError] if template file not found
        def load_template(template_name)
          if @cache_enabled && @template_cache.key?(template_name)
            return @template_cache[template_name]
          end

          path = template_path(template_name)

          unless File.exist?(path)
            raise ArgumentError, "Template not found: #{path}"
          end

          template_content = File.read(path)
          template = Liquid::Template.parse(
            template_content,
            environment: @environment
          )

          @template_cache[template_name] = template if @cache_enabled

          template
        end

        # Convert hash keys to strings recursively (required by Liquid)
        #
        # @param obj [Hash, Array, Object] Object to stringify
        # @return [Hash, Array, Object] Object with string keys
        def stringify_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(key, value), result|
              result[key.to_s] = stringify_keys(value)
            end
          when Array
            obj.map { |item| stringify_keys(item) }
          else
            obj
          end
        end
      end
    end
  end
end