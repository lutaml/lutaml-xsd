# frozen_string_literal: true

require_relative '../output_strategy'
require 'json'

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # Multi-file output strategy
        #
        # Generates separate HTML, CSS, JavaScript, and JSON data files.
        # Better for larger documentation sets and easier to customize.
        #
        # Directory structure:
        #   output_dir/
        #     index.html
        #     css/styles.css
        #     js/app.js
        #     data/schemas.json
        #
        # @example
        #   strategy = MultiFileStrategy.new(
        #     'output/docs',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, renderer)
        class MultiFileStrategy < OutputStrategy
          attr_reader :output_dir, :config_loader

          # Initialize multi-file strategy
          #
          # @param output_dir [String] Output directory
          # @param config_loader [ConfigurationLoader] Configuration loader
          # @param verbose [Boolean] Enable verbose output
          def initialize(output_dir, config_loader, verbose: false)
            super(verbose: verbose)
            @output_dir = output_dir
            @config_loader = config_loader
          end

          # Generate multi-file SPA
          #
          # @param data [Hash] Serialized schema data
          # @param renderer [TemplateRenderer] Template renderer
          # @return [Array<String>] List of generated file paths
          def generate(data, renderer)
            log 'Generating multi-file SPA...'

            # Load configurations
            theme = config_loader.load_ui_theme
            features = config_loader.load_features
            templates_config = config_loader.load_templates

            # Prepare output directories
            prepare_output

            # Build context for templates
            context = build_context(data, theme, features, templates_config)

            # Generate files
            files = []

            # 1. Generate index.html
            files << generate_index_html(data, renderer, context)

            # 2. Generate CSS file
            files << generate_css_file(theme)

            # 3. Generate JavaScript file
            files << generate_js_file(features)

            # 4. Generate data JSON file
            files << generate_data_file(data)

            log "✓ Multi-file SPA generated in: #{output_dir}"
            files
          end

          protected

          # Prepare output directory structure
          #
          # @return [void]
          def prepare_output
            ensure_directory(output_dir)
            ensure_directory(File.join(output_dir, 'css'))
            ensure_directory(File.join(output_dir, 'js'))
            ensure_directory(File.join(output_dir, 'data'))
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
              'metadata' => data[:metadata],
              'schemas' => data[:schemas],
              'theme' => theme['theme'],
              'features' => features['features'],
              'templates' => templates_config['templates'],
              'multi_file_mode' => true
            }
          end

          # Generate index.html
          #
          # @param data [Hash] Schema data
          # @param renderer [TemplateRenderer] Renderer
          # @param context [Hash] Template context
          # @return [String] Path to index.html
          def generate_index_html(data, renderer, context)
            # Render main content
            content_html = render_content(data, renderer)

            # Render layout with external resources
            html = renderer.render('layout.html.liquid', context.merge(
                                                           content: content_html
                                                         ))

            # Update links to external resources
            html = inject_external_resources(html)

            path = File.join(output_dir, 'index.html')
            write_file(path, html)
          end

          # Generate CSS file
          #
          # @param theme [Hash] Theme config
          # @return [String] Path to CSS file
          def generate_css_file(_theme)
            # For now, CSS is embedded in layout.html.liquid
            # This would be extracted in a future enhancement
            css = "/* Styles are embedded in HTML for now */\n"

            path = File.join(output_dir, 'css', 'styles.css')
            write_file(path, css)
          end

          # Generate JavaScript file
          #
          # @param features [Hash] Features config
          # @return [String] Path to JS file
          def generate_js_file(_features)
            # For now, JS is embedded in layout.html.liquid
            # This would be extracted in a future enhancement
            js = "/* Scripts are embedded in HTML for now */\n"

            path = File.join(output_dir, 'js', 'app.js')
            write_file(path, js)
          end

          # Generate data JSON file
          #
          # @param data [Hash] Schema data
          # @return [String] Path to JSON file
          def generate_data_file(data)
            json = JSON.pretty_generate(data)

            path = File.join(output_dir, 'data', 'schemas.json')
            write_file(path, json)
          end

          # Render main content
          #
          # @param data [Hash] Schema data
          # @param renderer [TemplateRenderer] Renderer
          # @return [String] Rendered content HTML
          def render_content(data, renderer)
            schemas = data[:schemas] || []

            schemas.map do |schema|
              renderer.render_partial('schema_card', { 'schema' => schema })
            end.join("\n")
          end

          # Inject external resource links into HTML
          #
          # @param html [String] HTML content
          # @return [String] Modified HTML with external links
          def inject_external_resources(html)
            # Add external CSS link
            html = html.sub(
              '</head>',
              '<link rel="stylesheet" href="css/styles.css"></head>'
            )

            # Add external JS link
            html = html.sub(
              '</body>',
              '<script src="js/app.js"></script></body>'
            )

            # Update data source to external JSON
            html.sub(
              /const Search = \{[^}]*data: \{[^}]*\}/m,
              "const Search = {\n      data: null, // Loaded from external file"
            )
          end
        end
      end
    end
  end
end
