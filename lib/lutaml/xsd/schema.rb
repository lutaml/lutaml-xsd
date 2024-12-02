# frozen_string_literal: true

module Lutaml
  module Xsd
    # rubocop:disable Metrics/ClassLength
    class Schema < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :xmlns, :string
      attribute :version, :string
      attribute :final_default, :string
      attribute :block_default, :string
      attribute :target_namespace, :string
      attribute :element_form_default, :string
      attribute :attribute_form_default, :string
      attribute :imports, Import, collection: true
      attribute :includes, Include, collection: true

      attribute :group, Group, collection: true
      attribute :import, Import, collection: true
      attribute :element, Element, collection: true
      attribute :include, Include, collection: true
      attribute :attribute, Attribute, collection: true
      attribute :annotation, Annotation, collection: true
      attribute :simple_type, SimpleType, collection: true
      attribute :complex_type, ComplexType, collection: true
      attribute :attribute_group, AttributeGroup, collection: true

      xml do
        root "schema", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :group, to: :group
        map_element :element, to: :element
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
      end

      def import_from_schema(model, value)
        value.each do |schema|
          setup_imports(model, schema)
          instance = import_object(schema)
          schema_location = instance.schema_location
          next if self.class.in_progress?(schema_location) || schema_location.nil?

          self.class.set_in_progress(schema_location)
          model.import << insert_in_processed_schemas(instance)
          self.class.remove_in_progress(schema_location)
        end
      end

      def import_to_schema(model, parent, doc)
        model.imports.each_with_index do |imported_schema, index|
          parent.add_child(imported_schema.to_xml)
          model.imports.delete_at(index)
        end
      end

      def include_from_schema(model, value)
        model.includes += value
        model.includes&.flatten!&.uniq!

        value.each do |schema|
          model.include << insert_in_processed_schemas(
            include_object(schema)
          )
        end
      end

      def include_to_schema(model, parent, doc)
        model.includes.each_with_index do |schema_hash, index|
          parent.add_child(schema_hash.to_xml)
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

      def import_object(imported_schema)
        Import.new(
          id: imported_schema["id"],
          namespace: imported_schema["namespace"],
          schema_path: dig_schema_location(imported_schema)
        )
      end

      def include_object(schema_hash)
        Include.new(
          id: schema_hash["id"],
          schema_location: dig_schema_location(schema_hash)
        )
      end

      def insert_in_processed_schemas(instance)
        parsed_schema = schema_by_location_or_instance(instance)
        return unless parsed_schema

        self.class.schema_processed(instance.schema_location, parsed_schema)
        parsed_schema
      end

      def schema_by_location_or_instance(instance)
        schema_location = instance.schema_location
        return unless schema_location

        self.class.processed_schemas[schema_location] ||
          Lutaml::Xsd.parse(
            instance.fetch_schema,
            location: Glob.location,
            nested_schema: true
          )
      end

      def setup_imports(model, schema)
        instance = import_object(schema)
        annotation_object(instance, schema)
        model.imports << instance
      end

      def annotation_object(instance, schema)
        annotation_key = schema.keys.find { |key| key.include?("annotation") }
        return unless annotation_key

        instance.annotation = Annotation.apply_mappings(schema[annotation_key], :xml)
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

        def set_in_progress(location)
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
