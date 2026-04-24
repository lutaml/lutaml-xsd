# frozen_string_literal: true

require "json"
require_relative "../output_strategy"

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # RngVueInlinedStrategy - Generates a single HTML file with RNG Vue app inlined
        #
        # Reads pre-built RNG-specific frontend assets from frontend-rng/dist/
        # and embeds them in a self-contained HTML file.
        #
        # @example
        #   strategy = RngVueInlinedStrategy.new(
        #     'output/grammar-docs.html',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, nil)
        class RngVueInlinedStrategy < OutputStrategy
          attr_reader :output_path, :config_loader

          def initialize(output_path, config_loader, verbose: false)
            super(verbose: verbose)
            @output_path = output_path
            @config_loader = config_loader
          end

          # Generate single HTML file with RNG Vue app inlined
          #
          # @param data [Hash] Serialized RNG data
          # @param _renderer [Object] Unused
          # @return [Array<String>] List containing single file path
          def generate(data, _renderer)
            log "Generating RNG Vue inlined SPA..."

            app_js = read_frontend_asset("app.iife.js")
            app_css = read_frontend_asset("style.css")

            html = build_html_document(data, app_js, app_css)

            prepare_output
            files = [write_file(output_path, html)]

            log "✓ RNG SPA generated: #{output_path}"
            files
          end

          protected

          def read_frontend_asset(filename)
            asset_path = find_frontend_asset(filename)
            if asset_path && File.exist?(asset_path)
              File.read(asset_path)
            else
              raise(
                "RNG frontend asset not found: #{filename}. " \
                "Run 'cd frontend-rng && npm install && npm run build' first.",
              )
            end
          end

          def find_frontend_asset(filename)
            path = File.join(__dir__, "..", "..", "..", "..", "..",
                             "frontend-rng", "dist", filename)
            File.exist?(path) ? path : nil
          end

          def build_html_document(data, app_js, app_css)
            rng_data_json = data.to_json
            metadata = data[:metadata] || {}
            title = metadata[:title] || metadata[:name] || "RNG Grammar Documentation"

            <<~HTML
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta name="generator" content="lutaml-xsd #{Lutaml::Xsd::VERSION}">
                <meta name="description" content="RNG Grammar Documentation">
                <title>#{title}</title>

                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

                <style>
                #{app_css}
                </style>
              </head>
              <body>
                <div id="app"></div>

                <script>
                window.RNG_DATA = #{rng_data_json};
                </script>

                <script>
                #{app_js}
                </script>
              </body>
              </html>
            HTML
          end

          def prepare_output
            dir = File.dirname(output_path)
            ensure_directory(dir) unless dir == "."
          end
        end
      end
    end
  end
end
