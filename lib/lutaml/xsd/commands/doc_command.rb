# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Documentation generation commands (MECE category)
      # Handles all documentation generation operations
      class DocCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "spa PACKAGE", "Generate interactive SPA documentation"
        long_desc <<~DESC
          Generate interactive HTML Single Page Application documentation from XSD schemas.

          Examples:
            # Generate single-file documentation
            lutaml-xsd doc spa schemas.lxr --mode single_file --output docs.html

            # Generate multi-file documentation site
            lutaml-xsd doc spa schemas.lxr --mode multi_file --output-dir ./docs

            # Generate API-based documentation with Sinatra server
            lutaml-xsd doc spa schemas.lxr --mode api --output-dir ./docs-api

            # With custom configuration
            lutaml-xsd doc spa schemas.lxr --mode single_file --output docs.html --config spa.yml

            # With custom title
            lutaml-xsd doc spa schemas.lxr --mode single_file --output docs.html --title "My Schema Docs"
        DESC
        option :mode,
               type: :string,
               default: "single_file",
               enum: %w[single_file multi_file api],
               desc: "Output mode: single_file (embedded JSON), multi_file (separate files), api (Sinatra server)"
        option :output,
               type: :string,
               desc: "Output file path (for single_file mode)"
        option :output_dir,
               type: :string,
               desc: "Output directory (for multi_file and api modes)"
        option :config,
               type: :string,
               desc: "Path to SPA configuration file"
        option :title,
               type: :string,
               desc: "Documentation title"
        def spa(package_path)
          require_relative "generate_spa_command"
          GenerateSpaCommand.new(package_path, options).run
        end
      end
    end
  end
end