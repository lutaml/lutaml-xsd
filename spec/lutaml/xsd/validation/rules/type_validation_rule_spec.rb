# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/rules/type_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "lutaml/xsd/element"
require "lutaml/xsd/simple_type"
require "lutaml/xsd/complex_type"

RSpec.describe Lutaml::Xsd::Validation::Rules::TypeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  describe "#category" do
    it "returns :type" do
      expect(rule.category).to eq(:type)
    end
  end

  describe "#description" do
    it "returns a description" do
      expect(rule.description).to be_a(String)
      expect(rule.description).not_to be_empty
    end
  end

  describe "#validate" do
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: "/root/element") }
    let(:moxml_element) do
      instance_double(
        "Moxml::Element",
        name: "count",
        namespace: nil,
        text: "42",
      )
    end
    let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

    context "when schema element is nil" do
      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with simple type" do
      let(:schema_element) do
        simple_type = instance_double(Lutaml::Xsd::SimpleType)
        instance_double(
          Lutaml::Xsd::Element,
          name: "count",
          simple_type: simple_type,
          complex_type: nil,
          type: nil,
        )
      end

      it "validates simple type content" do
        rule.validate(xml_element, schema_element, collector)

        # No errors expected for basic simple type
        expect(collector.errors).to be_empty
      end
    end

    context "with complex type" do
      let(:schema_element) do
        complex_type = instance_double(Lutaml::Xsd::ComplexType)
        instance_double(
          Lutaml::Xsd::Element,
          name: "person",
          simple_type: nil,
          complex_type: complex_type,
          type: nil,
        )
      end

      it "validates complex type content" do
        allow(schema_element.complex_type).to receive(:respond_to?).with(:simple_content).and_return(false)
        allow(schema_element.complex_type).to receive(:respond_to?).with(:sequence).and_return(false)
        allow(schema_element.complex_type).to receive(:respond_to?).with(:choice).and_return(false)
        allow(schema_element.complex_type).to receive(:respond_to?).with(:all).and_return(false)

        rule.validate(xml_element, schema_element, collector)

        # Complex type validation is delegated to other rules
        expect(collector.errors).to be_empty
      end
    end
  end
end
