# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Sequence do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:element name="DirectChild" type="xs:string"/>
        <xs:element name="ChoiceElement1" type="xs:string"/>
        <xs:element name="NestedSeqElement" type="xs:string"/>

        <xs:complexType name="RootType">
          <xs:sequence>
            <xs:element ref="DirectChild"/>
            <xs:choice>
              <xs:element ref="ChoiceElement1"/>
              <xs:element name="ChoiceElement2" type="xs:int"/>
            </xs:choice>
            <xs:sequence>
              <xs:element ref="NestedSeqElement"/>
            </xs:sequence>
          </xs:sequence>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:root_type) { schema.complex_type.find { |ct| ct.name == "RootType" } }
  let(:sequence) { root_type.sequence }

  describe "#child_elements" do
    it "returns all element children" do
      elements = sequence.child_elements
      expected_elements = %w[
        DirectChild
        ChoiceElement1
        ChoiceElement2
        NestedSeqElement
      ]
      expect(elements.length).to be >= 3
      expect(elements.map(&:referenced_name)).to include(*expected_elements)
    end

    it "handles nested sequences" do
      elements = sequence.child_elements
      expect(elements.map(&:referenced_name)).to include("NestedSeqElement")
    end

    it "accumulates elements in the provided array" do
      array = []
      sequence.child_elements(array)
      expect(array.length).to be >= 3
    end
  end

  describe "#find_elements_used" do
    it "returns true when element is used in sequence" do
      expect(sequence.find_elements_used("DirectChild")).to be true
    end

    it "returns false when element is not used" do
      expect(sequence.find_elements_used("NonExistent")).to be false
    end

    it "finds elements in nested structures" do
      expect(sequence.find_elements_used("ChoiceElement1")).to be true
      expect(sequence.find_elements_used("NestedSeqElement")).to be true
    end
  end
end
