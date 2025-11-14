# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/rules/occurrence_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "lutaml/xsd/element"
require "lutaml/xsd/sequence"

RSpec.describe Lutaml::Xsd::Validation::Rules::OccurrenceValidationRule do
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
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: "/root") }

    context "when schema particle is nil" do
      let(:moxml_element) { instance_double("Moxml::Element", name: "parent", children: []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with element occurrence constraints" do
      let(:child_moxml1) { instance_double("Moxml::Element", name: "child", namespace: nil, element?: true) }
      let(:child_moxml2) { instance_double("Moxml::Element", name: "child", namespace: nil, element?: true) }
      let(:moxml_children) { [child_moxml1, child_moxml2] }
      let(:moxml_element) do
        instance_double("Moxml::Element", name: "parent", children: moxml_children, namespace: nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      context "when minOccurs is satisfied" do
        let(:schema_element) do
          instance_double(
            Lutaml::Xsd::Element,
            name: "child",
            min_occurs: "1",
            max_occurs: "unbounded",
            target_namespace: nil
          )
        end

        it "does not report min occurs error" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element, schema_element, collector)

          min_errors = collector.errors.select { |e| e.code == "min_occurs_violation" }
          expect(min_errors).to be_empty
        end
      end

      context "when minOccurs is violated" do
        let(:moxml_element) do
          instance_double("Moxml::Element", name: "parent", children: [], namespace: nil)
        end
        let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }
        let(:schema_element) do
          instance_double(
            Lutaml::Xsd::Element,
            name: "child",
            min_occurs: "2",
            max_occurs: "unbounded",
            target_namespace: nil
          )
        end

        it "reports min occurs violation" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element_empty, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at least 2 time(s)")
        end

        it "includes suggestion" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element_empty, schema_element, collector)

          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error.suggestion).not_to be_nil
        end
      end

      context "when maxOccurs is violated" do
        let(:schema_element) do
          instance_double(
            Lutaml::Xsd::Element,
            name: "child",
            min_occurs: "1",
            max_occurs: "1",
            target_namespace: nil
          )
        end

        it "reports max occurs violation" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at most 1 time(s)")
        end

        it "includes suggestion to remove occurrences" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element, schema_element, collector)

          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error.suggestion).to include("Remove")
        end
      end

      context "when maxOccurs is unbounded" do
        let(:many_children) { Array.new(100) { instance_double("Moxml::Element", name: "child", namespace: nil, element?: true) } }
        let(:moxml_element_many) do
          instance_double("Moxml::Element", name: "parent", children: many_children, namespace: nil)
        end
        let(:xml_element_many) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element_many, navigator) }
        let(:schema_element) do
          instance_double(
            Lutaml::Xsd::Element,
            name: "child",
            min_occurs: "1",
            max_occurs: "unbounded",
            target_namespace: nil
          )
        end

        it "does not report max occurs error" do
          allow(schema_element).to receive(:respond_to?).with(:target_namespace).and_return(false)
          allow(schema_element).to receive(:respond_to?).with(:schema).and_return(false)

          rule.validate(xml_element_many, schema_element, collector)

          max_errors = collector.errors.select { |e| e.code == "max_occurs_violation" }
          expect(max_errors).to be_empty
        end
      end
    end
  end
end