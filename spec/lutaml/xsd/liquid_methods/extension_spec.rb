# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Extension do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:attributeGroup name="TestAttributeGroup">
          <xs:attribute name="GroupAttr1" type="xs:string"/>
          <xs:attribute name="GroupAttr2" type="xs:int"/>
        </xs:attributeGroup>

        <xs:complexType name="SimpleContentType">
          <xs:simpleContent>
            <xs:extension base="xs:string">
              <xs:attribute name="ExtendedAttr" type="xs:string"/>
              <xs:attributeGroup ref="TestAttributeGroup"/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:simple_content_type) { schema.complex_type.find { |ct| ct.name == "SimpleContentType" } }
  let(:extension) { simple_content_type.simple_content.extension }

  before do
    extension.attribute_group.each { |ag| ag.instance_variable_set(:@__root, schema) }
  end

  describe "#attribute_elements" do
    it "returns attributes from the extension" do
      attrs = extension.attribute_elements
      expect(attrs.length).to be >= 1
      expect(attrs.map(&:name)).to include("ExtendedAttr")
    end

    it "includes attributes from attribute groups" do
      attrs = extension.attribute_elements
      attr_names = attrs.map(&:name)
      expect(attr_names).to include("GroupAttr1", "GroupAttr2")
    end

    it "accumulates attributes in the provided array" do
      array = []
      extension.attribute_elements(array)
      expect(array.length).to be >= 3
    end
  end
end
