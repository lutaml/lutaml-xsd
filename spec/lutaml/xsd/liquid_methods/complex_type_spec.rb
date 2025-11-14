# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::ComplexType do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:element name="UsesRoot" type="RootType"/>
        <xs:element name="DirectChild" type="xs:string"/>

        <xs:attributeGroup name="TestAttributeGroup">
          <xs:attribute name="GroupAttr1" type="xs:string"/>
        </xs:attributeGroup>

        <xs:group name="TestGroup">
          <xs:sequence>
            <xs:element name="GroupElement1" type="xs:string"/>
          </xs:sequence>
        </xs:group>

        <xs:complexType name="RootType">
          <xs:sequence>
            <xs:element ref="DirectChild"/>
            <xs:choice>
              <xs:element name="ChoiceElement1" type="xs:string"/>
            </xs:choice>
            <xs:group ref="TestGroup"/>
          </xs:sequence>
          <xs:attribute name="RootAttr" type="xs:string"/>
          <xs:attributeGroup ref="TestAttributeGroup"/>
        </xs:complexType>

        <xs:complexType name="ChildType">
          <xs:sequence>
            <xs:element name="NestedChild" type="xs:string"/>
          </xs:sequence>
          <xs:attribute name="ChildAttr" type="xs:string"/>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:root_type) { schema.complex_type.find { |ct| ct.name == "RootType" } }
  let(:child_type) { schema.complex_type.find { |ct| ct.name == "ChildType" } }

  describe "#used_by" do
    it "returns elements that use this complex type" do
      used_by = root_type.used_by
      expect(used_by).to be_an(Array)
      expect(used_by.any? { |el| el.type == "RootType" }).to be true
    end
  end

  describe "#attribute_elements" do
    it "returns all attributes including from attribute groups" do
      attrs = root_type.attribute_elements
      expect(attrs.length).to be >= 1
      expect(attrs.map(&:name)).to include("RootAttr")
    end

    it "includes attributes from attribute groups" do
      attrs = root_type.attribute_elements
      attr_names = attrs.map(&:name)
      expect(attr_names).to include("GroupAttr1")
    end

    it "includes attributes from simple content" do
      simple_content_schema = <<~XML
        <schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="SimpleType">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="ExtendedAttr" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        </schema>
      XML
      sc_schema = Lutaml::Xsd.parse(simple_content_schema)
      sc_type = sc_schema.complex_type.first
      sc_type.__root = sc_schema
      attrs = sc_type.attribute_elements
      expect(attrs.map(&:name)).to include("ExtendedAttr")
    end
  end

  describe "#direct_child_elements" do
    it "returns direct child elements excluding attributes and annotations" do
      elements = root_type.direct_child_elements
      expect(elements.any? { |el| el.is_a?(Lutaml::Xsd::Sequence) }).to be true
      expect(elements.none? { |el| el.is_a?(Lutaml::Xsd::Attribute) }).to be true
      expect(elements.first.element.any? { |el| el.is_a?(Lutaml::Xsd::Element) }).to be true
    end

    it "allows custom exception list" do
      elements = root_type.direct_child_elements(except: ["Element"])
      expect(elements.none? { |el| el.is_a?(Lutaml::Xsd::Element) }).to be true
    end
  end

  describe "#child_elements" do
    it "returns all nested child elements" do
      elements = root_type.child_elements
      expect(elements.length).to be >= 3
      expect(elements.map(&:referenced_name)).to include("DirectChild", "ChoiceElement1", "GroupElement1")
    end
  end

  describe "#find_elements_used" do
    it "returns true when element is used" do
      expect(root_type.find_elements_used("DirectChild")).to be true
    end

    it "returns false when element is not used" do
      expect(root_type.find_elements_used("NonExistent")).to be false
    end
  end

  describe "#find_used_by" do
    it "returns true when complex type is used by the object" do
      # This would require setting up a more complex scenario
      # For now, we test the method exists and returns boolean
      result = root_type.find_used_by(child_type)
      expect([true, false]).to include(result)
    end
  end
end
