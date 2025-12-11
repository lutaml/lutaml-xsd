# frozen_string_literal: true

RSpec.describe Lutaml::Xsd::LiquidMethods::Element do
  let(:schema_xml) do
    <<~XML
      <schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
              targetNamespace="http://example.com/test"
              xmlns="http://example.com/test">
        <xs:element name="RootElement" type="RootType"/>
        <xs:element name="ReferencedElement" type="xs:string"/>
        <xs:element name="SimpleElement" type="xs:string"/>

        <xs:complexType name="RootType">
          <xs:sequence>
            <xs:element name="DirectChild" type="xs:string"/>
          </xs:sequence>
          <xs:attribute name="RootAttr" type="xs:string"/>
        </xs:complexType>

        <xs:complexType name="UsesRootType">
          <xs:sequence>
            <xs:element name="UsesRoot" type="RootType"/>
          </xs:sequence>
        </xs:complexType>
      </schema>
    XML
  end

  let(:schema) { Lutaml::Xsd.parse(schema_xml) }
  let(:root_element) { schema.element.find { |e| e.name == "RootElement" } }
  let(:referenced_element) { schema.element.find { |e| e.name == "ReferencedElement" } }
  let(:simple_element) { schema.element.find { |e| e.name == "SimpleElement" } }

  before do
    [root_element, referenced_element, simple_element].each do |el|
      el&.instance_variable_set(:@__root, schema)
    end
    schema.complex_type.each { |ct| ct.instance_variable_set(:@__root, schema) }
  end

  describe "#used_by" do
    it "returns complex types that use this element" do
      used_by = root_element.used_by
      expect(used_by).to be_an(Array)
    end
  end

  describe "#attributes" do
    it "returns attributes from the referenced complex type" do
      attrs = root_element.attributes
      expect(attrs).to be_an(Array)
      expect(attrs.map(&:name)).to include("RootAttr")
    end

    it "returns empty array when element does not reference a complex type" do
      attrs = simple_element.attributes
      expect(attrs).to be_nil
    end
  end

  describe "#child_elements" do
    it "returns child elements from the referenced complex type" do
      elements = root_element.child_elements
      expect(elements).to be_an(Array)
      expect(elements.map(&:name)).to include("DirectChild")
    end

    it "returns empty array when element does not reference a complex type" do
      elements = simple_element.child_elements
      expect(elements).to be_nil
    end
  end

  describe "#referenced_name" do
    it "returns the name when element has a name" do
      expect(root_element.referenced_name).to eq("RootElement")
    end

    it "returns the name of referenced element when using ref" do
      ref_element = Lutaml::Xsd::Element.new(__register: Lutaml::Xsd.register)
      ref_element.ref = "ReferencedElement"
      ref_element.instance_variable_set(:@__root, schema)
      expect(ref_element.referenced_name).to eq("ReferencedElement")
    end
  end

  describe "#referenced_type" do
    it "returns the type when element has a type" do
      expect(root_element.referenced_type).to eq("RootType")
    end

    it "returns the type of referenced element when using ref" do
      ref_element = Lutaml::Xsd::Element.new(__register: Lutaml::Xsd.register)
      ref_element.ref = "ReferencedElement"
      ref_element.instance_variable_set(:@__root, schema)
      expect(ref_element.referenced_type).to eq("xs:string")
    end
  end

  describe "#referenced_object" do
    it "returns self when element has a name" do
      expect(root_element.referenced_object).to eq(root_element)
    end

    it "returns the referenced element when using ref" do
      ref_element = Lutaml::Xsd::Element.new(__register: Lutaml::Xsd.register)
      ref_element.ref = "ReferencedElement"
      ref_element.instance_variable_set(:@__root, schema)
      expect(ref_element.referenced_object).to eq(referenced_element)
    end
  end

  describe "#referenced_complex_type" do
    it "returns the complex type when element references one" do
      ct = root_element.referenced_complex_type
      expect(ct).to be_a(Lutaml::Xsd::ComplexType)
      expect(ct.name).to eq("RootType")
    end

    it "returns nil when element does not reference a complex type" do
      expect(simple_element.referenced_complex_type).to be_nil
    end
  end
end
