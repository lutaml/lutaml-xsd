# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Validates a SchemaRepository's state. Run after parse/resolve to
      # surface file-not-found, parse-failure, mapping-shape, and circular
      # import errors as a flat list rather than raising piecemeal.
      class Validator
        def initialize(repository)
          @repository = repository
        end

        def validate(strict: false)
          errors = []

          validate_file_existence(errors, strict)
          validate_parsed_schemas(errors, strict)
          check_circular_imports(errors, strict)
          validate_namespace_mappings(errors, strict)

          errors
        end

        private

        def validate_file_existence(errors, strict)
          (@repository.files || []).each do |file_path|
            next if File.exist?(file_path)

            error = "Schema file not found: #{file_path}"
            errors << error
            raise Error, error if strict
          end
        end

        def validate_parsed_schemas(errors, strict)
          missing_schemas = (@repository.files || []).reject do |f|
            @repository.parsed_schemas.exists?(f)
          end
          return if missing_schemas.empty?

          error = "Failed to parse schemas: #{missing_schemas.join(', ')}"
          errors << error
          raise Error, error if strict
        end

        def validate_namespace_mappings(errors, strict)
          (@repository.namespace_mappings || []).each do |mapping|
            if mapping.prefix.nil? || mapping.prefix.empty?
              error = "Invalid namespace mapping: prefix cannot be empty"
              errors << error
              raise Error, error if strict
            end
            next unless mapping.uri.nil? || mapping.uri.empty?

            error = "Invalid namespace mapping for prefix '#{mapping.prefix}': URI cannot be empty"
            errors << error
            raise Error, error if strict
          end
        end

        def check_circular_imports(errors, strict)
          dependencies = build_dependency_graph
          visited = {}

          dependencies.each_key do |file|
            next unless has_circular_dependency?(file, dependencies, visited, [])

            error = "Circular import detected involving: #{file}"
            errors << error
            raise Error, error if strict
          end
        end

        def build_dependency_graph
          dependencies = {}
          @repository.parsed_schemas.all.each do |file_path, schema|
            deps = (schema.imports || []).map(&:schema_path)
            (schema.includes || []).each do |inc|
              deps << inc.schema_path
            end
            dependencies[file_path] = deps.compact
          end
          dependencies
        end

        def has_circular_dependency?(file, dependencies, visited, path)
          return false if visited[file] == :permanent
          return true if path.include?(file)

          visited[file] = :temporary
          path.push(file)

          (dependencies[file] || []).each do |dep|
            return true if has_circular_dependency?(dep, dependencies, visited, path)
          end

          path.pop
          visited[file] = :permanent
          false
        end
      end
    end
  end
end
