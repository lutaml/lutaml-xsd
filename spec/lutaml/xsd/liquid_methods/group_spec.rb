# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Group do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:element name="GroupElement1" type="xs:string"/>
        <xs:element name="NestedElement" type="xs:string"/>
        <xs:element name="NestedSeqElement" type="xs:string"/>

        <xs:group name="TestGroup">
          <xs:sequence>
            <xs:element ref="GroupElement1"/>
            <xs:element name="GroupElement2" type="xs:int"/>
          </xs:sequence>
        </xs:group>

        <xs:group name="NestedGroup">
          <xs:choice>
            <xs:element ref="NestedElement"/>
            <xs:sequence>
              <xs:element ref="NestedSeqElement"/>
            </xs:sequence>
          </xs:choice>
        </xs:group>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:test_group) { schema.group.find { |g| g.name == "TestGroup" } }
  let(:nested_group) { schema.group.find { |g| g.name == "NestedGroup" } }

  describe "#child_elements" do
    it "returns all element children" do
      elements = test_group.child_elements
      expect(elements.length).to eq(2)
      expect(elements.map(&:referenced_name)).to contain_exactly("GroupElement1", "GroupElement2")
    end

    it "handles nested structures" do
      elements = nested_group.child_elements
      expect(elements.map(&:referenced_name)).to include("NestedElement", "NestedSeqElement")
    end

    it "accumulates elements in the provided array" do
      array = []
      test_group.child_elements(array)
      expect(array.length).to eq(2)
    end
  end

  describe "#find_elements_used" do
    it "returns true when element is used in group" do
      expect(test_group.find_elements_used("GroupElement1")).to be true
    end

    it "returns false when element is not used" do
      expect(test_group.find_elements_used("NonExistent")).to be false
    end

    it "finds elements in nested structures" do
      expect(nested_group.find_elements_used("NestedElement")).to be true
      expect(nested_group.find_elements_used("NestedSeqElement")).to be true
    end
  end

  describe "#referenced_object" do
    it "returns self when group has a name" do
      expect(test_group.referenced_object).to eq(test_group)
    end

    it "returns the referenced group when using ref" do
      ref_group = Lutaml::Xsd::Group.new(__register: Lutaml::Xsd.register)
      ref_group.ref = "TestGroup"
      ref_group.instance_variable_set(:@__root, schema)
      expect(ref_group.referenced_object).to eq(test_group)
    end
  end
end
