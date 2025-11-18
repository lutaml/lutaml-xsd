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

  # Helper to create mock schema element that passes case statement checks
  def mock_schema_element(name:, min_occurs:, max_occurs:, target_namespace: nil)
    Object.new.tap do |obj|
      obj.define_singleton_method(:name) { name }
      obj.define_singleton_method(:min_occurs) { min_occurs }
      obj.define_singleton_method(:max_occurs) { max_occurs }
      obj.define_singleton_method(:target_namespace) { target_namespace }
      obj.define_singleton_method(:is_a?) do |klass|
        klass == Lutaml::Xsd::Element || super(klass)
      end
      obj.define_singleton_method(:kind_of?) do |klass|
        klass == Lutaml::Xsd::Element || super(klass)
      end
      obj.define_singleton_method(:instance_of?) do |klass|
        klass == Lutaml::Xsd::Element || super(klass)
      end
      obj.define_singleton_method(:class) { Lutaml::Xsd::Element }
    end
  end

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
      let(:moxml_element) do
        Struct.new(:name, :children).new("parent", [])
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with element occurrence constraints" do
      let(:child_moxml1) do
        obj = Struct.new(:name, :namespace).new("child", nil)
        obj.define_singleton_method(:element?) { true }
        obj
      end
      let(:child_moxml2) do
        obj = Struct.new(:name, :namespace).new("child", nil)
        obj.define_singleton_method(:element?) { true }
        obj
      end
      let(:moxml_children) { [child_moxml1, child_moxml2] }
      let(:moxml_element) do
        Struct.new(:name, :children, :namespace).new("parent", moxml_children, nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      context "when minOccurs is satisfied" do
        let(:schema_element) { mock_schema_element(name: "child", min_occurs: "1", max_occurs: "unbounded") }

        it "does not report min occurs error" do
          rule.validate(xml_element, schema_element, collector)

          min_errors = collector.errors.select { |e| e.code == "min_occurs_violation" }
          expect(min_errors).to be_empty
        end
      end

      context "when minOccurs is violated" do
        let(:moxml_child) do
          obj = Struct.new(:name, :namespace).new("child", nil)
          obj.define_singleton_method(:element?) { true }
          obj
        end
        let(:moxml_element) do
          Struct.new(:name, :children, :namespace).new("parent", [], nil)
        end
        let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }
        let(:schema_element) { mock_schema_element(name: "child", min_occurs: "2", max_occurs: "unbounded") }

        it "reports min occurs violation" do
          rule.validate(xml_element_empty, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at least 2 time(s)")
        end

        it "includes suggestion" do
          rule.validate(xml_element_empty, schema_element, collector)

          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error.suggestion).not_to be_nil
        end
      end

      context "when maxOccurs is violated" do
        let(:schema_element) { mock_schema_element(name: "child", min_occurs: "1", max_occurs: "1") }

        it "reports max occurs violation" do
          rule.validate(xml_element, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at most 1 time(s)")
        end

        it "includes suggestion to remove occurrences" do
          rule.validate(xml_element, schema_element, collector)

          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error.suggestion).to include("Remove")
        end
      end

      context "when maxOccurs is unbounded" do
        let(:many_children) do
          Array.new(100) do
            obj = Struct.new(:name, :namespace).new("child", nil)
            obj.define_singleton_method(:element?) { true }
            obj
          end
        end
        let(:moxml_element_many) do
          Struct.new(:name, :children, :namespace).new("parent", many_children, nil)
        end
        let(:xml_element_many) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element_many, navigator) }
        let(:schema_element) { mock_schema_element(name: "child", min_occurs: "1", max_occurs: "unbounded") }

        it "does not report max occurs error" do
          rule.validate(xml_element_many, schema_element, collector)

          max_errors = collector.errors.select { |e| e.code == "max_occurs_violation" }
          expect(max_errors).to be_empty
        end
      end
    end
  end
end