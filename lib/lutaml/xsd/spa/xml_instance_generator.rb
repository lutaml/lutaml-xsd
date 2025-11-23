# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      # Generates XML instance representations showing how to use XSD components
      # Based on xs3p's SampleInstanceTable templates
      class XmlInstanceGenerator
        attr_reader :schema, :component, :repository

        def initialize(schema, component, repository = nil, all_schemas: nil)
          @schema = schema
          @component = component
          @repository = repository
          @all_schemas = all_schemas || {}
          @visited_types = []
        end

        # Generate instance representation
        def generate
          case @component
          when Element
            generate_element_instance(@component)
          when ComplexType
            generate_type_instance(@component)
          when SimpleType
            generate_simple_type_instance(@component)
          else
            '<!-- Unknown component type -->'
          end
        end

        private

        # Generate element instance with attributes and content
        def generate_element_instance(element, indent: 0)
          lines = []
          indent_str = '  ' * indent

          # Build opening tag with all attributes on one line
          tag_name = element.name
          schema_id = get_schema_id_for_element(element)
          link_marker = schema_id ? " data-element-link=\"#{schema_id}/elements/#{tag_name}\"" : ''

          # Collect attributes
          attr_parts = []
          if element.type
            type = find_type(element.type)
            if type
              attrs = collect_attributes(type)
              attrs.each do |attr|
                attr_name = resolve_attribute_name(attr)
                next unless attr_name

                occurs = attribute_occurs(attr)
                default_val = attr.fixed || attr.default
                attr_type = attr.type || 'string'
                type_link = get_type_link_marker(attr_type)

                attr_parts << if default_val
                                "#{attr_name}=\"#{default_val}\" #{occurs}"
                              else
                                "#{attr_name}=\"#{attr_type}#{type_link}\" #{occurs}"
                              end
              end
            end
          end

          # Build complete opening tag
          if attr_parts.any?
            lines << "#{indent_str}<#{tag_name}#{link_marker}"
            attr_parts.each do |attr_part|
              lines << "#{indent_str} #{attr_part}"
            end
            lines << "#{indent_str}>"
          else
            lines << "#{indent_str}<#{tag_name}#{link_marker}>"
          end

          # Generate content from type
          if element.type
            type = find_type(element.type)
            if type
              content = generate_type_content(type, indent + 1)
              lines.concat(content) if content.any?
            end
          elsif element.complex_type
            # Inline complex type
            content = generate_type_content(element.complex_type, indent + 1)
            lines.concat(content) if content.any?
          elsif element.simple_type
            # Inline simple type
            lines << "#{indent_str}  #{extract_simple_constraints(element.simple_type)}"
          else
            lines << "#{indent_str}  ..."
          end

          # End tag without link marker (only opening tag needs it)
          occurs = element_occurs(element)
          lines << "#{indent_str}</#{tag_name}> #{occurs}"

          lines.join("\n")
        end

        # Generate type instance content
        def generate_type_instance(type, indent: 0)
          lines = []

          # Show type structure
          content = generate_type_content(type, indent)
          lines.concat(content) if content.any?

          lines.join("\n")
        end

        # Generate content for a type
        def generate_type_content(type, indent)
          lines = []
          indent_str = '  ' * indent

          return lines if @visited_types.include?(type.object_id)

          @visited_types << type.object_id

          # Handle sequence (only if not handling via complex_content)
          if type.respond_to?(:sequence) && type.sequence && !has_complex_content?(type)
            seq = type.sequence
            occurs = model_group_occurs(seq)
            lines << "#{indent_str}Start Sequence #{occurs}"

            seq.element.each do |elem|
              elem_occurs = element_occurs(elem)
              elem_name = resolve_element_name(elem)
              next unless elem_name

              # Resolve which schema this element belongs to and get display name with prefix
              elem_info = resolve_element_schema(elem_name)
              display_name = get_display_name_with_prefix(elem_info)
              elem_link = get_element_link_marker(elem_name)
              lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
            end

            lines << "#{indent_str}End Sequence"
          end

          # Handle choice
          if type.respond_to?(:choice) && type.choice
            choice = type.choice
            occurs = model_group_occurs(choice)
            lines << "#{indent_str}Start Choice #{occurs}"

            choice.element.each do |elem|
              elem_occurs = element_occurs(elem)
              elem_name = resolve_element_name(elem)
              next unless elem_name

              elem_info = resolve_element_schema(elem_name)
              display_name = get_display_name_with_prefix(elem_info)
              elem_link = get_element_link_marker(elem_name)
              lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
            end

            lines << "#{indent_str}End Choice"
          end

          # Handle all
          if type.respond_to?(:all) && type.all
            all_group = type.all
            occurs = model_group_occurs(all_group)
            lines << "#{indent_str}Start All #{occurs}"

            all_group.element.each do |elem|
              elem_occurs = element_occurs(elem)
              elem_name = resolve_element_name(elem)
              next unless elem_name

              elem_info = resolve_element_schema(elem_name)
              display_name = get_display_name_with_prefix(elem_info)
              elem_link = get_element_link_marker(elem_name)
              lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
            end

            lines << "#{indent_str}End All"
          end

          # Handle complex content (extension/restriction)
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              # Process extension with its base - combine into single sequence
              lines.concat(generate_extension_content(cc.extension, indent))
            elsif cc.respond_to?(:restriction) && cc.restriction
              # For restrictions, show the restricted content
              if cc.restriction.sequence || cc.restriction.choice || cc.restriction.all
                # Show restricted content model
                lines.concat(generate_type_content(cc.restriction, indent))
              else
                # If no content model in restriction, show base type
                base_type = find_type(cc.restriction.base) if cc.restriction.base
                if base_type
                  base_content = generate_type_content(base_type, indent)
                  lines.concat(base_content) if base_content.any?
                end
              end
            end
          end

          # Handle simple content
          if type.respond_to?(:simple_content) && type.simple_content
            sc = type.simple_content
            constraints = extract_simple_constraints(sc)
            lines << "#{indent_str}#{constraints}" if constraints
          end

          @visited_types.pop
          lines
        end

        # Generate simple type instance
        def generate_simple_type_instance(simple_type, _indent: 0)
          extract_simple_constraints(simple_type)
        end

        # Extract simple type constraints
        def extract_simple_constraints(simple_content)
          return 'string' unless simple_content

          if simple_content.respond_to?(:restriction) && simple_content.restriction
            restriction = simple_content.restriction
            base = restriction.base || 'string'

            # Check for enumerations
            if restriction.respond_to?(:enumeration) && restriction.enumeration&.any?
              enums = restriction.enumeration.map(&:value).join(' | ')
              return "(#{enums})"
            end

            # Check for patterns
            if restriction.respond_to?(:pattern) && restriction.pattern&.any?
              pattern = restriction.pattern.first
              return "pattern: #{pattern.value}" if pattern.respond_to?(:value)
            end

            # Check for length constraints
            constraints = []
            constraints << "minLength: #{restriction.min_length.first.value}" if restriction.respond_to?(:min_length) && restriction.min_length&.any?
            constraints << "maxLength: #{restriction.max_length.first.value}" if restriction.respond_to?(:max_length) && restriction.max_length&.any?

            return "#{base} (#{constraints.join(', ')})" if constraints.any?

            base
          elsif simple_content.respond_to?(:extension) && simple_content.extension
            simple_content.extension.base || 'string'
          else
            'string'
          end
        end

        # Calculate element occurrence notation
        def element_occurs(element)
          min = element.min_occurs || '1'
          max = element.max_occurs == 'unbounded' ? '*' : (element.max_occurs || '1')
          "[#{min}..#{max}]"
        end

        # Calculate attribute occurrence notation
        def attribute_occurs(attr)
          use = attr.use || 'optional'
          use == 'required' ? '[1]' : '[0..1]'
        end

        # Calculate model group occurrence notation
        def model_group_occurs(group)
          return '[1]' unless group

          min = group.min_occurs || '1'
          max = group.max_occurs == 'unbounded' ? '*' : (group.max_occurs || '1')
          "[#{min}..#{max}]"
        end

        # Check if type has complex_content
        def has_complex_content?(type)
          type.respond_to?(:complex_content) && type.complex_content
        end

        # Resolve element name from element (handles ref attribute)
        def resolve_element_name(elem)
          return elem.name if elem.name

          # Element uses ref - extract the local name from the ref
          return unless elem.ref

          elem.ref.split(':').last
        end

        # Resolve attribute name from attribute (handles ref attribute)
        def resolve_attribute_name(attr)
          return attr.name if attr.name

          # Attribute uses ref - extract the local name from the ref
          return unless attr.ref

          attr.ref.split(':').last
        end

        # Collect all attributes from a type (including inherited)
        def collect_attributes(type, visited = [])
          return [] if visited.include?(type.object_id)

          visited << type.object_id

          attrs = []

          # Direct attributes
          attrs.concat(type.attribute) if type.respond_to?(:attribute) && type.attribute

          # Attributes from complex content extension
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              # Add attributes from extension
              attrs.concat(cc.extension.attribute) if cc.extension.respond_to?(:attribute) && cc.extension.attribute

              # Recursively get base type attributes
              if cc.extension.base
                base_type = find_type(cc.extension.base)
                attrs.concat(collect_attributes(base_type, visited)) if base_type
              end
            elsif cc.respond_to?(:restriction) && cc.restriction
              attrs.concat(cc.restriction.attribute) if cc.restriction.respond_to?(:attribute) && cc.restriction.attribute
            end
          end

          # Attributes from simple content extension
          if type.respond_to?(:simple_content) && type.simple_content
            sc = type.simple_content
            if sc.respond_to?(:extension) && sc.extension
              attrs.concat(sc.extension.attribute) if sc.extension.respond_to?(:attribute) && sc.extension.attribute
            elsif sc.respond_to?(:restriction) && sc.restriction
              attrs.concat(sc.restriction.attribute) if sc.restriction.respond_to?(:attribute) && sc.restriction.attribute
            end
          end

          attrs.uniq(&:name)
        end

        # Find a type by name in the schema
        def find_type(type_name)
          return nil unless type_name

          # Strip namespace prefix
          local_name = type_name.split(':').last

          # Search in current schema
          if @schema.respond_to?(:complex_type) && @schema.complex_type
            found = @schema.complex_type.find { |t| t.name == local_name }
            return found if found
          end

          if @schema.respond_to?(:simple_type) && @schema.simple_type
            found = @schema.simple_type.find { |t| t.name == local_name }
            return found if found
          end

          # Search in repository if available
          if @repository
            # Try to find type in all schemas
            all_schemas = @repository.respond_to?(:all_schemas) ? @repository.all_schemas : {}
            all_schemas.each_value do |schema|
              if schema.respond_to?(:complex_type) && schema.complex_type
                found = schema.complex_type.find { |t| t.name == local_name }
                return found if found
              end

              if schema.respond_to?(:simple_type) && schema.simple_type
                found = schema.simple_type.find { |t| t.name == local_name }
                return found if found
              end
            end
          end

          nil
        end

        # Generate content for an extension (combining base and extension elements)
        def generate_extension_content(extension, indent)
          lines = []
          indent_str = '  ' * indent

          # Collect all elements from base type and extension into a single sequence
          all_elements = []

          # Get base type elements first
          if extension.base
            base_type = find_type(extension.base)
            all_elements.concat(collect_type_elements(base_type)) if base_type
          end

          # Then add extension elements
          if extension.respond_to?(:sequence) && extension.sequence
            all_elements.concat(extension.sequence.element) if extension.sequence.element
          elsif extension.respond_to?(:choice) && extension.choice
            # Handle choice in extension
            return generate_choice_content(extension.choice, indent)
          elsif extension.respond_to?(:all) && extension.all
            # Handle all in extension
            return generate_all_content(extension.all, indent)
          end

          # Display as a single combined sequence if we have elements
          if all_elements.any?
            occurs = '[1..1]' # Extension sequences are typically required
            lines << "#{indent_str}Start Sequence #{occurs}"

            all_elements.each do |elem|
              elem_occurs = element_occurs(elem)
              elem_name = resolve_element_name(elem)
              next unless elem_name

              elem_info = resolve_element_schema(elem_name)
              display_name = get_display_name_with_prefix(elem_info)
              elem_link = get_element_link_marker(elem_name)
              lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
            end

            lines << "#{indent_str}End Sequence"
          end

          lines
        end

        # Collect all elements from a type recursively
        def collect_type_elements(type, visited = [])
          return [] if visited.include?(type.object_id)

          visited << type.object_id

          elements = []

          # Direct sequence elements
          elements.concat(type.sequence.element) if type.respond_to?(:sequence) && type.sequence&.element

          # Elements from complex content extension
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              # Get base type elements
              if cc.extension.base
                base_type = find_type(cc.extension.base)
                elements.concat(collect_type_elements(base_type, visited)) if base_type
              end

              # Get extension sequence elements
              elements.concat(cc.extension.sequence.element) if cc.extension.respond_to?(:sequence) && cc.extension.sequence&.element
            end
          end

          elements
        end

        # Generate choice content
        def generate_choice_content(choice, indent)
          lines = []
          indent_str = '  ' * indent

          occurs = model_group_occurs(choice)
          lines << "#{indent_str}Start Choice #{occurs}"

          choice.element.each do |elem|
            elem_occurs = element_occurs(elem)
            elem_name = resolve_element_name(elem)
            next unless elem_name

            elem_info = resolve_element_schema(elem_name)
            display_name = get_display_name_with_prefix(elem_info)
            elem_link = get_element_link_marker(elem_name)
            lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
          end

          lines << "#{indent_str}End Choice"
          lines
        end

        # Generate all content
        def generate_all_content(all_group, indent)
          lines = []
          indent_str = '  ' * indent

          occurs = model_group_occurs(all_group)
          lines << "#{indent_str}Start All #{occurs}"

          all_group.element.each do |elem|
            elem_occurs = element_occurs(elem)
            elem_name = resolve_element_name(elem)
            next unless elem_name

            elem_info = resolve_element_schema(elem_name)
            display_name = get_display_name_with_prefix(elem_info)
            elem_link = get_element_link_marker(elem_name)
            lines << "#{indent_str}  <#{display_name}#{elem_link}> ... </#{display_name}#{elem_link}> #{elem_occurs}"
          end

          lines << "#{indent_str}End All"
          lines
        end

        # Get schema ID for an element (for linking)
        def get_schema_id_for_element(_element)
          # Try to find which schema this element belongs to
          return nil unless @schema

          # Use schema's target namespace or filename to create schema ID
          return unless @schema.respond_to?(:target_namespace) && @schema.target_namespace

          # Extract last part of namespace as schema ID
          uri = @schema.target_namespace
          uri.split('/').last || uri.split(':').last
        end

        # Get link marker for an element with cross-schema support
        def get_element_link_marker(elem_name)
          # Resolve which schema defines this element
          elem_info = resolve_element_schema(elem_name)

          # Strip namespace prefix for link
          local_name = elem_info[:name]
          schema_id = elem_info[:schema_id]

          " data-element-ref=\"#{local_name}\" data-element-schema=\"#{schema_id}\""
        end

        # Resolve which schema defines an element
        def resolve_element_schema(elem_name)
          # Parse the element name - might have namespace prefix
          if elem_name.include?(':')
            prefix, local_name = elem_name.split(':', 2)

            # Find schema with this namespace prefix
            target_schema = find_schema_by_prefix(prefix)

            if target_schema
              return {
                schema: target_schema,
                schema_id: get_schema_id(target_schema),
                prefix: prefix,
                name: local_name
              }
            end
          end

          # Element in same schema (no prefix or prefix not found)
          local_name = elem_name.split(':').last
          {
            schema: @schema,
            schema_id: get_schema_id(@schema),
            prefix: nil,
            name: local_name
          }
        end

        # Find schema by namespace prefix
        def find_schema_by_prefix(prefix)
          return nil unless @all_schemas

          # Common namespace mappings
          namespace_uris = {
            'uro' => 'https://www.geospatial.jp/iur/uro/3.2',
            'urf' => 'https://www.geospatial.jp/iur/urf/3.2',
            'gml' => 'http://www.opengis.net/gml/3.2',
            'xlink' => 'http://www.w3.org/1999/xlink',
            'gco' => 'http://www.isotc211.org/2005/gco'
          }

          namespace_uri = namespace_uris[prefix]
          return nil unless namespace_uri

          # Search all_schemas for one with matching target_namespace
          @all_schemas.each_value do |schema|
            if schema.respond_to?(:target_namespace) &&
               schema.target_namespace == namespace_uri
              return schema
            end
          end

          nil
        end

        # Get schema ID for a schema
        def get_schema_id(schema)
          return 'unnamed' unless schema

          # Use target namespace to derive schema ID
          if schema.respond_to?(:target_namespace) && schema.target_namespace
            uri = schema.target_namespace
            # Extract last part of namespace as schema ID (e.g., "uro/3.2" -> "uro")
            parts = uri.split('/')
            if parts.length >= 2
              name = parts[-2] # Get second-to-last part
              return slugify(name)
            end
            return slugify(parts.last || 'unnamed')
          end

          'unnamed'
        end

        # Slugify helper
        def slugify(name)
          return 'unnamed' unless name

          name.to_s
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
              .gsub(/([a-z\d])([A-Z])/, '\1-\2')
              .downcase
              .gsub(/[^a-z0-9]+/, '-')
              .gsub(/^-|-$/, '')
        end

        # Get display name with namespace prefix if cross-schema
        def get_display_name_with_prefix(elem_info)
          if elem_info[:prefix] && elem_info[:schema_id] != get_schema_id(@schema)
            # Cross-schema element - show with prefix
            "#{elem_info[:prefix]}:#{elem_info[:name]}"
          else
            # Same schema element - no prefix
            elem_info[:name]
          end
        end

        # Get link marker for a type
        def get_type_link_marker(type_name)
          return '' unless type_name

          # Don't link built-in XSD types
          return '' if type_name =~ /^(xs:|xsd:|string|integer|boolean|date|time|anyURI|double|float|decimal)/

          # Strip namespace prefix for link
          local_name = type_name.split(':').last
          " data-type-ref=\"#{local_name}\""
        end
      end
    end
  end
end
