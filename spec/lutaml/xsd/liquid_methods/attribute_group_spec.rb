# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::AttributeGroup do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:attributeGroup name="TestAttributeGroup">
          <xs:attribute name="GroupAttr1" type="xs:string"/>
          <xs:attribute name="GroupAttr2" type="xs:int"/>
        </xs:attributeGroup>

        <xs:complexType name="RootType">
          <xs:attributeGroup ref="TestAttributeGroup"/>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:attr_group) { schema.attribute_group.find { |ag| ag.name == "TestAttributeGroup" } }
  let(:root_type) { schema.complex_type.find { |ct| ct.name == "RootType" } }

  before do
    attr_group.instance_variable_set(:@__root, schema)
    root_type.instance_variable_set(:@__root, schema)
  end

  describe "#used_by" do
    it "returns complex types that use this attribute group" do
      used_by = attr_group.used_by
      expect(used_by).to include(root_type)
    end
  end

  describe "#attribute_elements" do
    it "returns all attributes from the attribute group" do
      attrs = attr_group.attribute_elements
      expect(attrs.length).to eq(2)
      expect(attrs.map(&:name)).to contain_exactly("GroupAttr1", "GroupAttr2")
    end

    it "accumulates attributes in the provided array" do
      array = []
      attr_group.attribute_elements(array)
      expect(array.length).to eq(2)
    end
  end

  describe "#find_used_by" do
    it "returns true when attribute group is used by the object" do
      expect(attr_group.find_used_by(root_type)).to be true
    end

    it "returns false when attribute group is not used" do
      other_type = Lutaml::Xsd::ComplexType.new(__register: Lutaml::Xsd.register)
      expect(attr_group.find_used_by(other_type)).to be nil
    end
  end

  describe "#referenced_object" do
    it "returns self when attribute group has a name" do
      expect(attr_group.referenced_object).to eq(attr_group)
    end

    it "returns the referenced attribute group when using ref" do
      ref_group = Lutaml::Xsd::AttributeGroup.new(__register: Lutaml::Xsd.register)
      ref_group.ref = "TestAttributeGroup"
      ref_group.instance_variable_set(:@__root, schema)
      expect(ref_group.referenced_object).to eq(attr_group)
    end
  end
end
