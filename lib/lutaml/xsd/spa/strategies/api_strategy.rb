# frozen_string_literal: true

require_relative "../output_strategy"
require "json"

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # API-based output strategy with Sinatra server
        #
        # Generates a complete Sinatra-based API server with separate
        # HTML frontend and JSON API endpoint. Perfect for development
        # and when you need a true API backend.
        #
        # Directory structure:
        #   output_dir/
        #     public/
        #       index.html
        #     lib/
        #       app.rb (Sinatra server)
        #     data/
        #       schemas.json
        #     config.ru (Rack config)
        #     Gemfile
        #
        # @example
        #   strategy = ApiStrategy.new(
        #     'output/docs-api',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, renderer)
        class ApiStrategy < OutputStrategy
          attr_reader :output_dir, :config_loader

          # Initialize API strategy
          #
          # @param output_dir [String] Output directory
          # @param config_loader [ConfigurationLoader] Configuration loader
          # @param verbose [Boolean] Enable verbose output
          def initialize(output_dir, config_loader, verbose: false)
            super(verbose: verbose)
            @output_dir = output_dir
            @config_loader = config_loader
          end

          # Generate API-based SPA with Sinatra server
          #
          # @param data [Hash] Serialized schema data
          # @param renderer [TemplateRenderer] Template renderer
          # @return [Array<String>] List of generated file paths
          def generate(data, renderer)
            log "Generating API-based SPA with Sinatra server..."

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

            # 1. Generate frontend HTML
            files << generate_frontend_html(data, renderer, context)

            # 2. Generate data JSON file
            files << generate_data_file(data)

            # 3. Generate Sinatra server
            files << generate_sinatra_app(data)

            # 4. Generate Rack config
            files << generate_config_ru

            # 5. Generate Gemfile
            files << generate_gemfile

            # 6. Generate README
            files << generate_readme(data)

            log "✓ API-based SPA generated in: #{output_dir}"
            log "✓ Start server with: cd #{output_dir} && bundle install && bundle exec rackup"
            files
          end

          protected

          # Prepare output directory structure
          #
          # @return [void]
          def prepare_output
            ensure_directory(output_dir)
            ensure_directory(File.join(output_dir, "public"))
            ensure_directory(File.join(output_dir, "lib"))
            ensure_directory(File.join(output_dir, "data"))
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
              "schemas" => [], # No schemas embedded in API mode
              "theme" => theme["theme"],
              "features" => features["features"],
              "templates" => templates_config["templates"],
              "api_mode" => true,
            }
          end

          # Generate frontend HTML with API fetch
          #
          # @param data [Hash] Schema data
          # @param renderer [TemplateRenderer] Renderer
          # @param context [Hash] Template context
          # @return [String] Path to index.html
          def generate_frontend_html(_data, renderer, context)
            # Render main content placeholder
            content_html = '<div id="app-content">Loading schemas...</div>'

            # Render layout with API fetch script
            html = renderer.render("layout.html.liquid", context.merge(
                                                           content: content_html,
                                                         ))

            # Inject API fetch logic
            html = inject_api_fetch_script(html)

            path = File.join(output_dir, "public", "index.html")
            write_file(path, html)
          end

          # Generate data JSON file
          #
          # @param data [Hash] Schema data
          # @return [String] Path to JSON file
          def generate_data_file(data)
            json = JSON.pretty_generate(data)

            path = File.join(output_dir, "data", "schemas.json")
            write_file(path, json)
          end

          # Generate Sinatra application
          #
          # @param data [Hash] Schema data (for metadata)
          # @return [String] Path to app.rb
          def generate_sinatra_app(data)
            app_code = <<~RUBY
              # frozen_string_literal: true

              require 'sinatra'
              require 'json'

              # Configure Sinatra
              set :port, ENV.fetch('PORT', 9292)
              set :bind, ENV.fetch('BIND', '0.0.0.0')
              set :public_folder, File.join(__dir__, '..', 'public')
              set :static, true

              # CORS headers for API access
              before do
                headers 'Access-Control-Allow-Origin' => '*',
                        'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                        'Access-Control-Allow-Headers' => 'Content-Type'
              end

              # Serve static frontend
              get '/' do
                send_file File.join(settings.public_folder, 'index.html')
              end

              # API endpoint - Get all schemas
              get '/api/schemas' do
                content_type :json

                data_file = File.join(__dir__, '..', 'data', 'schemas.json')

                if File.exist?(data_file)
                  File.read(data_file)
                else
                  status 404
                  { error: 'Schema data not found' }.to_json
                end
              end

              # API endpoint - Get schema by ID
              get '/api/schemas/:id' do
                content_type :json

                data_file = File.join(__dir__, '..', 'data', 'schemas.json')

                if File.exist?(data_file)
                  data = JSON.parse(File.read(data_file))
                  schema = data['schemas']&.find { |s| s['id'] == params[:id] }

                  if schema
                    schema.to_json
                  else
                    status 404
                    { error: 'Schema not found' }.to_json
                  end
                else
                  status 404
                  { error: 'Schema data not found' }.to_json
                end
              end

              # Health check endpoint
              get '/api/health' do
                content_type :json
                {
                  status: 'ok',
                  timestamp: Time.now.utc.iso8601,
                  version: '#{data[:metadata][:generator]}'
                }.to_json
              end

              # Handle OPTIONS for CORS preflight
              options '*' do
                200
              end
            RUBY

            path = File.join(output_dir, "lib", "app.rb")
            write_file(path, app_code)
          end

          # Generate Rack config file
          #
          # @return [String] Path to config.ru
          def generate_config_ru
            config_code = <<~RUBY
              # frozen_string_literal: true

              require_relative 'lib/app'

              run Sinatra::Application
            RUBY

            path = File.join(output_dir, "config.ru")
            write_file(path, config_code)
          end

          # Generate Gemfile
          #
          # @return [String] Path to Gemfile
          def generate_gemfile
            gemfile_content = <<~RUBY
              # frozen_string_literal: true

              source 'https://rubygems.org'

              gem 'sinatra', '~> 4.0'
              gem 'rackup', '~> 2.0'
              gem 'webrick', '~> 1.8'
            RUBY

            path = File.join(output_dir, "Gemfile")
            write_file(path, gemfile_content)
          end

          # Generate README with usage instructions
          #
          # @param data [Hash] Schema data (for metadata)
          # @return [String] Path to README.md
          def generate_readme(data)
            readme_content = <<~MARKDOWN
              # XSD Schema Documentation API Server

              Generated by #{data[:metadata][:generator]} on #{data[:metadata][:generated]}

              ## Overview

              This is an API-based documentation server for XSD schemas using Sinatra.
              The frontend is a Single Page Application that fetches schema data from the API.

              ## Directory Structure

              ```
              .
              ├── public/
              │   └── index.html      # Frontend SPA
              ├── lib/
              │   └── app.rb          # Sinatra server
              ├── data/
              │   └── schemas.json    # Schema data
              ├── config.ru           # Rack configuration
              ├── Gemfile             # Ruby dependencies
              └── README.md           # This file
              ```

              ## Setup

              1. Install dependencies:
                 ```bash
                 bundle install
                 ```

              2. Start the server:
                 ```bash
                 bundle exec rackup
                 ```

              3. Open your browser:
                 ```
                 http://localhost:9292
                 ```

              ## API Endpoints

              - `GET /` - Serve frontend HTML
              - `GET /api/schemas` - Get all schemas
              - `GET /api/schemas/:id` - Get specific schema by ID
              - `GET /api/health` - Health check endpoint

              ## Configuration

              You can configure the server using environment variables:

              - `PORT` - Server port (default: 9292)
              - `BIND` - Bind address (default: 0.0.0.0)

              Example:
              ```bash
              PORT=3000 bundle exec rackup
              ```

              ## Development

              For development with auto-reload:
              ```bash
              bundle exec rerun 'bundle exec rackup'
              ```

              (Requires `gem install rerun`)

              ## Production

              For production deployment, consider using:
              - Passenger
              - Puma
              - Unicorn

              Example with Puma:
              ```bash
              bundle add puma
              bundle exec puma config.ru
              ```

              ## Schema Count

              This documentation contains #{data[:schemas]&.size || 0} schema(s).

              ## License

              Same license as the source XSD schemas.
            MARKDOWN

            path = File.join(output_dir, "README.md")
            write_file(path, readme_content)
          end

          # Inject API fetch script into HTML
          #
          # @param html [String] HTML content
          # @return [String] Modified HTML with API fetch
          def inject_api_fetch_script(html)
            api_script = <<~JAVASCRIPT

              <script>
                // API Configuration
                const API_BASE = window.location.origin;

                // Fetch schemas from API
                async function loadSchemas() {
                  try {
                    const response = await fetch(`${API_BASE}/api/schemas`);
                    if (!response.ok) {
                      throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    const data = await response.json();

                    // Populate Search.data
                    if (typeof Search !== 'undefined') {
                      Search.data = data.schemas || [];
                    }

                    // Render schemas
                    renderSchemas(data.schemas || []);
                  } catch (error) {
                    console.error('Failed to load schemas:', error);
                    showError('Failed to load schema data. Please ensure the server is running.');
                  }
                }

                // Render schemas into the page
                function renderSchemas(schemas) {
                  const container = document.getElementById('app-content');
                  if (!container) return;

                  if (schemas.length === 0) {
                    container.innerHTML = '<p>No schemas found.</p>';
                    return;
                  }

                  // Render schema cards
                  container.innerHTML = schemas.map(schema => `
                    <div class="schema-card">
                      <h3>${schema.name || 'Unnamed Schema'}</h3>
                      <p><strong>Namespace:</strong> ${schema.namespace || 'N/A'}</p>
                      <p><strong>Elements:</strong> ${(schema.elements || []).length}</p>
                      <p><strong>Complex Types:</strong> ${(schema.complex_types || []).length}</p>
                      <p><strong>Simple Types:</strong> ${(schema.simple_types || []).length}</p>
                    </div>
                  `).join('');
                }

                // Show error message
                function showError(message) {
                  const container = document.getElementById('app-content');
                  if (container) {
                    container.innerHTML = `
                      <div class="error-message" style="padding: 2rem; background: #fee; border-left: 4px solid #c00; color: #c00;">
                        <strong>Error:</strong> ${message}
                      </div>
                    `;
                  }
                }

                // Load schemas when page loads
                document.addEventListener('DOMContentLoaded', loadSchemas);
              </script>
            JAVASCRIPT

            # Insert before closing body tag
            html.sub("</body>", "#{api_script}\n</body>")
          end
        end
      end
    end
  end
end
