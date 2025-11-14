# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Attribute do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:attribute name="TestAttribute" type="xs:string"/>
        <xs:attribute name="RequiredAttribute" type="xs:string"/>
        <xs:attribute name="OptionalAttribute" type="xs:string"/>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:required_attr) { schema.attribute.find { |a| a.name == "RequiredAttribute" } }
  let(:optional_attr) { schema.attribute.find { |a| a.name == "OptionalAttribute" } }
  let(:test_attr) { schema.attribute.find { |a| a.name == "TestAttribute" } }

  before do
    [required_attr, optional_attr, test_attr].each do |attr|
      attr&.instance_variable_set(:@__root, schema)
    end
  end

  describe "#cardinality" do
    it "returns '1' for required attributes" do
      required_attr.use = "required"
      expect(required_attr.cardinality).to eq("1")
    end

    it "returns '0..1' for optional attributes" do
      optional_attr.use = "optional"
      expect(optional_attr.cardinality).to eq("0..1")
    end

    it "returns nil for attributes without use specified" do
      test_attr.use = nil
      expect(test_attr.cardinality).to be_nil
    end
  end

  describe "#referenced_type" do
    it "returns the type of the attribute when it has a name" do
      test_attr.type = "xs:string"
      expect(test_attr.referenced_type).to eq("xs:string")
    end

    it "returns the type of the referenced attribute when using ref" do
      ref_attr = Lutaml::Xsd::Attribute.new(__register: Lutaml::Xsd.register)
      ref_attr.ref = "TestAttribute"
      ref_attr.instance_variable_set(:@__root, schema)
      test_attr.type = "xs:int"
      expect(ref_attr.referenced_type).to eq("xs:int")
    end
  end

  describe "#referenced_name" do
    it "returns the name when attribute has a name" do
      expect(test_attr.referenced_name).to eq("TestAttribute")
    end

    it "returns the name of referenced attribute when using ref" do
      ref_attr = Lutaml::Xsd::Attribute.new(__register: Lutaml::Xsd.register)
      ref_attr.ref = "TestAttribute"
      ref_attr.instance_variable_set(:@__root, schema)
      expect(ref_attr.referenced_name).to eq("TestAttribute")
    end

    it "returns ref when referenced object is not found" do
      ref_attr = Lutaml::Xsd::Attribute.new(__register: Lutaml::Xsd.register)
      ref_attr.ref = "NonExistent"
      ref_attr.instance_variable_set(:@__root, schema)
      expect(ref_attr.referenced_name).to eq("NonExistent")
    end
  end

  describe "#referenced_object" do
    it "returns self when attribute has a name" do
      expect(test_attr.referenced_object).to eq(test_attr)
    end

    it "returns the referenced attribute when using ref" do
      ref_attr = Lutaml::Xsd::Attribute.new(__register: Lutaml::Xsd.register)
      ref_attr.ref = "TestAttribute"
      ref_attr.instance_variable_set(:@__root, schema)
      expect(ref_attr.referenced_object).to eq(test_attr)
    end
  end
end
