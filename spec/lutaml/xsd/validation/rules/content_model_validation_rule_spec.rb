# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/content_model_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "moxml"

RSpec.describe Lutaml::Xsd::Validation::Rules::ContentModelValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  # Helper to create a moxml element with children
  def create_moxml_element(name, children = [])
    Struct.new(:name, :children, :namespace).new(name, children, nil)
  end

  # Helper to create a moxml child element
  def create_moxml_child(name)
    child = Struct.new(:name, :namespace).new(name, nil)
    child.define_singleton_method(:element?) { true }
    child
  end

  describe "#category" do
    it "returns :structure" do
      expect(rule.category).to eq(:structure)
    end
  end

  describe "#description" do
    it "returns a description" do
      expect(rule.description).to be_a(String)
      expect(rule.description).not_to be_empty
    end
  end

  describe "#validate" do
    let(:navigator) do
      Object.new.tap do |nav|
        nav.define_singleton_method(:current_xpath) { "/root" }
      end
    end

    context "when schema definition is nil" do
      let(:moxml_element) { create_moxml_element("parent", []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with sequence content model" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:sequence>
                  <xs:element name="first" type="xs:string" minOccurs="1"/>
                  <xs:element name="second" type="xs:string" minOccurs="1"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:child1) { create_moxml_child("first") }
      let(:child2) { create_moxml_child("second") }
      let(:moxml_element) { create_moxml_element("parent", [child1, child2]) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "validates sequence order" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for correct sequence
        sequence_errors = collector.errors.select { |e| e.code.include?("sequence") }
        expect(sequence_errors).to be_empty
      end
    end

    context "with choice content model" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:choice>
                  <xs:element name="option1" type="xs:string"/>
                  <xs:element name="option2" type="xs:string"/>
                </xs:choice>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:child1) { create_moxml_child("option1") }
      let(:moxml_element) { create_moxml_element("parent", [child1]) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "validates choice alternatives" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for valid choice
        choice_errors = collector.errors.select { |e| e.code.include?("choice") }
        expect(choice_errors).to be_empty
      end
    end

    context "when choice is not satisfied" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:choice>
                  <xs:element name="option1" type="xs:string"/>
                </xs:choice>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:moxml_element) { create_moxml_element("parent", []) }
      let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "reports choice not satisfied error" do
        rule.validate(xml_element_empty, schema_def, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find { |e| e.code == "choice_not_satisfied" }
        expect(error).not_to be_nil
        expect(error.message).to include("must be present")
      end
    end
  end
end