# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/rules/content_model_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "lutaml/xsd/element"
require "lutaml/xsd/sequence"
require "lutaml/xsd/choice"
require "lutaml/xsd/all"
require "lutaml/xsd/complex_type"

RSpec.describe Lutaml::Xsd::Validation::Rules::ContentModelValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

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
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: "/root") }

    context "when schema definition is nil" do
      let(:moxml_element) { instance_double("Moxml::Element", name: "parent", children: []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with sequence content model" do
      let(:child1_moxml) { instance_double("Moxml::Element", name: "first", namespace: nil, element?: true) }
      let(:child2_moxml) { instance_double("Moxml::Element", name: "second", namespace: nil, element?: true) }
      let(:moxml_children) { [child1_moxml, child2_moxml] }
      let(:moxml_element) do
        instance_double("Moxml::Element", name: "parent", children: moxml_children, namespace: nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema_element1) do
        instance_double(
          Lutaml::Xsd::Element,
          name: "first",
          min_occurs: "1",
          max_occurs: "1",
          target_namespace: nil
        )
      end

      let(:schema_element2) do
        instance_double(
          Lutaml::Xsd::Element,
          name: "second",
          min_occurs: "1",
          max_occurs: "1",
          target_namespace: nil
        )
      end

      let(:sequence) do
        instance_double(
          Lutaml::Xsd::Sequence,
          element: [schema_element1, schema_element2],
          min_occurs: nil,
          max_occurs: nil
        )
      end

      let(:complex_type) do
        instance_double(
          Lutaml::Xsd::ComplexType,
          sequence: sequence,
          choice: nil,
          all: nil
        )
      end

      let(:schema_def) do
        instance_double(
          Lutaml::Xsd::Element,
          complex_type: complex_type,
          simple_type: nil,
          type: nil
        )
      end

      it "validates sequence order" do
        allow(complex_type).to receive(:respond_to?).with(:sequence).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:choice).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:all).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:complex_content).and_return(false)
        allow(sequence).to receive(:respond_to?).with(:element).and_return(true)
        allow(sequence).to receive(:respond_to?).with(:sequence).and_return(false)
        allow(sequence).to receive(:respond_to?).with(:choice).and_return(false)
        allow(sequence).to receive(:respond_to?).with(:group).and_return(false)
        allow(schema_element1).to receive(:respond_to?).with(:target_namespace).and_return(false)
        allow(schema_element1).to receive(:respond_to?).with(:schema).and_return(false)
        allow(schema_element2).to receive(:respond_to?).with(:target_namespace).and_return(false)
        allow(schema_element2).to receive(:respond_to?).with(:schema).and_return(false)

        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for correct sequence
        sequence_errors = collector.errors.select { |e| e.code.include?("sequence") }
        expect(sequence_errors).to be_empty
      end
    end

    context "with choice content model" do
      let(:child_moxml) { instance_double("Moxml::Element", name: "option1", namespace: nil, element?: true) }
      let(:moxml_children) { [child_moxml] }
      let(:moxml_element) do
        instance_double("Moxml::Element", name: "parent", children: moxml_children, namespace: nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:option1) do
        instance_double(
          Lutaml::Xsd::Element,
          name: "option1",
          min_occurs: "1",
          max_occurs: "1",
          target_namespace: nil
        )
      end

      let(:option2) do
        instance_double(
          Lutaml::Xsd::Element,
          name: "option2",
          min_occurs: "1",
          max_occurs: "1",
          target_namespace: nil
        )
      end

      let(:choice) do
        instance_double(
          Lutaml::Xsd::Choice,
          element: [option1, option2],
          min_occurs: "1",
          max_occurs: "1"
        )
      end

      let(:complex_type) do
        instance_double(
          Lutaml::Xsd::ComplexType,
          sequence: nil,
          choice: choice,
          all: nil
        )
      end

      let(:schema_def) do
        instance_double(
          Lutaml::Xsd::Element,
          complex_type: complex_type,
          simple_type: nil,
          type: nil
        )
      end

      it "validates choice alternatives" do
        allow(complex_type).to receive(:respond_to?).with(:sequence).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:choice).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:all).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:complex_content).and_return(false)
        allow(choice).to receive(:respond_to?).with(:element).and_return(true)
        allow(choice).to receive(:respond_to?).with(:sequence).and_return(false)
        allow(choice).to receive(:respond_to?).with(:choice).and_return(false)
        allow(choice).to receive(:respond_to?).with(:group).and_return(false)
        allow(option1).to receive(:respond_to?).with(:target_namespace).and_return(false)
        allow(option1).to receive(:respond_to?).with(:schema).and_return(false)
        allow(option2).to receive(:respond_to?).with(:target_namespace).and_return(false)
        allow(option2).to receive(:respond_to?).with(:schema).and_return(false)

        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for valid choice
        choice_errors = collector.errors.select { |e| e.code.include?("choice") }
        expect(choice_errors).to be_empty
      end
    end

    context "when choice is not satisfied" do
      let(:moxml_element) do
        instance_double("Moxml::Element", name: "parent", children: [], namespace: nil)
      end
      let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:option1) do
        instance_double(
          Lutaml::Xsd::Element,
          name: "option1",
          target_namespace: nil
        )
      end

      let(:choice) do
        instance_double(
          Lutaml::Xsd::Choice,
          element: [option1],
          min_occurs: "1",
          max_occurs: "1"
        )
      end

      let(:complex_type) do
        instance_double(
          Lutaml::Xsd::ComplexType,
          sequence: nil,
          choice: choice,
          all: nil
        )
      end

      let(:schema_def) do
        instance_double(
          Lutaml::Xsd::Element,
          complex_type: complex_type,
          simple_type: nil,
          type: nil
        )
      end

      it "reports choice not satisfied error" do
        allow(complex_type).to receive(:respond_to?).with(:sequence).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:choice).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:all).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:complex_content).and_return(false)
        allow(choice).to receive(:respond_to?).with(:element).and_return(true)
        allow(choice).to receive(:respond_to?).with(:sequence).and_return(false)
        allow(choice).to receive(:respond_to?).with(:choice).and_return(false)
        allow(choice).to receive(:respond_to?).with(:group).and_return(false)
        allow(option1).to receive(:respond_to?).with(:name).and_return(true)

        rule.validate(xml_element_empty, schema_def, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find { |e| e.code == "choice_not_satisfied" }
        expect(error).not_to be_nil
        expect(error.message).to include("must be present")
      end
    end
  end
end