# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::SimpleContent do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:attributeGroup name="TestAttributeGroup">
          <xs:attribute name="GroupAttr1" type="xs:string"/>
        </xs:attributeGroup>

        <xs:complexType name="SimpleContentType">
          <xs:simpleContent>
            <xs:extension base="xs:string">
              <xs:attribute name="ExtendedAttr" type="xs:string"/>
              <xs:attributeGroup ref="TestAttributeGroup"/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>

        <xs:complexType name="SimpleContentWithBase">
          <xs:simpleContent base="xs:int">
          </xs:simpleContent>
        </xs:complexType>

        <xs:complexType name="SimpleContentWithRestriction">
          <xs:simpleContent>
            <xs:restriction base="xs:string">
              <xs:maxLength value="100"/>
            </xs:restriction>
          </xs:simpleContent>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:complex_types) { schema.complex_type }
  let(:simple_content) { complex_types.find { |ct| ct.name == "SimpleContentType" }.simple_content }

  describe "#attribute_elements" do
    it "returns attributes from the extension" do
      attrs = simple_content.attribute_elements
      expect(attrs.length).to be >= 1
      expect(attrs.map(&:name)).to include("ExtendedAttr")
    end

    it "includes attributes from attribute groups in extension" do
      attrs = simple_content.attribute_elements
      attr_names = attrs.map(&:name)
      expect(attr_names).to include("GroupAttr1")
    end
  end

  describe "#base_type" do
    let(:simple_content_with_base) { complex_types.find { |ct| ct.name == "SimpleContentWithBase" } }
    let(:simple_content_with_restriction) { complex_types.find { |ct| ct.name == "SimpleContentWithRestriction" } }

    it "returns base from extension when present" do
      expect(simple_content.base_type).to eq("xs:string")
    end

    it "returns base from restriction when present" do
      expect(simple_content_with_restriction.simple_content.base_type).to eq("xs:string")
    end

    it "returns base attribute when extension and restriction are nil" do
      expect(simple_content_with_base.simple_content.base_type).to eq("xs:int")
    end

    it "returns nil when no base is specified" do
      sc = Lutaml::Xsd::SimpleContent.new(__register: Lutaml::Xsd.register)
      expect(sc.base_type).to be_nil
    end
  end
end
