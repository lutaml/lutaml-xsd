# frozen_string_literal: true

require "thor"
require_relative "commands/pkg_command"
require_relative "commands/xml_command"
require_relative "commands/build_command"
require_relative "commands/doc_command"
require_relative "commands/type_command"
require_relative "commands/search_command"
require_relative "commands/namespace_command"
require_relative "commands/element_command"

module Lutaml
  module Xsd
    # Main CLI class for lutaml-xsd command-line interface
    # Provides MECE command structure: pkg, xml, build, doc
    class Cli < Thor
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output"

      desc "pkg SUBCOMMAND", "Package inspection commands"
      long_desc <<~DESC
        Inspect and query schema repository packages.

        Commands:
          ls           - List all schemas in package
          tree         - Show package file tree
          inspect      - Show full package details
          stats        - Display package statistics
          extract      - Extract a schema from package
          coverage     - Analyze schema coverage
          verify       - Verify XSD specification compliance
          metadata     - Manage package metadata
          type         - Query and explore schema types
          search       - Search for types by name or documentation
          namespace    - Explore namespaces
          element      - Explore elements

        Examples:
          lutaml-xsd pkg ls my-schemas.lxr
          lutaml-xsd pkg tree my-schemas.lxr
          lutaml-xsd pkg stats my-schemas.lxr
          lutaml-xsd pkg type find "gml:CodeType" schemas.lxr
          lutaml-xsd pkg search "unit" schemas.lxr
      DESC
      subcommand "pkg", Commands::PkgCommand

      desc "xml SUBCOMMAND", "XML validation commands"
      long_desc <<~DESC
        Validate XML files against XSD schemas.

        Commands:
          validate     - Validate XML instance files

        Examples:
          lutaml-xsd xml validate instance.xml schemas.lxr
          lutaml-xsd xml validate *.xml schemas.lxr
      DESC
      subcommand "xml", Commands::XmlCommand

      desc "build SUBCOMMAND", "Package creation commands"
      long_desc <<~DESC
        Build and manage schema repository packages.

        Commands:
          from-config        - Build package from YAML configuration
          init               - Interactive package initialization
          quick              - Quick build + validate + stats workflow
          auto               - Auto-build with smart caching
          validate           - Validate a package
          validate-resolution - Validate all references are resolved

        Examples:
          lutaml-xsd build from-config config.yml
          lutaml-xsd build init schema.xsd
          lutaml-xsd build quick config.yml
      DESC
      subcommand "build", Commands::BuildCommand

      desc "doc SUBCOMMAND", "Documentation generation commands"
      long_desc <<~DESC
        Generate documentation from schema packages.

        Commands:
          spa          - Generate interactive SPA documentation

        Examples:
          lutaml-xsd doc spa schemas.lxr --mode single_file --output docs.html
          lutaml-xsd doc spa schemas.lxr --mode multi_file --output-dir ./docs
      DESC
      subcommand "doc", Commands::DocCommand

      desc "version", "Display lutaml-xsd version"
      def version
        puts "lutaml-xsd version #{Lutaml::Xsd::VERSION}"
      end

      # Error handler
      def self.exit_on_failure?
        true
      end
    end
  end
end
