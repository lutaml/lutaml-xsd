# frozen_string_literal: true

module Lutaml
  module Xsd
    class Schema < Lutaml::Model::Serializable
      attribute :xmlns, :string
      attribute :import, Import, collection: true
      attribute :schemas, Schema, collection: true
      attribute :import_and_include, :hash, collection: true
      attribute :include, Include, collection: true
      attribute :element, Element, collection: true
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

        map_attribute :xmlns, to: :xmlns, namespace: "http://csrc.nist.gov/ns/oscal/metaschema/1.0", prefix: nil
        map_element :import, to: :import, with: { from: :from_schema, to: :to_schema_xml }
        map_element :include, to: :include
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

      def self.processed_schemas
        @processed_schemas ||= {}
      end

      def self.schema_processed?(id)
        processed_schemas[id]
      end

      def self.schema_processed(id)
        processed_schemas[id] = true
      end

      def from_schema(model, value)
        model.import_and_include += value
        model.import_and_include&.flatten!&.uniq!
        value.each do |imported_schema|
          next if self.class.schema_processed?(imported_schema["id"])

          self.class.schema_processed(imported_schema["id"])
          imported_schema["schema_location"] = imported_schema.delete("__schema_location")&.dig(:schema_location)
          schema_imported = Import.new(
            id: imported_schema["id"],
            namespace: imported_schema["namespace"],
            schema_location: imported_schema["schema_location"],
          ).import_schema
          model.schemas << Lutaml::Xsd.parse(schema_imported, location: Glob.location) if schema_imported
        end
      end

      def to_schema_xml(model, parent, doc)
        model.import_and_include.each_with_index do |imported_schema, index|
          import_element = doc.create_element("import")
          import_element.set_attribute("id", imported_schema["id"]) if imported_schema["id"]
          import_element.set_attribute("namespace", imported_schema["namespace"]) if imported_schema["namespace"]
          if imported_schema["__schema_location"]&.key?(:schema_location)
            import_element.set_attribute("schemaLocation", imported_schema["__schema_location"][:schema_location])
          end
          model.import_and_include.delete_at(index)
          parent.add_child(import_element)
        end
      end
    end
  end
end
