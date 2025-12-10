# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Schema do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:element name="GammaElement" type="xs:string"/>
        <xs:element name="AlphaElement" type="xs:string"/>
        <xs:element name="BetaElement" type="xs:string"/>

        <xs:complexType name="WidgetType">
          <xs:sequence>
            <xs:element ref="GammaElement"/>
          </xs:sequence>
        </xs:complexType>
        <xs:complexType name="AlphaType">
          <xs:sequence>
            <xs:element ref="AlphaElement"/>
          </xs:sequence>
        </xs:complexType>
        <xs:complexType name="BetaType">
          <xs:sequence>
            <xs:element ref="BetaElement"/>
          </xs:sequence>
        </xs:complexType>

        <xs:attributeGroup name="CoreAttributes">
          <xs:attribute name="id" type="xs:string"/>
        </xs:attributeGroup>
        <xs:attributeGroup name="BaseAttributes">
          <xs:attribute name="base" type="xs:string"/>
        </xs:attributeGroup>
        <xs:attributeGroup name="ZetaAttributes">
          <xs:attribute name="zeta" type="xs:string"/>
        </xs:attributeGroup>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }

  describe "#elements_sorted_by_name" do
    it "returns elements sorted alphabetically by name" do
      element_names = schema.elements_sorted_by_name.map(&:name)
      expect(element_names).to eq(%w[AlphaElement BetaElement GammaElement])
    end
  end

  describe "#complex_types_sorted_by_name" do
    it "returns complex types sorted alphabetically by name" do
      complex_type_names = schema.complex_types_sorted_by_name.map(&:name)
      expect(complex_type_names).to eq(%w[AlphaType BetaType WidgetType])
    end
  end

  describe "#attribute_groups_sorted_by_name" do
    it "returns attribute groups sorted alphabetically by name" do
      group_names = schema.attribute_groups_sorted_by_name.map(&:name)
      expect(group_names).to eq(%w[BaseAttributes CoreAttributes ZetaAttributes])
    end
  end
end
