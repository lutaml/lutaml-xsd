# frozen_string_literal: true

require "json"
require_relative "xml_instance_generator"
require_relative "svg/diagram_generator"

module Lutaml
  module Xsd
    module Spa
      # Base class for schema serializers (Template Method Pattern)
      #
      # Defines the overall algorithm for serializing XSD schema repositories
      # into a format suitable for SPA documentation. Subclasses can override
      # specific steps to customize the serialization process.
      #
      # The serialization process follows these steps:
      # 1. Build metadata
      # 2. Serialize all schemas
      # 3. Build search index
      # 4. Assemble final structure
      #
      # @abstract Subclass and override template methods to customize
      #   serialization
      #
      # @example Using the serializer
      #   serializer = JsonSchemaSerializer.new(repository)
      #   data = serializer.serialize
      #   json = serializer.to_json
      class SchemaSerializer
        attr_reader :repository, :config, :package

        # Initialize schema serializer
        #
        # @param repository_or_package [SchemaRepository, SchemaRepositoryPackage] Schema repository or package to serialize
        # @param config [Hash] Configuration options
        def initialize(repository_or_package, config = {})
          if repository_or_package.is_a?(SchemaRepositoryPackage)
            @package = repository_or_package
            @repository = repository_or_package.repository
          else
            @repository = repository_or_package
            @package = nil
          end
          @config = config
        end

        # Serialize repository to data structure (template method)
        #
        # This method defines the overall algorithm for serialization.
        # Subclasses can override individual steps as needed.
        #
        # @return [Hash] Serialized data structure
        def serialize
          {
            metadata: build_metadata,
            schemas: serialize_schemas,
            index: build_index
          }
        end

        # Convert serialized data to JSON string
        #
        # @param pretty [Boolean] Whether to pretty-print JSON
        # @return [String] JSON string
        def to_json(pretty: true)
          data = serialize
          pretty ? JSON.pretty_generate(data) : JSON.generate(data)
        end

        protected

        # Build metadata section (template method hook)
        #
        # Subclasses can override to customize metadata
        #
        # @return [Hash] Metadata
        def build_metadata
          {
            generated: current_timestamp,
            generator: generator_info,
            title: config["title"] || default_title,
            schema_count: get_schemas.size
          }
        end

        # Serialize all schemas (template method hook)
        #
        # @return [Array<Hash>] Array of serialized schemas
        def serialize_schemas
          get_schemas.map.with_index do |(file_path, schema), index|
            serialize_schema(schema, index, file_path)
          end
        end

        # Serialize single schema (template method hook)
        #
        # Subclasses should override to customize schema serialization
        #
        # @param schema [Schema] Schema object
        # @param index [Integer] Schema index
        # @param file_path [String] Schema file path
        # @return [Hash] Serialized schema
        def serialize_schema(schema, index, file_path = nil)
          {
            id: schema_id(index, schema, file_path),
            name: schema_name(schema, file_path),
            namespace: schema.target_namespace,
            file_path: clean_file_path(file_path),
            is_entrypoint: is_entrypoint?(file_path),
            elements: serialize_elements(schema),
            complex_types: serialize_complex_types(schema),
            simple_types: serialize_simple_types(schema),
            attributes: serialize_attributes(schema),
            groups: serialize_groups(schema)
          }
        end

        # Build search index (template method hook)
        #
        # Subclasses can override to customize indexing
        #
        # @return [Hash] Search index
        def build_index
          {
            by_id: build_id_index,
            by_name: build_name_index,
            by_type: build_type_index
          }
        end

        # Serialize elements from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized elements
        def serialize_elements(schema)
          return [] unless schema.respond_to?(:element)

          schema.element.map.with_index do |element, index|
            serialize_element(element, index)
          end
        end

        # Serialize single element
        #
        # @param element [Element] Element object
        # @param index [Integer] Element index
        # @return [Hash] Serialized element
        def serialize_element(element, index)
          element_data = {
            id: element_id(index, element),
            name: element.name,
            type: element.type,
            min_occurs: element.min_occurs,
            max_occurs: element.max_occurs,
            documentation: extract_documentation(element),
            instance_xml: generate_instance_xml(element)
          }

          # Add SVG diagram
          element_data[:diagram_svg] = generate_diagram(element_data, :element)

          element_data
        end

        # Serialize complex types from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized complex types
        def serialize_complex_types(schema)
          return [] unless schema.respond_to?(:complex_type)

          schema.complex_type.map.with_index do |type, index|
            serialize_complex_type(type, index)
          end
        end

        # Serialize single complex type
        #
        # @param type [ComplexType] Complex type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized complex type
        def serialize_complex_type(type, index)
          type_data = {
            id: complex_type_id(index, type),
            name: type.name,
            base: extract_base_type(type),
            content_model: extract_content_model(type),
            attributes: serialize_type_attributes(type),
            elements: serialize_type_elements(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type)
          }

          # Add SVG diagram
          type_data[:diagram_svg] = generate_diagram(type_data, :type)

          type_data
        end

        # Serialize simple types from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized simple types
        def serialize_simple_types(schema)
          return [] unless schema.respond_to?(:simple_type)

          schema.simple_type.map.with_index do |type, index|
            serialize_simple_type(type, index)
          end
        end

        # Serialize single simple type
        #
        # @param type [SimpleType] Simple type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized simple type
        def serialize_simple_type(type, index)
          {
            id: simple_type_id(index, type),
            name: type.name,
            base: extract_simple_base(type),
            restriction: serialize_restriction(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type)
          }
        end

        # Serialize attributes from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized attributes
        def serialize_attributes(schema)
          return [] unless schema.respond_to?(:attribute)

          schema.attribute.map.with_index do |attr, index|
            serialize_attribute(attr, index)
          end
        end

        # Serialize single attribute
        #
        # @param attr [Attribute] Attribute object
        # @param index [Integer] Attribute index
        # @return [Hash] Serialized attribute
        def serialize_attribute(attr, index)
          {
            id: attribute_id(index, attr),
            name: attr.name,
            type: attr.type,
            use: attr.use,
            default: attr.default,
            documentation: extract_documentation(attr)
          }
        end

        # Serialize groups from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized groups
        def serialize_groups(schema)
          return [] unless schema.respond_to?(:group)

          schema.group.map.with_index do |group, index|
            serialize_group(group, index)
          end
        end

        # Serialize single group
        #
        # @param group [Group] Group object
        # @param index [Integer] Group index
        # @return [Hash] Serialized group
        def serialize_group(group, index)
          {
            id: group_id(index, group),
            name: group.name,
            documentation: extract_documentation(group)
          }
        end

        # Serialize type attributes
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized attributes
        def serialize_type_attributes(type)
          return [] unless type.respond_to?(:attributes)

          type.attributes.map do |attr|
            {
              name: attr.name,
              type: attr.type,
              use: attr.use
            }
          end
        end

        # Serialize type elements
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized elements
        def serialize_type_elements(type)
          return [] unless type.respond_to?(:elements)

          type.elements.map do |elem|
            {
              name: elem.name,
              type: elem.type,
              min_occurs: elem.min_occurs,
              max_occurs: elem.max_occurs
            }
          end
        end

        # Serialize restriction
        #
        # @param type [SimpleType] Simple type
        # @return [Hash, nil] Restriction data
        def serialize_restriction(type)
          return nil unless type.respond_to?(:restriction)

          restriction = type.restriction
          return nil unless restriction

          {
            base: restriction.base,
            facets: serialize_facets(restriction)
          }
        end

        # Serialize facets
        #
        # @param restriction [Restriction] Restriction object
        # @return [Array<Hash>] Serialized facets
        def serialize_facets(restriction)
          facets = []

          if restriction.respond_to?(:enumerations) && restriction.enumerations
            facets << { type: "enumeration", values: restriction.enumerations }
          end

          if restriction.respond_to?(:pattern) && restriction.pattern
            facets << { type: "pattern", value: restriction.pattern }
          end

          if restriction.respond_to?(:min_length) && restriction.min_length
            facets << { type: "min_length", value: restriction.min_length }
          end

          if restriction.respond_to?(:max_length) && restriction.max_length
            facets << { type: "max_length", value: restriction.max_length }
          end

          facets
        end

        # Extract documentation from object
        #
        # @param obj [Object] Schema object
        # @return [String, nil] Documentation text
        def extract_documentation(obj)
          return nil unless obj.respond_to?(:annotation)
          return nil unless obj.annotation
          return nil unless obj.annotation.respond_to?(:documentations)

          docs = obj.annotation.documentations
          return nil if docs.empty?

          docs.map(&:content).join("\n")
        end

        # Extract content model from complex type
        #
        # @param type [ComplexType] Complex type
        # @return [String] Content model type
        def extract_content_model(type)
          return "sequence" if type.respond_to?(:sequence) && type.sequence
          return "choice" if type.respond_to?(:choice) && type.choice
          return "all" if type.respond_to?(:all) && type.all
          return "complex_content" if type.respond_to?(:complex_content) && type.complex_content
          return "simple_content" if type.respond_to?(:simple_content) && type.simple_content

          "empty"
        end

        # Extract base type from complex type
        #
        # @param type [ComplexType] Complex type
        # @return [String, nil] Base type name
        def extract_base_type(type)
          # Check complex_content for extension or restriction
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              return cc.extension.base if cc.extension.respond_to?(:base)
            elsif cc.respond_to?(:restriction) && cc.restriction
              return cc.restriction.base if cc.restriction.respond_to?(:base)
            end
          end

          # Check simple_content for extension or restriction
          if type.respond_to?(:simple_content) && type.simple_content
            sc = type.simple_content
            if sc.respond_to?(:extension) && sc.extension
              return sc.extension.base if sc.extension.respond_to?(:base)
            elsif sc.respond_to?(:restriction) && sc.restriction
              return sc.restriction.base if sc.restriction.respond_to?(:base)
            end
          end

          nil
        end

        # Extract base type from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [String, nil] Base type name
        def extract_simple_base(type)
          if type.respond_to?(:restriction) && type.restriction
            return type.restriction.base if type.restriction.respond_to?(:base)
          end

          if type.respond_to?(:list) && type.list
            return type.list.item_type if type.list.respond_to?(:item_type)
          end

          if type.respond_to?(:union) && type.union
            return "union" # Union types have multiple bases
          end

          nil
        end

        # ID generation methods

        # Helper: Slugify for URL-safe IDs with CamelCase support
        #
        # @param name [String, nil] Name to slugify
        # @return [String] URL-safe slug
        def slugify(name)
          return "unnamed" unless name

          name.to_s
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')  # Split acronyms: HTTPParser → HTTP-Parser
            .gsub(/([a-z\d])([A-Z])/, '\1-\2')      # Split camelCase: fooBar → foo-Bar
            .downcase                                # Convert to lowercase
            .gsub(/[^a-z0-9]+/, '-')                # Replace non-alphanumeric with dash
            .gsub(/^-|-$/, '')                       # Remove leading/trailing dashes
        end

        def schema_id(index, schema = nil, file_path = nil)
          # Use schema name instead of index
          name = schema_name(schema, file_path) if schema
          name ||= "schema-#{index}"  # Fallback
          slugify(name)
        end

        def element_id(index, element = nil)
          # Use element name if available
          return slugify(element.name) if element&.name
          "element-#{index}"  # Fallback
        end

        def complex_type_id(index, type = nil)
          # Use type name if available
          return "type-#{slugify(type.name)}" if type&.name
          "type-#{index}"  # Fallback
        end

        def simple_type_id(index, type = nil)
          # Differentiate from complex types
          return "simpletype-#{slugify(type.name)}" if type&.name
          "simpletype-#{index}"  # Fallback
        end

        def attribute_id(index, attr = nil)
          # Use attribute name if available
          return "attr-#{slugify(attr.name)}" if attr&.name
          "attr-#{index}"  # Fallback
        end

        def group_id(index, group = nil)
          # Use group name if available
          return "group-#{slugify(group.name)}" if group&.name
          "group-#{index}"  # Fallback
        end

        # Helper methods

        def current_timestamp
          Time.now.utc.iso8601
        end

        def generator_info
          "lutaml-xsd v#{Lutaml::Xsd::VERSION}"
        end

        def default_title
          "XSD Schema Documentation"
        end

        def schema_name(schema, file_path = nil)
          # Prioritize target namespace for consistent schema identification
          # This ensures links use namespace-based IDs instead of filenames
          if schema.respond_to?(:target_namespace) && schema.target_namespace
            # Extract last meaningful part of namespace URI as name
            uri = schema.target_namespace
            # For URNs like "urn:oasis:names:tc:unitsml:schema:xsd:UnitsML-Schema-1.0"
            # extract the last part
            last_part = uri.split('/').last || uri.split(':').last || "unnamed"
            return last_part unless last_part == "unnamed"
          end

          # Fallback to filename only if namespace not available
          if file_path && !file_path.empty?
            return File.basename(file_path, ".*")
          end

          "unnamed"
        end

        # Check if file path is an entrypoint
        #
        # @param file_path [String, nil] File path to check
        # @return [Boolean] True if file is an entrypoint
        def is_entrypoint?(file_path)
          return false unless file_path

          # Get original entrypoint files from package metadata
          # The metadata.files contains ONLY the original entry points,
          # not the resolved dependencies
          entrypoint_files = []

          if package && package.respond_to?(:metadata)
            metadata = package.metadata || {}
            entrypoint_files = metadata[:files] || metadata["files"] || []
          elsif repository.respond_to?(:files) && !repository.respond_to?(:all_schemas)
            # Direct repository has files attribute
            entrypoint_files = repository.files || []
          end

          return false if entrypoint_files.empty?

          # Compare just the filename (basename) since paths may differ
          # between metadata (original paths) and serialized schemas (temp paths)
          file_basename = File.basename(file_path).downcase
          entrypoint_files.any? do |entry_path|
            File.basename(entry_path.to_s).downcase == file_basename
          end
        end

        # Clean file path to show relative path within package
        #
        # @param file_path [String, nil] Full file path
        # @return [String, nil] Cleaned path
        def clean_file_path(file_path)
          return nil unless file_path

          # Extract path relative to package (strip temp directory)
          # Transform: /var/folders/.../T/package.../schemas/file.xsd
          # To: schemas/file.xsd
          if file_path.include?("/schemas/")
            parts = file_path.split("/schemas/")
            "schemas/#{parts.last}"
          else
            File.basename(file_path)
          end
        end

        # Get schemas from repository
        #
        # @return [Hash] Hash of file_path => schema
        def get_schemas
          if repository.respond_to?(:all_schemas)
            repository.all_schemas
          elsif repository.respond_to?(:schemas)
            # Fallback for other repository types
            repository.schemas
          else
            {}
          end
        end

        # Index building methods (can be overridden)

        def build_id_index
          {}
        end

        def build_name_index
          {}
        end

        def build_type_index
          {}
        end

        # Generate XML instance representation for a component
        #
        # @param component [Element, ComplexType, SimpleType] Component to generate instance for
        # @return [String, nil] XML instance representation
        def generate_instance_xml(component)
          return nil unless component

          # Get the schema that contains this component
          schema = find_schema_for_component(component)
          return nil unless schema

          generator = XmlInstanceGenerator.new(
            schema,
            component,
            repository,
            all_schemas: get_schemas
          )
          generator.generate
        rescue => e
          # Fallback if generation fails - return nil to skip display
          warn "Failed to generate instance XML: #{e.message}" if config[:verbose]
          nil
        end

        # Find the schema that contains a given component
        #
        # @param component [Object] Component to find schema for
        # @return [Schema, nil] Schema containing the component
        def find_schema_for_component(component)
          # Search through all schemas to find the one containing this component
          get_schemas.each do |_path, schema|
            # Check if component is in this schema's elements
            if schema.respond_to?(:element) && schema.element&.include?(component)
              return schema
            end

            # Check if component is in this schema's complex types
            if schema.respond_to?(:complex_type) && schema.complex_type&.include?(component)
              return schema
            end

            # Check if component is in this schema's simple types
            if schema.respond_to?(:simple_type) && schema.simple_type&.include?(component)
              return schema
            end
          end

          # If not found, return first schema as fallback
          _path, schema = get_schemas.first
          schema
        end

        # Generate SVG diagram for a component
        #
        # @param component_data [Hash] Serialized component data
        # @param component_type [Symbol] Component type (:element or :type)
        # @return [String, nil] SVG diagram markup
        def generate_diagram(component_data, component_type)
          generator = Svg::DiagramGenerator.new(schema_name)

          case component_type
          when :element
            generator.generate_element_diagram(component_data)
          when :type
            generator.generate_type_diagram(component_data)
          else
            nil
          end
        rescue StandardError => e
          # Graceful failure - diagram generation should not break serialization
          warn "Warning: Failed to generate SVG diagram: #{e.message}" if ENV['DEBUG']
          nil
        end

        # Get current schema name for SVG generation
        #
        # @return [String] Schema name
        def get_current_schema_name
          # Try to get from current schema being serialized
          if @current_schema_name
            return @current_schema_name
          end

          # Fallback to first schema name
          file_path, schema = get_schemas.first
          schema_name(schema, file_path)
        end
      end
    end
  end
end