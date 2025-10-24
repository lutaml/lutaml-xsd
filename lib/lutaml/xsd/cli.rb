# frozen_string_literal: true

require "thor"
require_relative "commands/package_command"
require_relative "commands/type_command"
require_relative "commands/stats_command"

module Lutaml
  module Xsd
    # Main CLI class for lutaml-xsd command-line interface
    # Provides commands for package management, type queries, and statistics
    class Cli < Thor
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output"

      desc "package SUBCOMMAND", "Manage schema repository packages"
      subcommand "package", Commands::PackageCommand

      desc "type SUBCOMMAND", "Query and explore schema types"
      subcommand "type", Commands::TypeCommand

      desc "stats SUBCOMMAND", "Display repository statistics"
      subcommand "stats", Commands::StatsCommand

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
