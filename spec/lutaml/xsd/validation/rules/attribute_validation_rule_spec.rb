# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/attribute_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_attribute"
require "lutaml/xsd/validation/xml_navigator"

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  describe "#category" do
    it "returns :constraint" do
      expect(rule.category).to eq(:constraint)
    end
  end

  describe "#description" do
    it "returns a description" do
      expect(rule.description).to be_a(String)
      expect(rule.description).not_to be_empty
    end
  end

  describe "#validate" do
    # Lightweight stub navigator: only needs to expose current_xpath.
    let(:navigator) { Struct.new(:current_xpath).new("/root/element") }

    # Lightweight value objects representing a Moxml attribute / element /
    # namespace. Using Structs keeps the test double-free while satisfying
    # the surface area that XmlElement and XmlAttribute touch.
    let(:moxml_namespace) { Struct.new(:href, :prefix) }

    let(:moxml_attribute_class) do
      Struct.new(:name, :value, :namespace) do
        # XmlElement#attributes maps over Moxml attributes and accesses
        # namespace&.href / namespace&.prefix, which Structs already provide.
      end
    end

    let(:moxml_element_class) do
      Struct.new(:name, :attributes, :namespace)
    end

    let(:xsd_attribute) do
      Lutaml::Xml::Schema::Xsd::Attribute.new.tap do |attr|
        attr.name = "id"
        attr.use = "required"
      end
    end

    let(:xsd_complex_type) do
      Lutaml::Xml::Schema::Xsd::ComplexType.new.tap do |ct|
        ct.attribute = [xsd_attribute]
      end
    end

    let(:xsd_schema_element) do
      Lutaml::Xml::Schema::Xsd::Element.new.tap do |el|
        el.name = "person"
        el.complex_type = xsd_complex_type
      end
    end

    context "when schema element is nil" do
      let(:moxml_element) { moxml_element_class.new("person", [], nil) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with required attributes" do
      let(:xml_attrs) do
        [
          moxml_attribute_class.new("id", "123", moxml_namespace.new(nil, nil)),
        ]
      end
      let(:moxml_element) do
        moxml_element_class.new("person", xml_attrs, moxml_namespace.new(nil, nil))
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not report error when required attribute is present" do
        rule.validate(xml_element, xsd_schema_element, collector)

        required_errors = collector.errors.select do |e|
          e.code == "required_attribute_missing"
        end
        expect(required_errors).to be_empty
      end
    end

    context "with missing required attribute" do
      let(:moxml_element) do
        moxml_element_class.new("person", [], moxml_namespace.new(nil, nil))
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "reports required attribute missing error" do
        rule.validate(xml_element, xsd_schema_element, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error).not_to be_nil
        expect(error.message).to include("Required attribute 'id' is missing")
      end

      it "includes suggestion" do
        rule.validate(xml_element, xsd_schema_element, collector)

        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error.suggestion).not_to be_nil
        expect(error.suggestion).to include("id")
      end
    end
  end
end
