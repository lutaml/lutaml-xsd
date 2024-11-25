# frozen_string_literal: true

module Lutaml
  module Xsd
    class Schema < Lutaml::Model::Serializable
      attribute :xmlns, :string
      attribute :imports, Import, collection: true
      attribute :includes, Include, collection: true
      attribute :import, Import, collection: true
      attribute :schemas, Schema, collection: true
      attribute :element, Element, collection: true
      attribute :include, Include, collection: true
      attribute :complex_type, ComplexType, collection: true
      attribute :simple_type, SimpleType, collection: true
      attribute :group, Group, collection: true
      attribute :attribute_group, AttributeGroup, collection: true
      attribute :element_form_default, :string
      attribute :attribute_form_default, :string
      attribute :block_default, :string
      attribute :target_namespace, :string

      xml do
        root "schema", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :import, to: :import, with: { from: :import_from_schema, to: :import_to_schema }
        map_element :include, to: :include, with: { from: :include_from_schema, to: :include_to_schema }
        map_element :element, to: :element
        map_element :complexType, to: :complex_type
        map_element :simpleType, to: :simple_type
        map_element :group, to: :group
        map_element :attributeGroup, to: :attribute_group
        map_attribute :elementFormDefault, to: :element_form_default
        map_attribute :attributeFormDefault, to: :attribute_form_default
        map_attribute :blockDefault, to: :block_default
        map_attribute :targetNamespace, to: :target_namespace
      end

      def import_from_schema(model, value)
        model.imports += value
        model.imports&.flatten!&.uniq!

        value.each do |imported_schema|
          next if self.class.schema_processed?(dig_schema_location(imported_schema))

          self.class.schema_processed(dig_schema_location(imported_schema))
          insert_in_schemas(schema_imported(imported_schema), model)
        end
      end

      def import_to_schema(model, parent, doc)
        model.imports.each_with_index do |imported_schema, index|
          import_element = create_import_or_include_element(imported_schema, doc, element_name: "import")
          insert_annotation(imported_schema, import_element, doc)
          parent.add_child(import_element)
          model.imports.delete_at(index)
        end
      end

      def include_from_schema(model, value)
        model.includes += value
        model.includes&.flatten!&.uniq!

        value.each do |included_schema|
          next if self.class.schema_processed?(dig_schema_location(included_schema))

          self.class.schema_processed(dig_schema_location(included_schema))
          insert_in_schemas(schema_included(included_schema), model)
        end
      end

      def include_to_schema(model, parent, doc)
        model.includes.each_with_index do |included_schema, index|
          include_element = create_import_or_include_element(included_schema, doc, element_name: "include")
          insert_annotation(included_schema, include_element, doc)
          parent.add_child(include_element)
          model.includes.delete_at(index)
        end
      end

      private

      def dig_schema_location(schema_hash)
        schema_hash&.dig("__schema_location", :schema_location)
      end

      def schema_location?(schema_hash)
        schema_hash&.dig("__schema_location")&.key?(:schema_location)
      end

      def add_annotation(value, doc)
        annotation = doc.create_element("annotation")
        documentation_element = doc.create_element("documentation")
        documentation_element.add_child(documentation_text(value))
        annotation.add_child(documentation_element)
        annotation
      end

      def documentation_text(value)
        documentation_key = value.keys.find { |key| key.include?("documentation") }
        value.dig(documentation_key, "text")
      end

      def create_import_or_include_element(schema_hash, doc, element_name:)
        element = doc.create_element(element_name)
        element.set_attribute("id", schema_hash["id"]) if schema_hash["id"]
        element.set_attribute("namespace", schema_hash["namespace"]) if schema_hash["namespace"]
        element.set_attribute("schemaLocation", dig_schema_location(schema_hash)) if schema_location?(schema_hash)
        element
      end

      def insert_annotation(schema_hash, element, doc)
        schema_hash.each do |key, value|
          next unless key.include?("annotation")

          element.add_child(add_annotation(value, doc))
        end
      end

      def schema_imported(imported_schema)
        Import.new(
          id: imported_schema["id"],
          namespace: imported_schema["namespace"],
          schema_location: dig_schema_location(imported_schema)
        ).import_schema
      end

      def schema_included(included_schema)
        Include.new(
          id: included_schema["id"],
          schema_location: dig_schema_location(included_schema)
        ).include_schema
      end

      def insert_in_schemas(schema, model)
        return unless schema

        model.schemas << Lutaml::Xsd.parse(schema, location: Glob.location)
      end

      class << self
        def processed_schemas
          @processed_schemas ||= {}
        end

        def schema_processed?(location)
          processed_schemas[location]
        end

        def schema_processed(location)
          processed_schemas[location] = true
        end
      end
    end
  end
end
