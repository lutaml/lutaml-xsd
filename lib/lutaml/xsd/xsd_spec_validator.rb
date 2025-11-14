# frozen_string_literal: true

module Lutaml
  module Xsd
    # Validates XSD schemas against W3C XSD specification
    # Single responsibility: check spec compliance
    class XsdSpecValidator
      attr_reader :repository, :version

      def initialize(repository, version: "1.0")
        @repository = repository
        @version = version # '1.0' or '1.1'
      end

      # Validate all schemas in repository
      # Returns SpecComplianceReport
      def validate
        errors = []
        warnings = []

        # Apply validation rules based on XSD version
        validation_rules.each do |rule|
          rule_result = rule.validate(repository)
          errors.concat(rule_result[:errors])
          warnings.concat(rule_result[:warnings])
        end

        SpecComplianceReport.new(
          version: @version,
          valid: errors.empty?,
          errors: errors,
          warnings: warnings,
          schemas_checked: repository.all_schemas.size
        )
      end

      private

      def validation_rules
        # Return array of validation rule objects
        # Extensible: can add new rules easily
        [
          TargetNamespaceRule.new(@version),
          ElementFormDefaultRule.new(@version),
          AttributeFormDefaultRule.new(@version),
          CircularImportRule.new(@version),
          DuplicateDefinitionRule.new(@version),
          SchemaLocationRule.new(@version),
          NamespaceConsistencyRule.new(@version)
        ]
      end
    end

    # Base class for validation rules (Strategy pattern)
    class ValidationRule
      attr_reader :version

      def initialize(version)
        @version = version
      end

      def validate(repository)
        { errors: [], warnings: [] }
      end

      protected

      # Get all schemas from repository
      def get_schemas(repository)
        repository.all_schemas
      end
    end

    # Validates target namespace requirements
    class TargetNamespaceRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        get_schemas(repository).each do |schema_file, schema|
          # Check if target namespace is properly defined
          if schema.target_namespace.nil? || schema.target_namespace.empty?
            warnings << "Schema #{File.basename(schema_file)} has no target namespace"
          elsif schema.target_namespace !~ /^https?:\/\//
            warnings << "Schema #{File.basename(schema_file)} target namespace '#{schema.target_namespace}' is not a URI"
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Validates elementFormDefault and attributeFormDefault settings
    class ElementFormDefaultRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        get_schemas(repository).each do |schema_file, schema|
          # XSD best practice: explicitly set elementFormDefault
          unless schema.element_form_default
            warnings << "Schema #{File.basename(schema_file)} does not explicitly set elementFormDefault (defaults to 'unqualified')"
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Validates attributeFormDefault settings
    class AttributeFormDefaultRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        get_schemas(repository).each do |schema_file, schema|
          # XSD best practice: explicitly set attributeFormDefault
          unless schema.attribute_form_default
            warnings << "Schema #{File.basename(schema_file)} does not explicitly set attributeFormDefault (defaults to 'unqualified')"
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Validates for circular import chains
    class CircularImportRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        # Build dependency graph
        dependencies = build_dependency_graph(repository)

        # Check for circular dependencies
        visited = {}
        dependencies.each_key do |file|
          if has_circular_dependency?(file, dependencies, visited, [])
            errors << "Circular import chain detected involving schema: #{File.basename(file)}"
          end
        end

        { errors: errors, warnings: warnings }
      end

      private

      def build_dependency_graph(repository)
        dependencies = {}

        get_schemas(repository).each do |file_path, schema|
          deps = []

          # Collect import dependencies
          imports = schema.respond_to?(:import) ? schema.import : []
          (imports || []).each do |import|
            deps << import.schema_path if import.respond_to?(:schema_path)
          end

          # Collect include dependencies
          includes = schema.respond_to?(:include) ? schema.include : []
          (includes || []).each do |include|
            deps << include.schema_path if include.respond_to?(:schema_path)
          end

          dependencies[file_path] = deps.compact
        end

        dependencies
      end

      def has_circular_dependency?(file, dependencies, visited, path)
        return false if visited[file] == :permanent

        if path.include?(file)
          return true # Circular dependency found
        end

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

    # Validates for duplicate type/element/attribute definitions
    class DuplicateDefinitionRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        # Track definitions by namespace and name
        definitions = {}

        get_schemas(repository).each do |schema_file, schema|
          namespace = schema.target_namespace || "(no namespace)"

          # Check complex types
          (schema.complex_type || []).each do |type|
            next unless type.name

            key = "#{namespace}::complexType::#{type.name}"
            if definitions[key]
              errors << "Duplicate complexType '#{type.name}' in namespace '#{namespace}' (#{File.basename(schema_file)} and #{File.basename(definitions[key])})"
            else
              definitions[key] = schema_file
            end
          end

          # Check simple types
          (schema.simple_type || []).each do |type|
            next unless type.name

            key = "#{namespace}::simpleType::#{type.name}"
            if definitions[key]
              errors << "Duplicate simpleType '#{type.name}' in namespace '#{namespace}' (#{File.basename(schema_file)} and #{File.basename(definitions[key])})"
            else
              definitions[key] = schema_file
            end
          end

          # Check elements
          (schema.element || []).each do |elem|
            next unless elem.name

            key = "#{namespace}::element::#{elem.name}"
            if definitions[key]
              errors << "Duplicate element '#{elem.name}' in namespace '#{namespace}' (#{File.basename(schema_file)} and #{File.basename(definitions[key])})"
            else
              definitions[key] = schema_file
            end
          end

          # Check attributes
          (schema.attribute || []).each do |attr|
            next unless attr.name

            key = "#{namespace}::attribute::#{attr.name}"
            if definitions[key]
              errors << "Duplicate attribute '#{attr.name}' in namespace '#{namespace}' (#{File.basename(schema_file)} and #{File.basename(definitions[key])})"
            else
              definitions[key] = schema_file
            end
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Validates schemaLocation attributes
    class SchemaLocationRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        get_schemas(repository).each do |schema_file, schema|
          # Check imports
          imports = schema.respond_to?(:import) ? schema.import : []
          (imports || []).each do |import|
            next unless import.respond_to?(:namespace) && import.namespace

            if !import.respond_to?(:schema_path) || !import.schema_path || import.schema_path.empty?
              warnings << "Import in #{File.basename(schema_file)} for namespace '#{import.namespace}' has no schemaLocation"
            end
          end

          # Check includes
          includes = schema.respond_to?(:include) ? schema.include : []
          (includes || []).each do |include|
            if !include.respond_to?(:schema_path) || !include.schema_path || include.schema_path.empty?
              errors << "Include in #{File.basename(schema_file)} has no schemaLocation"
            end
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Validates namespace consistency
    class NamespaceConsistencyRule < ValidationRule
      def validate(repository)
        errors = []
        warnings = []

        # Track which namespaces are defined in which files
        namespace_files = {}

        get_schemas(repository).each do |schema_file, schema|
          namespace = schema.target_namespace
          next unless namespace

          namespace_files[namespace] ||= []
          namespace_files[namespace] << schema_file
        end

        # Check for namespaces defined in multiple files
        namespace_files.each do |namespace, files|
          if files.size > 1
            warnings << "Namespace '#{namespace}' is defined in #{files.size} schemas: #{files.map { |f| File.basename(f) }.join(", ")}"
          end
        end

        { errors: errors, warnings: warnings }
      end
    end

    # Value object for validation report
    class SpecComplianceReport
      attr_reader :version, :valid, :errors, :warnings, :schemas_checked

      def initialize(version:, valid:, errors:, warnings:, schemas_checked:)
        @version = version
        @valid = valid
        @errors = errors
        @warnings = warnings
        @schemas_checked = schemas_checked
      end

      def to_h
        {
          xsd_version: version,
          valid: valid,
          schemas_checked: schemas_checked,
          errors: errors,
          warnings: warnings,
          error_count: errors.size,
          warning_count: warnings.size
        }
      end
    end
  end
end