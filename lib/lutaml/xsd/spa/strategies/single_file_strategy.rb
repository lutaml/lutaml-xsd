# frozen_string_literal: true

require_relative "../output_strategy"

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # Single-file output strategy
        #
        # Generates a single self-contained HTML file with all resources
        # (CSS, JavaScript, data) embedded inline. Ideal for portability
        # and ease of distribution.
        #
        # @example
        #   strategy = SingleFileStrategy.new(
        #     'output/docs.html',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, renderer)
        class SingleFileStrategy < OutputStrategy
          attr_reader :output_path, :config_loader

          # Initialize single-file strategy
          #
          # @param output_path [String] Output file path
          # @param config_loader [ConfigurationLoader] Configuration loader
          # @param verbose [Boolean] Enable verbose output
          def initialize(output_path, config_loader, verbose: false)
            super(verbose: verbose)
            @output_path = output_path
            @config_loader = config_loader
          end

          # Generate single HTML file
          #
          # @param data [Hash] Serialized schema data
          # @param renderer [TemplateRenderer] Template renderer
          # @return [Array<String>] List containing single file path
          def generate(data, renderer)
            log "Generating single-file SPA..."

            # Load configurations
            theme = config_loader.load_ui_theme
            features = config_loader.load_features
            templates_config = config_loader.load_templates

            # Prepare context for template
            context = build_context(data, theme, features, templates_config)

            # Render main content using schema cards
            content_html = render_content(data, renderer)

            # Render complete layout
            html = renderer.render("layout.html.liquid", context.merge(
                                                           content: content_html,
                                                         ))

            # Write to file
            prepare_output
            files = [write_file(output_path, html)]

            log "✓ Single file generated: #{output_path}"
            files
          end

          protected

          # Prepare output directory
          #
          # @return [void]
          def prepare_output
            dir = File.dirname(output_path)
            ensure_directory(dir) unless dir == "."
          end

          # Build template context
          #
          # @param data [Hash] Schema data
          # @param theme [Hash] UI theme config
          # @param features [Hash] Features config
          # @param templates_config [Hash] Templates config
          # @return [Hash] Template context
          def build_context(data, theme, features, templates_config)
            {
              "metadata" => data[:metadata],
              "schemas" => data[:schemas],
              "theme" => theme["theme"],
              "features" => features["features"],
              "templates" => templates_config["templates"],
            }
          end

          # Render main content
          #
          # @param data [Hash] Schema data
          # @param renderer [TemplateRenderer] Renderer
          # @return [String] Rendered content HTML
          def render_content(data, renderer)
            schemas = data[:schemas] || []

            # Pre-render all schema detail views
            schema_details = schemas.map do |schema|
              renderer.render_partial("_schema_detail", { "schema" => schema })
            end.join("\n")

            # Wrap in containers: one for pre-rendered schemas, one for dynamic detail views
            <<~HTML
              <div id="schema-list-container">
                <div id="no-schema-selected" class="welcome-message">
                  <h2>Select a schema from the sidebar to view details</h2>
                  <p>Explore elements, types, attributes, and more.</p>
                </div>
                #{schema_details}
              </div>
              <div id="detail-view-container" style="display:none;">
                <!-- Dynamic element/type detail views rendered here -->
              </div>
            HTML
          end
        end
      end
    end
  end
end
