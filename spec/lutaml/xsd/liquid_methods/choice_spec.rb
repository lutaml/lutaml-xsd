# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Choice do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:complexType name="RootType">
          <xs:sequence>
            <xs:choice>
              <xs:element name="ChoiceElement1" type="xs:string"/>
              <xs:element name="ChoiceElement2" type="xs:int"/>
            </xs:choice>
          </xs:sequence>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:root_type) { schema.complex_type.find { |ct| ct.name == "RootType" } }
  let(:choice) { root_type.sequence.choice.first }

  describe "#child_elements" do
    it "returns all element children" do
      elements = choice.child_elements
      expect(elements.length).to eq(2)
      expect(elements.map(&:name)).to contain_exactly("ChoiceElement1", "ChoiceElement2")
    end

    it "accumulates elements in the provided array" do
      expect(choice.child_elements.length).to eq(2)
    end

    it "handles nested structures" do
      nested_schema_xml = <<~XML
        <schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="NestedType">
            <xs:choice>
              <xs:sequence>
                <xs:element name="NestedElement" type="xs:string"/>
              </xs:sequence>
            </xs:choice>
          </xs:complexType>
        </schema>
      XML
      nested_schema = Lutaml::Xsd.parse(nested_schema_xml)
      nested_choice = nested_schema.complex_type&.first&.choice&.sequence&.first
      elements = nested_choice.child_elements
      expect(elements.map(&:name)).to include("NestedElement")
    end
  end

  describe "#find_elements_used" do
    let(:schema_xml_ref_element) do
      <<~XML
        <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                targetNamespace="http://example.com/test"
                xmlns="http://example.com/test">
          <xs:element name="Element1" type="xsd:string"/>
          <xs:complexType name="RootType">
            <xs:sequence>
              <xs:choice>
                <xs:element name="ChoiceElement1" type="xs:string"/>
                <xs:element name="ChoiceElement2" type="xs:int"/>
                <xs:element ref="Element1"/>
              </xs:choice>
            </xs:sequence>
          </xs:complexType>
        </schema>
      XML
    end

    it "returns true when element is used in choice" do
      choice = Lutaml::Xsd.parse(schema_xml_ref_element).complex_type.first.sequence.choice.first
      expect(choice.find_elements_used("Element1")).to be true
    end

    it "returns false when element is not used" do
      expect(choice.find_elements_used("NonExistent")).to be false
    end
  end
end
