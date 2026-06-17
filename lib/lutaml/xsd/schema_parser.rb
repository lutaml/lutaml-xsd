# frozen_string_literal: true

require "yaml"
require "zip"
require "lutaml/store"

module Lutaml
  module Xsd
    # Handles parsing of XSD and RNG schema files into the repository's store.
    # Extracted from SchemaRepository to separate parsing concerns.
    class SchemaParser
      attr_reader :store, :schema

      def initialize(repository)
        @repository = repository
        @store = repository.parsed_schemas
        @schema = nil
      end

      # Parse all configured schema files
      def parse(files, glob_mappings, verbose: false)
        if verbose
          puts "Parsing #{files.size} schema files..."
          files.each_with_index do |file_path, idx|
            print "\r[#{idx + 1}/#{files.size}] #{File.basename(file_path)}"
            $stdout.flush
            parse_file(file_path, glob_mappings)
          end
          puts "\n✓ All schemas parsed"
        else
          files.each { |file_path| parse_file(file_path, glob_mappings) }
        end
      end

      # Parse a single schema file (XSD or RNG/RNC)
      def parse_file(file_path, glob_mappings)
        return if store.exists?(file_path)
        return unless File.exist?(file_path)

        ext = File.extname(file_path).downcase
        parsed_schema = if %w[.rng .rnc].include?(ext)
                          parse_rng(file_path)
                        else
                          parse_xsd(file_path, glob_mappings)
                        end

        store.set(file_path, parsed_schema)
        import_resolved_schemas
      rescue StandardError => e
        warn "Warning: Failed to parse schema #{file_path}: #{e.message}"
      end

      private

      def import_resolved_schemas
        global_cache = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
        global_cache.each do |path, schema|
          store.set(path, schema) unless store.exists?(path)
        end
      end

      def parse_xsd(file_path, glob_mappings)
        xsd_content = File.read(file_path)
        Lutaml::Xml::Schema::Xsd.parse(
          xsd_content,
          location: File.dirname(file_path),
          schema_mappings: glob_mappings,
        )
      end

      def parse_rng(file_path)
        require "rng"

        grammar = if file_path.downcase.end_with?(".rnc")
                    Rng.parse_file(file_path)
                  else
                    rng_content = File.read(file_path)
                    Rng.parse(rng_content,
                              location: File.dirname(file_path),
                              resolve_external: true)
                  end

        schema = RngToXsdConverter.new(grammar, file_path: file_path).convert
        write_generated_xsd(file_path, schema)
        schema
      end

      def write_generated_xsd(file_path, schema)
        xsd_content = schema.to_formatted_xml
        xsd_path = file_path.sub(/\.(rng|rnc)$/i, ".xsd")

        begin
          File.write(xsd_path, xsd_content)
        rescue StandardError
          require "tmpdir"
          xsd_path = File.join(Dir.tmpdir, "lutaml_xsd_#{File.basename(file_path, '.*')}.xsd")
          File.write(xsd_path, xsd_content)
        end

        update_rng_references(file_path, xsd_path)
      end

      def update_rng_references(old_path, new_path)
        files = @repository.files
        if files
          idx = files.index(old_path)
          files[idx] = new_path if idx
        end

        if store.exists?(old_path)
          store.set(new_path, store.get(old_path))
          store.delete(old_path)
        end

        cached = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
        if cached.key?(old_path)
          cached[new_path] = cached.delete(old_path)
        end
      end
    end
  end
end
