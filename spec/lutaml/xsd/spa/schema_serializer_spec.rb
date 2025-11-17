# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/schema_serializer"
require "json"

RSpec.describe Lutaml::Xsd::Spa::SchemaSerializer do
  # Helper to create real schema from XML
  let(:test_schema_xml) do
    <<~XML
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="TestElement" type="xs:string" minOccurs="0" maxOccurs="1"/>
        <xs:complexType name="TestComplexType"/>
        <xs:simpleType name="TestSimpleType">
          <xs:restriction base="xs:string"/>
        </xs:simpleType>
        <xs:attribute name="testAttr" type="xs:string" use="required"/>
      </xs:schema>
    XML
  end

  let(:real_schema) { Lutaml::Xsd::Schema.from_xml(test_schema_xml) }
  let(:real_element) { real_schema.element.first }
  let(:real_complex_type) { real_schema.complex_type.first }
  let(:real_simple_type) { real_schema.simple_type.first }
  let(:real_attribute) { real_schema.attribute.first }

  let(:real_repository) do
    Lutaml::Xsd::SchemaRepository.new.tap do |repo|
      # Override all_schemas to return our test schema
      def repo.all_schemas
        { "test-schema.xsd" => @test_schema }
      end
      def repo.test_schema=(schema)
        @test_schema = schema
      end
      repo.test_schema = real_schema
    end
  end

  let(:config) { { "title" => "Test Documentation" } }

  subject(:serializer) { described_class.new(real_repository, config) }

  describe "#initialize" do
    it "accepts repository and config" do
      expect(serializer.repository).to eq(real_repository)
      expect(serializer.config).to eq(config)
    end

    it "accepts repository without config" do
      serializer = described_class.new(real_repository)
      expect(serializer.config).to eq({})
    end
  end

  describe "#serialize" do
    it "returns hash with metadata, schemas, and index" do
      result = serializer.serialize

      expect(result).to be_a(Hash)
      expect(result).to have_key(:metadata)
      expect(result).to have_key(:schemas)
      expect(result).to have_key(:index)
    end

    it "includes metadata section" do
      result = serializer.serialize
      metadata = result[:metadata]

      expect(metadata).to be_a(Hash)
      expect(metadata[:generated]).to be_a(String)
      expect(metadata[:generator]).to match(/lutaml-xsd/)
      expect(metadata[:title]).to eq("Test Documentation")
      expect(metadata[:schema_count]).to eq(1)
    end

    it "includes schemas section" do
      result = serializer.serialize
      schemas = result[:schemas]

      expect(schemas).to be_an(Array)
      expect(schemas.size).to eq(1)
    end

    it "includes index section" do
      result = serializer.serialize
      index = result[:index]

      expect(index).to be_a(Hash)
      expect(index).to have_key(:by_id)
      expect(index).to have_key(:by_name)
      expect(index).to have_key(:by_type)
    end
  end

  describe "#to_json" do
    it "returns JSON string" do
      json = serializer.to_json(pretty: false)

      expect(json).to be_a(String)
      expect { JSON.parse(json) }.not_to raise_error
    end

    it "returns pretty-printed JSON when pretty: true" do
      json = serializer.to_json(pretty: true)

      expect(json).to include("\n")
      parsed = JSON.parse(json)
      expect(parsed).to have_key("metadata")
    end

    it "returns compact JSON when pretty: false" do
      json = serializer.to_json(pretty: false)

      expect(json).not_to include("\n  ")
    end
  end

  describe "#serialize_schema" do
    it "serializes schema with all sections" do
      schema_data = serializer.send(:serialize_schema, real_schema, 0, "test-schema.xsd")

      expect(schema_data[:id]).to eq("test")
      expect(schema_data[:name]).to eq("test")
      expect(schema_data[:namespace]).to eq("http://example.com/test")
      expect(schema_data).to have_key(:elements)
      expect(schema_data).to have_key(:complex_types)
      expect(schema_data).to have_key(:simple_types)
      expect(schema_data).to have_key(:attributes)
      expect(schema_data).to have_key(:groups)
    end
  end

  describe "#serialize_elements" do
    it "serializes array of elements" do
      elements = serializer.send(:serialize_elements, real_schema)

      expect(elements).to be_an(Array)
      expect(elements.size).to eq(1)
      expect(elements.first[:name]).to eq("TestElement")
    end

    it "returns empty array when schema has no elements" do
      empty_schema_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      XML
      empty_schema = Lutaml::Xsd::Schema.from_xml(empty_schema_xml)

      elements = serializer.send(:serialize_elements, empty_schema)
      expect(elements).to eq([])
    end
  end

  describe "#serialize_element" do
    it "serializes element with all properties" do
      element_data = serializer.send(:serialize_element, real_element, 0)

      expect(element_data[:id]).to eq("test-element")
      expect(element_data[:name]).to eq("TestElement")
      expect(element_data[:type]).to eq("xs:string")
      expect(element_data[:min_occurs]).to eq("0")
      expect(element_data[:max_occurs]).to eq("1")
    end
  end

  describe "#serialize_complex_types" do
    it "serializes array of complex types" do
      types = serializer.send(:serialize_complex_types, real_schema)

      expect(types).to be_an(Array)
      expect(types.size).to eq(1)
      expect(types.first[:name]).to eq("TestComplexType")
    end

    it "returns empty array when schema has no complex types" do
      empty_schema_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      XML
      empty_schema = Lutaml::Xsd::Schema.from_xml(empty_schema_xml)

      types = serializer.send(:serialize_complex_types, empty_schema)
      expect(types).to eq([])
    end
  end

  describe "#serialize_complex_type" do
    it "serializes complex type with all properties" do
      type_data = serializer.send(:serialize_complex_type, real_complex_type, 0)

      expect(type_data[:id]).to eq("type-test-complex-type")
      expect(type_data[:name]).to eq("TestComplexType")
      expect(type_data[:base]).to be_nil
      expect(type_data).to have_key(:content_model)
      expect(type_data).to have_key(:attributes)
      expect(type_data).to have_key(:elements)
    end
  end

  describe "#serialize_simple_types" do
    it "serializes array of simple types" do
      types = serializer.send(:serialize_simple_types, real_schema)

      expect(types).to be_an(Array)
      expect(types.size).to eq(1)
      expect(types.first[:name]).to eq("TestSimpleType")
    end

    it "returns empty array when schema has no simple types" do
      empty_schema_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      XML
      empty_schema = Lutaml::Xsd::Schema.from_xml(empty_schema_xml)

      types = serializer.send(:serialize_simple_types, empty_schema)
      expect(types).to eq([])
    end
  end

  describe "#serialize_simple_type" do
    it "serializes simple type with all properties" do
      type_data = serializer.send(:serialize_simple_type, real_simple_type, 0)

      expect(type_data[:id]).to eq("simpletype-test-simple-type")
      expect(type_data[:name]).to eq("TestSimpleType")
      expect(type_data).to have_key(:restriction)
    end
  end

  describe "#serialize_attributes" do
    it "serializes array of attributes" do
      attributes = serializer.send(:serialize_attributes, real_schema)

      expect(attributes).to be_an(Array)
      expect(attributes.size).to eq(1)
      expect(attributes.first[:name]).to eq("testAttr")
    end

    it "returns empty array when schema has no attributes" do
      empty_schema_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      XML
      empty_schema = Lutaml::Xsd::Schema.from_xml(empty_schema_xml)

      attributes = serializer.send(:serialize_attributes, empty_schema)
      expect(attributes).to eq([])
    end
  end

  describe "#serialize_attribute" do
    it "serializes attribute with all properties" do
      attr_data = serializer.send(:serialize_attribute, real_attribute, 0)

      expect(attr_data[:id]).to eq("attr-test-attr")
      expect(attr_data[:name]).to eq("testAttr")
      expect(attr_data[:type]).to eq("xs:string")
      expect(attr_data[:use]).to eq("required")
    end
  end

  describe "#extract_documentation" do
    context "when object has annotation with documentation" do
      let(:element_with_doc_xml) do
        <<~XML
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="TestElement">
              <xs:annotation>
                <xs:documentation>Test doc</xs:documentation>
              </xs:annotation>
            </xs:element>
          </xs:schema>
        XML
      end

      let(:schema_with_doc) { Lutaml::Xsd::Schema.from_xml(element_with_doc_xml) }
      let(:element_with_doc) { schema_with_doc.element.first }

      it "extracts documentation content" do
        doc = serializer.send(:extract_documentation, element_with_doc)
        expect(doc).to eq("Test doc")
      end
    end

    context "when object has no annotation" do
      it "returns nil" do
        doc = serializer.send(:extract_documentation, real_element)
        expect(doc).to be_nil
      end
    end

    context "when object does not respond to annotation" do
      it "returns nil" do
        obj = Object.new
        doc = serializer.send(:extract_documentation, obj)
        expect(doc).to be_nil
      end
    end
  end

  describe "#extract_content_model" do
    it "returns 'sequence' when type has sequence" do
      type_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="TestType">
            <xs:sequence>
              <xs:element name="child" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:schema>
      XML
      schema = Lutaml::Xsd::Schema.from_xml(type_xml)
      type = schema.complex_type.first

      model = serializer.send(:extract_content_model, type)
      expect(model).to eq("sequence")
    end

    it "returns 'choice' when type has choice" do
      type_xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="TestType">
            <xs:choice>
              <xs:element name="child" type="xs:string"/>
            </xs:choice>
          </xs:complexType>
        </xs:schema>
      XML
      schema = Lutaml::Xsd::Schema.from_xml(type_xml)
      type = schema.complex_type.first

      model = serializer.send(:extract_content_model, type)
      expect(model).to eq("choice")
    end

    it "returns 'empty' when type has no content model" do
      model = serializer.send(:extract_content_model, real_complex_type)
      expect(model).to eq("empty")
    end
  end

  describe "ID generation methods" do
    it "generates schema ID" do
      expect(serializer.send(:schema_id, 5)).to eq("schema-5")
    end

    it "generates element ID" do
      expect(serializer.send(:element_id, 10, real_element)).to eq("test-element")
    end

    it "generates complex type ID" do
      expect(serializer.send(:complex_type_id, 3, real_complex_type)).to eq("type-test-complex-type")
    end

    it "generates simple type ID" do
      expect(serializer.send(:simple_type_id, 7, real_simple_type)).to eq("simpletype-test-simple-type")
    end

    it "generates attribute ID" do
      expect(serializer.send(:attribute_id, 2, real_attribute)).to eq("attr-test-attr")
    end

    it "generates group ID" do
      expect(serializer.send(:group_id, 1)).to eq("group-1")
    end
  end

  describe "helper methods" do
    it "returns current timestamp in ISO8601 format" do
      timestamp = serializer.send(:current_timestamp)
      expect(timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "returns generator info" do
      info = serializer.send(:generator_info)
      expect(info).to match(/lutaml-xsd v/)
    end

    it "returns default title" do
      title = serializer.send(:default_title)
      expect(title).to eq("XSD Schema Documentation")
    end

    it "returns schema name" do
      name = serializer.send(:schema_name, real_schema)
      expect(name).to eq("test")
    end

    it "returns 'unnamed' for schema without name" do
      minimal_xml = '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>'
      schema = Lutaml::Xsd::Schema.from_xml(minimal_xml)
      name = serializer.send(:schema_name, schema)
      expect(name).to eq("unnamed")
    end
  end

  describe "edge cases" do
    context "when repository has no schemas" do
      let(:empty_repository) do
        Lutaml::Xsd::SchemaRepository.new.tap do |repo|
          def repo.all_schemas
            {}
          end
        end
      end

      let(:empty_serializer) { described_class.new(empty_repository) }

      it "serializes empty schemas array" do
        result = empty_serializer.serialize
        expect(result[:schemas]).to eq([])
        expect(result[:metadata][:schema_count]).to eq(0)
      end
    end

    context "when schema has nil collections" do
      let(:minimal_xml) { '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>' }
      let(:minimal_schema) { Lutaml::Xsd::Schema.from_xml(minimal_xml) }

      let(:minimal_repository) do
        Lutaml::Xsd::SchemaRepository.new.tap do |repo|
          def repo.all_schemas
            { "minimal.xsd" => @minimal_schema }
          end
          def repo.minimal_schema=(schema)
            @minimal_schema = schema
          end
          repo.minimal_schema = minimal_schema
        end
      end

      it "handles nil collections gracefully" do
        serializer = described_class.new(minimal_repository)

        result = serializer.serialize
        expect(result[:schemas].first[:elements]).to eq([])
        expect(result[:schemas].first[:complex_types]).to eq([])
      end
    end
  end
end