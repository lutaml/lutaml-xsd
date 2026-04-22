# frozen_string_literal: true

require "json"
require "tmpdir"
require "fileutils"
require_relative "xml_instance_generator"
require_relative "utils/extract_enumeration"

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
        include ::Lutaml::Xsd::Spa::Utils::ExtractEnumeration

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
          metadata = build_metadata
          # Convert SpaMetadata model to hash for JSON serialization
          # SpaMetadata.to_hash returns string keys, but we need symbol keys for compatibility
          metadata_hash = if metadata.respond_to?(:to_hash)
                            hash = metadata.to_hash
                            # Convert string keys to symbols for backward compatibility
                            hash.to_h do |k, v|
                              [k.is_a?(String) ? k.to_sym : k, v]
                            end
                          elsif metadata.respond_to?(:to_h)
                            metadata.to_h
                          else
                            metadata
                          end
          {
            metadata: metadata_hash,
            schemas: serialize_schemas,
            namespaces: build_namespaces,
            index: build_index,
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
        # @return [SpaMetadata] SpaMetadata model instance
        def build_metadata
          pkg_meta = @package&.metadata

          # Extract metadata from package (supports both Hash-like and Lutaml::Model objects)
          pkg_hash = if pkg_meta.respond_to?(:to_h)
                       pkg_meta.to_h
                     elsif pkg_meta.respond_to?(:to_hash)
                       pkg_meta.to_hash
                     elsif pkg_meta.is_a?(Hash)
                       pkg_meta
                     else
                       {}
                     end

          title = pkg_hash[:title] || pkg_hash["title"] ||
            pkg_hash[:name] || pkg_hash["name"] ||
            config["title"] || default_title

          SpaMetadata.new(
            generated: current_timestamp,
            generator: generator_info,
            title: title,
            name: pkg_hash[:name] || pkg_hash["name"],
            version: pkg_hash[:version] || pkg_hash["version"],
            description: pkg_hash[:description] || pkg_hash["description"],
            homepage: pkg_hash[:homepage] || pkg_hash["homepage"],
            documentation: pkg_hash[:documentation] || pkg_hash["documentation"],
            license: pkg_hash[:license] || pkg_hash["license"],
            license_url: (pkg_hash[:license_url] || pkg_hash["license_url"]).then do |v|
              v.is_a?(String) && !v.empty? ? v : nil
            end,
            authors: pkg_hash[:authors] || pkg_hash["authors"],
            repository: pkg_hash[:repository] || pkg_hash["repository"],
            tags: pkg_hash[:tags] || pkg_hash["tags"] || [],
            appearance: pkg_hash[:appearance] || pkg_hash["appearance"],
            links: pkg_hash[:links] || pkg_hash["links"],
            schema_count: get_schemas.size,
          )
        end

        # Build a URI => prefix lookup from repository namespace_mappings
        #
        # @return [Hash] Map of namespace URI to registered prefix
        def namespace_prefix_lookup
          return @namespace_prefix_lookup if defined?(@namespace_prefix_lookup) && @namespace_prefix_lookup

          @namespace_prefix_lookup = {}
          if repository.respond_to?(:namespace_mappings) && repository.namespace_mappings
            repository.namespace_mappings.each do |mapping|
              if mapping.uri && mapping.prefix
                @namespace_prefix_lookup[mapping.uri] =
                  mapping.prefix
              end
            end
          end
          @namespace_prefix_lookup
        end

        # Build namespaces section from all schemas
        #
        # @return [Array<Hash>] Array of namespace hashes with prefix, uri, schemas
        def build_namespaces
          ns_map = {}
          get_schemas.each do |file_path, schema|
            next unless schema

            ns = schema.target_namespace
            if ns
              prefix = namespace_prefix_lookup[ns] || derive_prefix(ns, schema)
              ns_map[ns] ||= { prefix: prefix, uri: ns, schemas: [] }
              ns_map[ns][:schemas] << schema_id(nil, schema, file_path)
            else
              ns_map["__default__"] ||= { prefix: "tns", uri: "", schemas: [] }
              ns_map["__default__"][:schemas] << schema_id(nil, schema,
                                                           file_path)
            end
          end
          ns_map.values
        end

        # Derive a short prefix from a namespace URI
        #
        # @param ns [String] Namespace URI
        # @param _schema [Schema] Schema object (unused)
        # @return [String] Derived prefix
        def derive_prefix(ns, _schema)
          return "tns" if ns.nil? || ns.empty?

          # Detect standard XML Schema namespace using parsed URI components
          begin
            uri = URI(ns)
            if uri&.host && %w[w3.org www.w3.org].include?(uri.host) && uri.path&.include?("XMLSchema")
              return "xs"
            end
          rescue URI::InvalidURIError
            # Fall back to other heuristics below if the namespace is not a valid URI
          end

          return "gml" if ns.include?("/gml/")

          # Try to extract a meaningful prefix from the URI path
          # e.g. "http://www.opengis.net/citygml/2.0" => "citygml"
          # e.g. "http://example.com/my-schema" => "myschema"
          host_stripped = ns.sub(%r{^https?://}, "")
          path = host_stripped.sub(%r{^[^/]+}, "")
          segments = path.split("/").reject(&:empty?)
          # Use the last non-numeric segment as prefix
          prefix_segment = segments.reverse.find { |s| !s.match?(/\A[\d.]+\z/) }
          prefix_segment&.gsub(/[^a-zA-Z0-9]/, "")&.downcase || "tns"
        end

        # Serialize all schemas (template method hook)
        #
        # @return [Array<Hash>] Array of serialized schemas
        def serialize_schemas
          schemas_data = get_schemas.map.with_index do |(file_path, schema), index|
            serialize_schema(schema, index, file_path)
          end.compact

          # Post-process: add used_by reverse references
          attach_used_by_references(schemas_data)

          schemas_data
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
          return nil unless schema

          schema_source = if file_path
            begin
              File.read(file_path)
            rescue StandardError
              nil
            end
          end

          prefix = namespace_prefix_lookup[schema.target_namespace] || derive_prefix(
            schema.target_namespace, schema
          )
          {
            id: schema_id(index, schema, file_path),
            name: schema_name(schema, file_path),
            prefix: prefix,
            namespace: schema.target_namespace,
            file_path: clean_file_path(file_path),
            is_entrypoint: is_entrypoint?(file_path),
            elements: serialize_elements(
              schema, prefix, schema_source, file_path),
            complex_types: serialize_complex_types(
              schema, prefix, schema_source, file_path),
            simple_types: serialize_simple_types(schema, prefix),
            attributes: serialize_attributes(schema, prefix),
            groups: serialize_groups(schema, prefix),
            attribute_groups: serialize_attribute_groups(
              schema, prefix, schema_source),
            imports: serialize_imports(schema),
            includes: serialize_includes(schema),
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
            by_type: build_type_index,
          }
        end

        # Serialize elements from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @param file_path [String, nil] Optional schema file path
        # @return [Array<Hash>] Serialized elements (sorted alphabetically by name)
        def serialize_elements(schema,
          prefix = nil, schema_source = nil, file_path = nil)
          return [] unless schema.respond_to?(:elements) || schema.respond_to?(:element)

          elements = schema.respond_to?(:elements) ? schema.elements : schema.element
          elements.map.with_index do |element, index|
            serialize_element(element, index, prefix, schema_source, file_path)
          end.sort_by { |e| e[:name] || "" }
        end

        # Serialize single element
        #
        # @param element [Element] Element object
        # @param index [Integer] Element index
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @param file_path [String, nil] Optional schema file path
        # @return [Hash] Serialized element
        def serialize_element(element, index,
          prefix = nil, schema_source = nil, file_path = nil)
          element_data = {
            id: element_id(index, element, prefix),
            name: element.name,
            type: element.type,
            min_occurs: element.min_occurs,
            max_occurs: element.max_occurs,
            occurs: {
              min: element.min_occurs || 1,
              max: element.max_occurs || 1,
            },
            documentation: extract_documentation(element),
            instance_xml: generate_instance_xml(element),
            source: extract_source_by_type_key_value(
              "element", "name", element.name, prefix, schema_source),
          }

          # Enriched fields
          if element.respond_to?(:ref) && element.ref
            element_data[:ref] =
              element.ref
          end
          if element.respond_to?(:nillable) && element.nillable
            element_data[:nillable] =
              element.nillable
          end
          if element.respond_to?(:abstract) && element.abstract
            element_data[:abstract] =
              element.abstract
          end
          if element.respond_to?(:substitution_group) && element.substitution_group
            element_data[:substitution_group] = element.substitution_group
          end
          if element.respond_to?(:default) && element.default
            element_data[:default] =
              element.default
          end
          if element.respond_to?(:fixed) && element.fixed
            element_data[:fixed] =
              element.fixed
          end

          # Add SVG diagram
          element_data[:diagram_svg] = generate_diagram(element_data, :element, file_path)

          element_data
        end

        def gen_element_diagram(name, file_path)
          if !file_path || !File.exist?(file_path)
            warn "xsdvi: XSD file '#{file_path}' not found" if config[:verbose]
            return nil
          end

          output_folder = Dir.mktmpdir("xsdvi-")

          # generate diagram using xsdvi command line tool
          `bundle exec xsdvi generate #{file_path} -r #{name} -o -p #{output_folder}`

          svg_file = File.join(output_folder, "#{name}.svg")
          unless File.exist?(svg_file)
            warn "xsdvi: SVG not generated for '#{name}'" if config[:verbose]
            return nil
          end

          # read generated SVG content
          svg_content = File.read(svg_file)

          # Strip XML declaration and DOCTYPE for embedding in HTML
          svg_content = svg_content
            .gsub(/<\?xml[^?]*\?>\s*/i, "")
            .gsub(/<!DOCTYPE[^>]*>\s*/i, "")
            .gsub(/<title>.*?<\/title>/i, "") # Remove title element if present
            .gsub(/<script[^>]*>.*?<\/script>/im, "") # Remove any script
            .gsub(/<a[^>]*>(.*?)<\/a>/im, '\1') # Remove links but keep content

          svg_content
        ensure
          FileUtils.rm_rf(output_folder) if output_folder
        end

        # Serialize complex types from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @return [Array<Hash>] Serialized complex types (sorted alphabetically by name)
        def serialize_complex_types(schema, prefix = nil, schema_source = nil, file_path = nil)
          return [] unless schema.respond_to?(:complex_types) || schema.respond_to?(:complex_type)

          types = schema.respond_to?(:complex_types) ? schema.complex_types : schema.complex_type
          types.map.with_index do |type, index|
            serialize_complex_type(
              type, index, prefix, schema_source, file_path)
          end.sort_by { |t| t[:name] || "" }
        end

        # Serialize single complex type
        #
        # @param type [ComplexType] Complex type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized complex type
        def serialize_complex_type(type, index, prefix = nil, schema_source = nil, file_path = nil)
          content_model = extract_content_model(type)
          type_data = {
            id: complex_type_id(index, type, prefix),
            name: type.name,
            base: extract_base_type(type),
            content_model: content_model,
            abstract: type.respond_to?(:abstract) ? type.abstract : false,
            mixed: type.respond_to?(:mixed) ? type.mixed : false,
            attributes: serialize_type_attributes(type),
            elements: serialize_type_elements(type),
            groups: serialize_type_group_refs(type),
            attribute_groups: serialize_type_attr_groups(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type),
            source: extract_source_by_type_key_value(
                "complexType", "name", type.name, prefix, schema_source),
          }

          # Collect attributes from inside extension for simpleContent/complexContent
          extension_attrs = collect_extension_attributes(type)
          type_data[:extension_attributes] = extension_attrs unless extension_attrs.empty?

          # Add SVG diagram
          type_data[:diagram_svg] = generate_diagram(type_data, :type, file_path)

          type_data
        end

        # Collect attributes from inside extension element
        #
        # @param type [ComplexType] Complex type object
        # @return [Array<Hash>] Serialized extension attributes
        def collect_extension_attributes(type)
          attrs = []

          # Check simpleContent.extension
          if type.respond_to?(:simple_content) && type.simple_content
            sc = type.simple_content
            if sc.respond_to?(:extension) && sc.extension
              ext = sc.extension
              attrs.concat(collect_from_extension(ext))
            end
          end

          # Check complexContent.extension
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              ext = cc.extension
              attrs.concat(collect_from_extension(ext))
            end
          end

          attrs
        end

        # Collect attributes from an extension element
        #
        # @param extension [Object] Extension object
        # @return [Array<Hash>] Serialized attributes
        def collect_from_extension(extension)
          attrs = []

          # Direct attributes
          if extension.respond_to?(:attribute) && extension.attribute
            direct_attrs = extension.attribute.is_a?(Array) ? extension.attribute : [extension.attribute]
            direct_attrs.each do |attr|
              attr_name = if attr.respond_to?(:name) && attr.name
                            attr.name
                          else
                            (attr.respond_to?(:ref) ? attr.ref : nil)
                          end
              attrs << {
                name: attr_name,
                ref: attr.respond_to?(:ref) ? attr.ref : nil,
                type: attr.respond_to?(:type) ? attr.type : nil,
                use: attr.respond_to?(:use) ? attr.use : nil,
              }
            end
          end

          # Attribute groups
          if extension.respond_to?(:attribute_group) && extension.attribute_group
            ext_groups = extension.attribute_group.is_a?(Array) ? extension.attribute_group : [extension.attribute_group]
            ext_groups.each do |ag|
              ag_name = if ag.respond_to?(:ref)
                          ag.ref
                        else
                          (ag.respond_to?(:name) ? ag.name : nil)
                        end
              if ag_name
                # Look up attributes from the attribute group definition
                looked_up_attrs = lookup_attribute_group_attributes(ag_name)
                looked_up_attrs.each do |looked_attr|
                  attrs << looked_attr.merge({ attribute_group_ref: ag_name })
                end
              end
            end
          end

          attrs
        end

        # Serialize simple types from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @return [Array<Hash>] Serialized simple types (sorted alphabetically by name)
        def serialize_simple_types(schema, prefix = nil)
          return [] unless schema.respond_to?(:simple_types) || schema.respond_to?(:simple_type)

          types = schema.respond_to?(:simple_types) ? schema.simple_types : schema.simple_type
          types.map.with_index do |type, index|
            serialize_simple_type(type, index, prefix)
          end.sort_by { |t| t[:name] || "" }
        end

        # Serialize single simple type
        #
        # @param type [SimpleType] Simple type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized simple type
        def serialize_simple_type(type, index, prefix = nil)
          {
            id: simple_type_id(index, type, prefix),
            name: type.name,
            base: extract_simple_base(type),
            restriction: serialize_restriction(type),
            union: extract_union_members(type),
            list: extract_list_type(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type),
          }
        end

        # Serialize attributes from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized attributes
        def serialize_attributes(schema, prefix = nil)
          return [] unless schema.respond_to?(:attributes) || schema.respond_to?(:attribute)

          attrs = schema.respond_to?(:attributes) ? schema.attributes : schema.attribute
          attrs.map.with_index do |attr, index|
            serialize_attribute(attr, index, prefix)
          end
        end

        # Serialize single attribute
        #
        # @param attr [Attribute] Attribute object
        # @param index [Integer] Attribute index
        # @return [Hash] Serialized attribute
        def serialize_attribute(attr, index, prefix = nil)
          {
            id: attribute_id(index, attr, prefix),
            name: attr.name,
            type: attr.type,
            use: attr.use,
            default: attr.default,
            documentation: extract_documentation(attr),
          }
        end

        # Serialize groups from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized groups
        def serialize_groups(schema, prefix = nil)
          return [] unless schema.respond_to?(:groups) || schema.respond_to?(:group)

          grps = schema.respond_to?(:groups) ? schema.groups : schema.group
          grps.map.with_index do |group, index|
            serialize_group(group, index, prefix)
          end
        end

        # Serialize single group
        #
        # @param group [Group] Group object
        # @param index [Integer] Group index
        # @return [Hash] Serialized group
        def serialize_group(group, index, prefix = nil)
          {
            id: group_id(index, group, prefix),
            name: group.name,
            elements: serialize_group_elements(group),
            attributes: serialize_group_attributes(group),
            documentation: extract_documentation(group),
          }
        end

        # Serialize attribute groups from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @return [Array<Hash>] Serialized attribute groups (sorted alphabetically by name)
        def serialize_attribute_groups(schema, prefix = nil, schema_source = nil)
          groups = if schema.respond_to?(:attribute_groups)
                     schema.attribute_groups
                   elsif schema.respond_to?(:attribute_group)
                     schema.attribute_group
                   else
                     []
                   end
          return [] if groups.nil? || groups.empty?

          groups.map do |ag|
            id_prefix = prefix ? "attrgroup-#{prefix}-" : "attrgroup-"
            {
              id: "#{id_prefix}#{slugify(ag.name)}",
              name: ag.name,
              attributes: serialize_ag_attributes(ag),
              documentation: extract_documentation(ag),
              source: extract_source_by_type_key_value(
                "attributeGroup", "name", ag.name, prefix, schema_source),
              instance_xml: generate_instance_xml(ag),
            }
          end.sort_by { |ag| ag[:name] || "" }
        end

        # Extract source information for an attribute group
        # from the schema
        def extract_source_by_type_key_value(type, key, value, prefix = nil, source = nil)
          return nil unless source && value

          # parse the schema source and find the attribute group by name
          begin
            doc = Nokogiri::XML(source, &:noblanks)
            xpath = if prefix
                      "//#{prefix}:#{type}[@#{key}='#{value}']"
                    else
                      "//#{type}[@#{key}='#{value}']"
                    end
            ag_node = doc.at_xpath(xpath)
            ag_node&.to_xml(indent: 2)
          rescue StandardError
            # If parsing fails, return nil
            nil
          end
        end

        # Serialize attributes from an attribute group
        #
        # @param ag [AttributeGroup] Attribute group
        # @return [Array<Hash>] Serialized attributes
        def serialize_ag_attributes(ag)
          return [] unless ag.respond_to?(:attribute) && ag.attribute

          ag.attribute.map do |attr|
            # Check for inline simpleType with enumeration
            enum_default, enum_type = extract_enumeration_default(attr)
            {
              name: attr.name || "#{attr.ref} (ref)",
              type: enum_type || attr.type,
              use: attr.respond_to?(:use) ? attr.use : nil,
              default: enum_default || (attr.respond_to?(:default) ? attr.default : nil),
              fixed: attr.respond_to?(:fixed) ? attr.fixed : nil,
              documentation: extract_documentation(attr),
            }
          end
        end

        # Serialize imports from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized imports
        def serialize_imports(schema)
          return [] unless schema.respond_to?(:imports) && schema.imports

          schema.imports.filter_map do |imp|
            {
              namespace: imp.respond_to?(:namespace) ? imp.namespace : nil,
              schema_location: if imp.respond_to?(:schema_path)
                                 imp.schema_path
                               elsif imp.respond_to?(:schema_location)
                                 imp.schema_location
                               end,
            }
          end
        end

        # Serialize includes from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized includes
        def serialize_includes(schema)
          return [] unless schema.respond_to?(:includes) && schema.includes

          schema.includes.filter_map do |inc|
            {
              schema_location: if inc.respond_to?(:schema_path)
                                 inc.schema_path
                               elsif inc.respond_to?(:schema_location)
                                 inc.schema_location
                               end,
            }
          end
        end

        # Serialize elements within a group
        #
        # @param group [Group] Group object
        # @return [Array<Hash>] Serialized elements
        def serialize_group_elements(group)
          elements = []
          if group.respond_to?(:elements) && group.elements
            elements = group.elements.map do |elem|
              {
                name: elem.name,
                type: elem.type,
                min_occurs: elem.min_occurs,
                max_occurs: elem.max_occurs,
                occurs: {
                  min: elem.min_occurs || 1,
                  max: elem.max_occurs || 1,
                },
                reference: elem.respond_to?(:ref) ? elem.ref : nil,
                documentation: extract_documentation(elem),
              }
            end
          end
          elements
        end

        # Serialize attributes within a group
        #
        # @param group [Group] Group object
        # @return [Array<Hash>] Serialized attributes
        def serialize_group_attributes(group)
          attrs = []
          if group.respond_to?(:attributes) && group.attributes
            attrs = group.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
                use: attr.respond_to?(:use) ? attr.use : nil,
                default: attr.respond_to?(:default) ? attr.default : nil,
                fixed: attr.respond_to?(:fixed) ? attr.fixed : nil,
                documentation: extract_documentation(attr),
              }
            end
          end
          attrs
        end

        # Serialize group references from a complex type
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized group references
        def serialize_type_group_refs(type)
          return [] unless type.respond_to?(:group) && type.group

          groups = type.group.is_a?(Array) ? type.group : [type.group]
          groups.filter_map do |g|
            {
              ref: g.respond_to?(:ref) ? g.ref : g.name,
              min_occurs: g.respond_to?(:min_occurs) ? g.min_occurs : nil,
              max_occurs: g.respond_to?(:max_occurs) ? g.max_occurs : nil,
            }
          end
        end

        # Serialize attribute group references from a complex type
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized attribute group references with attributes
        def serialize_type_attr_groups(type)
          # Collect attribute group refs from all three possible locations:
          # 1. Direct attribute groups on the type
          # 2. Inside simpleContent.extension
          # 3. Inside complexContent.extension
          all_ag_refs = []

          # 1. Direct attribute groups
          if type.respond_to?(:attribute_group) && type.attribute_group
            direct_groups = type.attribute_group.is_a?(Array) ? type.attribute_group : [type.attribute_group]
            all_ag_refs.concat(direct_groups)
          end

          # 2. Attribute groups inside simpleContent.extension
          if type.respond_to?(:simple_content) && type.simple_content
            sc = type.simple_content
            if sc.respond_to?(:extension) && sc.extension
              extension = sc.extension
              if extension.respond_to?(:attribute_group) && extension.attribute_group
                ext_groups = extension.attribute_group.is_a?(Array) ? extension.attribute_group : [extension.attribute_group]
                all_ag_refs.concat(ext_groups)
              end
            end
          end

          # 3. Attribute groups inside complexContent.extension
          if type.respond_to?(:complex_content) && type.complex_content
            cc = type.complex_content
            if cc.respond_to?(:extension) && cc.extension
              extension = cc.extension
              if extension.respond_to?(:attribute_group) && extension.attribute_group
                ext_groups = extension.attribute_group.is_a?(Array) ? extension.attribute_group : [extension.attribute_group]
                all_ag_refs.concat(ext_groups)
              end
            end
          end

          return [] if all_ag_refs.empty?

          all_ag_refs.filter_map do |ag|
            ag_name = ag.respond_to?(:ref) ? ag.ref : ag.name
            next unless ag_name

            # Look up the actual attribute group definition to get its attributes
            attrs = lookup_attribute_group_attributes(ag_name)
            {
              ref: ag_name,
              attributes: attrs,
            }
          end
        end

        # Look up attributes from an attribute group definition
        #
        # @param ag_name [String] Attribute group name
        # @return [Array<Hash>] Serialized attributes
        def lookup_attribute_group_attributes(ag_name)
          clean_name = ag_name.split(":").last
          get_schemas.each_value do |schema|
            next unless schema.respond_to?(:attribute_group) && schema.attribute_group

            found_ag = schema.attribute_group.find do |group|
              [clean_name, ag_name].include?(group.name)
            end
            if found_ag&.attribute
              return serialize_ag_attributes(found_ag)
            end
          end
          []
        end

        # Extract union member types from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [Array<String>, nil] Union member type names
        def extract_union_members(type)
          return nil unless type.respond_to?(:union) && type.union

          union = type.union
          if union.respond_to?(:member_types) && union.member_types
            union.member_types.is_a?(String) ? union.member_types.split : union.member_types
          elsif union.respond_to?(:simple_types) && union.simple_types
            union.simple_types.filter_map(&:name)
          end
        end

        # Extract list item type from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [String, nil] List item type name
        def extract_list_type(type)
          return nil unless type.respond_to?(:list) && type.list

          list = type.list
          list.item_type if list.respond_to?(:item_type)
        end

        # Build used_by reverse references across all schemas
        #
        # @param schemas_data [Array<Hash>] Serialized schema data
        # @return [void]
        def attach_used_by_references(schemas_data)
          used_by = build_used_by_index(schemas_data)
          schemas_data.each do |schema_data|
            (schema_data[:complex_types] || []).each do |type|
              type[:used_by] = used_by[type[:name]] || []
            end
            (schema_data[:simple_types] || []).each do |type|
              type[:used_by] = used_by[type[:name]] || []
            end
            (schema_data[:attribute_groups] || []).each do |ag|
              ag[:used_by] = used_by[ag[:name]] || []
            end
            (schema_data[:elements] || []).each do |elem|
              # Filter out self-references
              elem_name = elem[:name]
              elem[:used_by] = (used_by[elem_name] || []).reject do |ref|
                ref[:name] == elem_name
              end
            end
            (schema_data[:groups] || []).each do |group|
              group[:used_by] = used_by[group[:name]] || []
            end
            (schema_data[:attributes] || []).each do |attr|
              attr[:used_by] = used_by[attr[:name]] || []
            end
          end
        end

        # Build reverse index: type_name => [referencing component names]
        #
        # @param schemas_data [Array<Hash>] Serialized schema data
        # @return [Hash] Map of type_name => array of referencing component hashes
        def build_used_by_index(schemas_data)
          used_by = Hash.new { |h, k| h[k] = [] }

          schemas_data.each do |schema_data| # rubocop:disable Metrics/BlockLength
            schema_label = schema_data[:name] || "unknown"

            # Elements that reference a type
            (schema_data[:elements] || []).each do |elem|
              if elem[:name]
                used_by[elem[:name]] << { name: elem[:name],
                                          kind: "element",
                                          schema: schema_label }
              end

              # Elements used by (referenced by complex types)
              (schema_data[:complex_types] || []).each do |type|
                (type[:elements] || []).each do |type_el|
                  if type_el[:name] == "#{elem[:name]} (ref)"
                    used_by[elem[:name]] << { name: type[:name],
                                              kind: "complexType",
                                              schema: schema_label }
                  end
                end
              end
            end

            # Complex types: base type, element types, attribute types, groups
            (schema_data[:complex_types] || []).each do |type|
              if type[:base]
                used_by[type[:base]] << { name: type[:name],
                                          kind: "complexType",
                                          schema: schema_label }
              end
              (type[:elements] || []).each do |elem|
                element_name = elem[:name] || elem[:ref]
                if element_name
                  used_by[element_name] << { name: type[:name],
                                            kind: "complexType",
                                            schema: schema_label }
                end
                if elem[:type]
                  type_name = elem[:type].split(":").last || elem[:type]
                  used_by[type_name] << { name: type[:name],
                                          kind: "complexType",
                                          schema: schema_label }
                end
              end
              (type[:attributes] || []).each do |attr|
                if attr[:name]
                  used_by[attr[:name]] << { name: type[:name],
                                            kind: "complexType",
                                            schema: schema_label }
                end
              end
              (type[:attribute_groups] || []).each do |ag_ref|
                if ag_ref[:ref]
                  used_by[ag_ref[:ref]] << { name: type[:name],
                                             kind: "complexType",
                                             schema: schema_label }
                end
              end
              (type[:groups] || []).each do |grp_ref|
                if grp_ref[:ref]
                  used_by[grp_ref[:ref]] << { name: type[:name],
                                              kind: "complexType",
                                              schema: schema_label }
                end
              end
            end

            # Simple types: base type
            (schema_data[:simple_types] || []).each do |type|
              if type[:base]
                used_by[type[:base]] << { name: type[:name],
                                          kind: "simpleType",
                                          schema: schema_label }
              end
            end

            # Schema elements: type attribute
            (schema_data[:elements] || []).each do |elem|
              if elem[:type]
                type_name = elem[:type].split(":").last || elem[:type]
                used_by[type_name] << { name: elem[:name], kind: "element",
                                       schema: schema_label }
              end
            end
          end

          # Deduplicate
          used_by.each_key { |k| used_by[k] = used_by[k].uniq }
          used_by
        end

        # Serialize type attributes
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized attributes
        def serialize_type_attributes(type)
          return [] unless type.respond_to?(:attributes)

          type.attributes.map do |attr|
            # Check for inline simpleType with enumeration
            enum_default, enum_type = extract_enumeration_default(attr)
            {
              name: attr.name || "#{attr.ref} (ref)",
              type: enum_type || attr.type,
              use: attr.use,
              default: enum_default || (attr.respond_to?(:default) ? attr.default : nil),
              fixed: attr.respond_to?(:fixed) ? attr.fixed : nil,
              documentation: extract_documentation(attr),
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
              name: elem.name || "#{elem.ref} (ref)",
              type: elem.type,
              min_occurs: elem.min_occurs,
              max_occurs: elem.max_occurs,
              occurs: {
                min: elem.min_occurs || 1,
                max: elem.max_occurs || 1,
              },
              reference: elem.respond_to?(:ref) ? elem.ref : nil,
              documentation: extract_documentation(elem),
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
            facets: serialize_facets(restriction),
          }
        end

        # Serialize facets
        #
        # @param restriction [Restriction] Restriction object
        # @return [Array<Hash>] Serialized facets
        def serialize_facets(restriction)
          facets = []

          if restriction.respond_to?(:enumerations) && restriction.enumerations
            facets << { type: "enumeration",
                        values: restriction.enumerations }
          end

          if restriction.respond_to?(:pattern) && restriction.pattern
            facets << { type: "pattern",
                        value: restriction.pattern }
          end

          if restriction.respond_to?(:min_length) && restriction.min_length
            facets << { type: "min_length",
                        value: restriction.min_length }
          end

          if restriction.respond_to?(:max_length) && restriction.max_length
            facets << { type: "max_length",
                        value: restriction.max_length }
          end

          if restriction.respond_to?(:length) && restriction.length
            facets << { type: "length",
                        value: restriction.length }
          end

          if restriction.respond_to?(:min_inclusive) && restriction.min_inclusive
            facets << { type: "min_inclusive",
                        value: restriction.min_inclusive }
          end

          if restriction.respond_to?(:max_inclusive) && restriction.max_inclusive
            facets << { type: "max_inclusive",
                        value: restriction.max_inclusive }
          end

          if restriction.respond_to?(:min_exclusive) && restriction.min_exclusive
            facets << { type: "min_exclusive",
                        value: restriction.min_exclusive }
          end

          if restriction.respond_to?(:max_exclusive) && restriction.max_exclusive
            facets << { type: "max_exclusive",
                        value: restriction.max_exclusive }
          end

          if restriction.respond_to?(:total_digits) && restriction.total_digits
            facets << { type: "total_digits",
                        value: restriction.total_digits }
          end

          if restriction.respond_to?(:fraction_digits) && restriction.fraction_digits
            facets << { type: "fraction_digits",
                        value: restriction.fraction_digits }
          end

          if restriction.respond_to?(:white_space) && restriction.white_space
            facets << { type: "white_space",
                        value: restriction.white_space }
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
          return type.restriction.base if type.respond_to?(:restriction) && type.restriction.respond_to?(:base)

          return type.list.item_type if type.respond_to?(:list) && type.list.respond_to?(:item_type)

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
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2') # Split acronyms: HTTPParser → HTTP-Parser
            .gsub(/([a-z\d])([A-Z])/, '\1-\2') # Split camelCase: fooBar → foo-Bar
            .downcase # Convert to lowercase
            .gsub(/[^a-z0-9]+/, "-") # Replace non-alphanumeric with dash
            .gsub(/^-|-$/, "") # Remove leading/trailing dashes
        end

        def schema_id(index, schema = nil, file_path = nil)
          # Use schema name instead of index
          name = schema_name(schema, file_path) if schema
          name ||= "schema-#{index}" # Fallback
          slugify(name)
        end

        def element_id(index, element = nil, prefix = nil)
          if element&.name
            slug = slugify(element.name)
            return prefix ? "element-#{prefix}-#{slug}" : "element-#{slug}"
          end

          "element-#{index}"
        end

        def complex_type_id(index, type = nil, prefix = nil)
          if type&.name
            slug = slugify(type.name)
            return prefix ? "type-#{prefix}-#{slug}" : "type-#{slug}"
          end

          "type-#{index}"
        end

        def simple_type_id(index, type = nil, prefix = nil)
          if type&.name
            slug = slugify(type.name)
            return prefix ? "simpletype-#{prefix}-#{slug}" : "simpletype-#{slug}"
          end

          "simpletype-#{index}"
        end

        def attribute_id(index, attr = nil, prefix = nil)
          if attr&.name
            slug = slugify(attr.name)
            return prefix ? "attr-#{prefix}-#{slug}" : "attr-#{slug}"
          end

          "attr-#{index}"
        end

        def group_id(index, group = nil, prefix = nil)
          if group&.name
            slug = slugify(group.name)
            return prefix ? "group-#{prefix}-#{slug}" : "group-#{slug}"
          end

          "group-#{index}"
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
          # Prioritize filename if available and meaningful
          if file_path.is_a?(String) && !file_path.empty?
            basename = File.basename(file_path, ".*")
            # Use filename unless it's generic (schema, unnamed, or just numbers)
            return basename unless basename.match?(/^(schema|unnamed|\d+)$/i)
          end

          # Fallback to target namespace extraction
          if schema.respond_to?(:target_namespace) && schema.target_namespace
            # Extract last meaningful part of namespace URI
            uri = schema.target_namespace
            # For URNs like "urn:oasis:names:tc:unitsml:schema:xsd:UnitsML-Schema-1.0"
            # extract the last part
            last_part = uri.split("/").last || uri.split(":").last || "unnamed"
            # Don't return if it's just a version number (e.g., "3.2")
            return last_part unless last_part.match?(/^\d+(\.\d+)*$/)
          end

          # Final fallback: use filename if we have one, even if generic
          if file_path.is_a?(String) && !file_path.empty?
            return File.basename(file_path,
                                 ".*")
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

          if package.respond_to?(:metadata)
            metadata = package.metadata
            # Handle both Hash (backward compat) and SchemaRepositoryMetadata object
            entrypoint_files = if metadata.is_a?(Hash)
                                 metadata[:files] || metadata["files"] || []
                               elsif metadata.respond_to?(:files)
                                 metadata.files || []
                               else
                                 []
                               end
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
            all_schemas: get_schemas,
          )
          generator.generate
        rescue StandardError => e
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
          get_schemas.each_value do |schema|
            # Check if component is in this schema's elements
            return schema if schema.respond_to?(:element) && schema.element&.include?(component)

            # Check if component is in this schema's complex types
            return schema if schema.respond_to?(:complex_type) && schema.complex_type&.include?(component)

            # Check if component is in this schema's simple types
            return schema if schema.respond_to?(:simple_type) && schema.simple_type&.include?(component)
          end

          # If not found, return first schema as fallback
          _path, schema = get_schemas.first
          schema
        end

        # Generate SVG diagram for a component using xsdvi CLI
        #
        # @param component_data [Hash] Serialized component data
        # @param component_type [Symbol] Component type (:element or :type)
        # @param file_path [String, nil] XSD file path for xsdvi
        # @return [String, nil] SVG diagram markup
        def generate_diagram(component_data, _component_type, file_path = nil)
          name = component_data[:name] || component_data["name"]
          return nil unless name && file_path

          gen_element_diagram(name, file_path)
        rescue StandardError => e
          warn "Warning: Failed to generate SVG diagram: #{e.message}" if ENV["DEBUG"]
          nil
        end
      end
    end
  end
end
