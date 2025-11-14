# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/schema_serializer"
require "json"

RSpec.describe Lutaml::Xsd::Spa::SchemaSerializer do
  let(:mock_element) do
    instance_double(
      Lutaml::Xsd::Element,
      name: "TestElement",
      type: "xs:string",
      min_occurs: "0",
      max_occurs: "1",
      annotation: nil
    )
  end

  let(:mock_attribute) do
    instance_double(
      Lutaml::Xsd::Attribute,
      name: "testAttr",
      type: "xs:string",
      use: "required",
      default: nil,
      annotation: nil
    )
  end

  let(:mock_complex_type) do
    instance_double(
      Lutaml::Xsd::ComplexType,
      name: "TestComplexType",
      base: nil,
      annotation: nil,
      sequence: nil,
      choice: nil,
      all: nil,
      complex_content: nil,
      simple_content: nil
    )
  end

  let(:mock_simple_type) do
    instance_double(
      Lutaml::Xsd::SimpleType,
      name: "TestSimpleType",
      base: "xs:string",
      restriction: nil,
      annotation: nil
    )
  end

  let(:mock_schema) do
    instance_double(
      Lutaml::Xsd::Schema,
      name: "test-schema",
      target_namespace: "http://example.com/test",
      elements: [mock_element],
      complex_types: [mock_complex_type],
      simple_types: [mock_simple_type],
      attributes: [mock_attribute],
      groups: []
    )
  end

  let(:mock_repository) do
    instance_double(
      Lutaml::Xsd::SchemaRepository,
      schemas: [mock_schema]
    )
  end

  let(:config) { { "title" => "Test Documentation" } }

  subject(:serializer) { described_class.new(mock_repository, config) }

  describe "#initialize" do
    it "accepts repository and config" do
      expect(serializer.repository).to eq(mock_repository)
      expect(serializer.config).to eq(config)
    end

    it "accepts repository without config" do
      serializer = described_class.new(mock_repository)
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
      schema_data = serializer.send(:serialize_schema, mock_schema, 0)

      expect(schema_data[:id]).to eq("schema-0")
      expect(schema_data[:name]).to eq("test-schema")
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
      elements = serializer.send(:serialize_elements, mock_schema)

      expect(elements).to be_an(Array)
      expect(elements.size).to eq(1)
      expect(elements.first[:name]).to eq("TestElement")
    end

    it "returns empty array when schema has no elements method" do
      schema = instance_double(Lutaml::Xsd::Schema)
      allow(schema).to receive(:respond_to?).with(:elements).and_return(false)

      elements = serializer.send(:serialize_elements, schema)
      expect(elements).to eq([])
    end
  end

  describe "#serialize_element" do
    it "serializes element with all properties" do
      element_data = serializer.send(:serialize_element, mock_element, 0)

      expect(element_data[:id]).to eq("elem-0")
      expect(element_data[:name]).to eq("TestElement")
      expect(element_data[:type]).to eq("xs:string")
      expect(element_data[:min_occurs]).to eq("0")
      expect(element_data[:max_occurs]).to eq("1")
      expect(element_data[:documentation]).to be_nil
    end
  end

  describe "#serialize_complex_types" do
    it "serializes array of complex types" do
      types = serializer.send(:serialize_complex_types, mock_schema)

      expect(types).to be_an(Array)
      expect(types.size).to eq(1)
      expect(types.first[:name]).to eq("TestComplexType")
    end

    it "returns empty array when schema has no complex_types method" do
      schema = instance_double(Lutaml::Xsd::Schema)
      allow(schema).to receive(:respond_to?).with(:complex_types).and_return(false)

      types = serializer.send(:serialize_complex_types, schema)
      expect(types).to eq([])
    end
  end

  describe "#serialize_complex_type" do
    it "serializes complex type with all properties" do
      type_data = serializer.send(:serialize_complex_type, mock_complex_type, 0)

      expect(type_data[:id]).to eq("ctype-0")
      expect(type_data[:name]).to eq("TestComplexType")
      expect(type_data[:base]).to be_nil
      expect(type_data).to have_key(:content_model)
      expect(type_data).to have_key(:attributes)
      expect(type_data).to have_key(:elements)
    end
  end

  describe "#serialize_simple_types" do
    it "serializes array of simple types" do
      types = serializer.send(:serialize_simple_types, mock_schema)

      expect(types).to be_an(Array)
      expect(types.size).to eq(1)
      expect(types.first[:name]).to eq("TestSimpleType")
    end

    it "returns empty array when schema has no simple_types method" do
      schema = instance_double(Lutaml::Xsd::Schema)
      allow(schema).to receive(:respond_to?).with(:simple_types).and_return(false)

      types = serializer.send(:serialize_simple_types, schema)
      expect(types).to eq([])
    end
  end

  describe "#serialize_simple_type" do
    it "serializes simple type with all properties" do
      type_data = serializer.send(:serialize_simple_type, mock_simple_type, 0)

      expect(type_data[:id]).to eq("stype-0")
      expect(type_data[:name]).to eq("TestSimpleType")
      expect(type_data[:base]).to eq("xs:string")
      expect(type_data[:restriction]).to be_nil
    end
  end

  describe "#serialize_attributes" do
    it "serializes array of attributes" do
      attributes = serializer.send(:serialize_attributes, mock_schema)

      expect(attributes).to be_an(Array)
      expect(attributes.size).to eq(1)
      expect(attributes.first[:name]).to eq("testAttr")
    end

    it "returns empty array when schema has no attributes method" do
      schema = instance_double(Lutaml::Xsd::Schema)
      allow(schema).to receive(:respond_to?).with(:attributes).and_return(false)

      attributes = serializer.send(:serialize_attributes, schema)
      expect(attributes).to eq([])
    end
  end

  describe "#serialize_attribute" do
    it "serializes attribute with all properties" do
      attr_data = serializer.send(:serialize_attribute, mock_attribute, 0)

      expect(attr_data[:id]).to eq("attr-0")
      expect(attr_data[:name]).to eq("testAttr")
      expect(attr_data[:type]).to eq("xs:string")
      expect(attr_data[:use]).to eq("required")
      expect(attr_data[:default]).to be_nil
    end
  end

  describe "#extract_documentation" do
    context "when object has annotation with documentation" do
      let(:mock_documentation) do
        instance_double(Lutaml::Xsd::Documentation, content: "Test doc")
      end

      let(:mock_annotation) do
        instance_double(
          Lutaml::Xsd::Annotation,
          documentations: [mock_documentation]
        )
      end

      let(:annotated_element) do
        instance_double(
          Lutaml::Xsd::Element,
          annotation: mock_annotation
        )
      end

      it "extracts documentation content" do
        doc = serializer.send(:extract_documentation, annotated_element)
        expect(doc).to eq("Test doc")
      end
    end

    context "when object has no annotation" do
      it "returns nil" do
        doc = serializer.send(:extract_documentation, mock_element)
        expect(doc).to be_nil
      end
    end

    context "when object does not respond to annotation" do
      it "returns nil" do
        obj = double("object")
        doc = serializer.send(:extract_documentation, obj)
        expect(doc).to be_nil
      end
    end
  end

  describe "#extract_content_model" do
    it "returns 'sequence' when type has sequence" do
      type = instance_double(Lutaml::Xsd::ComplexType, sequence: true)
      allow(type).to receive(:respond_to?).with(:sequence).and_return(true)
      allow(type).to receive(:respond_to?).with(:choice).and_return(false)

      model = serializer.send(:extract_content_model, type)
      expect(model).to eq("sequence")
    end

    it "returns 'choice' when type has choice" do
      type = instance_double(Lutaml::Xsd::ComplexType, choice: true, sequence: nil)
      allow(type).to receive(:respond_to?).with(:sequence).and_return(true)
      allow(type).to receive(:respond_to?).with(:choice).and_return(true)

      model = serializer.send(:extract_content_model, type)
      expect(model).to eq("choice")
    end

    it "returns 'empty' when type has no content model" do
      type = instance_double(Lutaml::Xsd::ComplexType)
      allow(type).to receive(:respond_to?).and_return(true)
      allow(type).to receive(:sequence).and_return(nil)
      allow(type).to receive(:choice).and_return(nil)
      allow(type).to receive(:all).and_return(nil)
      allow(type).to receive(:complex_content).and_return(nil)
      allow(type).to receive(:simple_content).and_return(nil)

      model = serializer.send(:extract_content_model, type)
      expect(model).to eq("empty")
    end
  end

  describe "ID generation methods" do
    it "generates schema ID" do
      expect(serializer.send(:schema_id, 5)).to eq("schema-5")
    end

    it "generates element ID" do
      expect(serializer.send(:element_id, 10)).to eq("elem-10")
    end

    it "generates complex type ID" do
      expect(serializer.send(:complex_type_id, 3)).to eq("ctype-3")
    end

    it "generates simple type ID" do
      expect(serializer.send(:simple_type_id, 7)).to eq("stype-7")
    end

    it "generates attribute ID" do
      expect(serializer.send(:attribute_id, 2)).to eq("attr-2")
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
      name = serializer.send(:schema_name, mock_schema)
      expect(name).to eq("test-schema")
    end

    it "returns 'unnamed' for schema without name" do
      schema = instance_double(Lutaml::Xsd::Schema, name: nil)
      name = serializer.send(:schema_name, schema)
      expect(name).to eq("unnamed")
    end
  end

  describe "edge cases" do
    context "when repository has no schemas" do
      let(:empty_repository) do
        instance_double(Lutaml::Xsd::SchemaRepository, schemas: [])
      end

      let(:empty_serializer) { described_class.new(empty_repository) }

      it "serializes empty schemas array" do
        result = empty_serializer.serialize
        expect(result[:schemas]).to eq([])
        expect(result[:metadata][:schema_count]).to eq(0)
      end
    end

    context "when schema has nil collections" do
      let(:minimal_schema) do
        instance_double(
          Lutaml::Xsd::Schema,
          name: "minimal",
          target_namespace: nil
        )
      end

      let(:minimal_repository) do
        instance_double(
          Lutaml::Xsd::SchemaRepository,
          schemas: [minimal_schema]
        )
      end

      it "handles nil collections gracefully" do
        serializer = described_class.new(minimal_repository)
        allow(minimal_schema).to receive(:respond_to?).and_return(false)

        result = serializer.serialize
        expect(result[:schemas].first[:elements]).to eq([])
        expect(result[:schemas].first[:complex_types]).to eq([])
      end
    end
  end
end