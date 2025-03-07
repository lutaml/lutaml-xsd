# frozen_string_literal: true

module Lutaml
  module Xsd
    # rubocop:disable Metrics/ClassLength
    class Schema < Model::Serializable
      attribute :id, :string
      attribute :lang, :string
      attribute :xmlns, :string
      attribute :version, :string
      attribute :imported, :boolean
      attribute :included, :boolean
      attribute :final_default, :string
      attribute :block_default, :string
      attribute :target_namespace, :string
      attribute :element_form_default, :string
      attribute :attribute_form_default, :string
      attribute :imports, Import, collection: true, initialize_empty: true
      attribute :includes, Include, collection: true, initialize_empty: true

      attribute :group, Group, collection: true, initialize_empty: true
      attribute :import, Import, collection: true, initialize_empty: true
      attribute :element, Element, collection: true, initialize_empty: true
      attribute :include, Include, collection: true, initialize_empty: true
      attribute :notation, Notation, collection: true, initialize_empty: true
      attribute :redefine, Redefine, collection: true, initialize_empty: true
      attribute :attribute, Attribute, collection: true, initialize_empty: true
      attribute :annotation, Annotation, collection: true, initialize_empty: true
      attribute :simple_type, SimpleType, collection: true, initialize_empty: true
      attribute :complex_type, ComplexType, collection: true, initialize_empty: true
      attribute :attribute_group, AttributeGroup, collection: true, initialize_empty: true

      xml do
        root "schema", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :group, to: :group
        map_element :element, to: :element
        map_element :redefine, to: :redefine
        map_element :notation, to: :notation
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :simpleType, to: :simple_type
        map_element :complexType, to: :complex_type
        map_element :attributeGroup, to: :attribute_group
        map_element :import, to: :import, with: { from: :import_from_schema, to: :import_to_schema }
        map_element :include, to: :include, with: { from: :include_from_schema, to: :include_to_schema }

        map_attribute :attributeFormDefault, to: :attribute_form_default
        map_attribute :elementFormDefault, to: :element_form_default
        map_attribute :targetNamespace, to: :target_namespace
        map_attribute :finalDefault, to: :final_default
        map_attribute :blockDefault, to: :block_default
        map_attribute :version, to: :version
        map_attribute :id, to: :id
        map_attribute :lang, to: :lang
      end

      def import_from_schema(model, value)
        value.each do |schema|
          setup_import_and_include("import", model, schema, namespace: schema.attributes["namespace"].value)
        end
      end

      def import_to_schema(model, parent, _doc)
        return if model.imported

        model.imported = true
        model.imports.each do |imported_schema|
          parent.add_child(imported_schema.to_xml)
        end
      end

      def include_from_schema(model, value)
        value.each do |schema|
          setup_import_and_include("include", model, schema)
        end
      end

      def include_to_schema(model, parent, _doc)
        return if model.included

        model.included = true
        model.includes.each do |schema_hash|
          parent.add_child(schema_hash.to_xml)
        end
      end

      private

      def setup_import_and_include(klass, model, schema, args = {})
        instance = init_instance_of(klass, schema.attributes || {}, args)
        annotation_object(instance, schema)
        model.send("#{klass}s") << instance
        schema_path = instance.schema_path
        return if self.class.in_progress?(schema_path) || schema_path.nil?

        self.class.add_in_progress(schema_path)
        model.send(klass) << insert_in_processed_schemas(instance)
        self.class.remove_in_progress(schema_path)
      end

      def init_instance_of(klass, schema_hash, args = {})
        args[:id] = schema_hash["id"].value if schema_hash&.key?("id")
        args[:schema_path] = schema_hash["schemaLocation"].value if schema_hash&.key?("schemaLocation")
        Lutaml::Xsd.const_get(klass.capitalize).new(**args)
      end

      def insert_in_processed_schemas(instance)
        parsed_schema = schema_by_location_or_instance(instance)
        return unless parsed_schema

        self.class.schema_processed(instance.schema_path, parsed_schema)
        parsed_schema
      end

      def schema_by_location_or_instance(instance)
        schema_path = instance.schema_path
        return unless schema_path && Glob.location?

        self.class.processed_schemas[schema_path] ||
          Lutaml::Xsd.parse(
            instance.fetch_schema,
            location: Glob.location,
            nested_schema: true
          )
      end

      def annotation_object(instance, schema)
        elements = schema.children || []
        annotation_key = elements.find { |element| element.unprefixed_name == "annotation" }
        return unless annotation_key

        instance.annotation = Annotation.apply_mappings(annotation_key, :xml)
      end

      class << self
        def reset_processed_schemas
          @processed_schemas = {}
        end

        def processed_schemas
          @processed_schemas ||= {}
        end

        def schema_processed?(location)
          processed_schemas[location]
        end

        def schema_processed(location, schema)
          return if location.nil?

          processed_schemas[location] = schema
        end

        def in_progress
          @in_progress ||= []
        end

        def in_progress?(location)
          in_progress.include?(location)
        end

        def add_in_progress(location)
          in_progress << location
        end

        def remove_in_progress(location)
          in_progress.delete(location)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
