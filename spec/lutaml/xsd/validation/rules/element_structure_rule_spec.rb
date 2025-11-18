# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/rules/element_structure_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "lutaml/xsd/element"

RSpec.describe Lutaml::Xsd::Validation::Rules::ElementStructureRule do
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
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: "/root/element") }
    let(:moxml_element) do
      instance_double(
        "Moxml::Element",
        name: "person",
        namespace: instance_double("Namespace", href: "http://example.com", prefix: "ex")
      )
    end
    let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

    context "when schema element is nil" do
      it "reports element not allowed error" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors.size).to eq(1)
        error = collector.errors.first
        expect(error.code).to eq("element_not_allowed")
        expect(error.message).to include("not allowed here")
      end

      it "includes element qualified name in error" do
        rule.validate(xml_element, nil, collector)

        error = collector.errors.first
        expect(error.message).to include("{http://example.com}person")
      end

      it "includes suggestion in error" do
        rule.validate(xml_element, nil, collector)

        error = collector.errors.first
        expect(error.suggestion).not_to be_nil
      end
    end

    context "when element name matches" do
      let(:schema_element) do
        Object.new.tap do |obj|
          obj.define_singleton_method(:name) { "person" }
          obj.define_singleton_method(:target_namespace) { "http://example.com" }
        end
      end

      it "does not report name mismatch error" do
        rule.validate(xml_element, schema_element, collector)

        name_errors = collector.errors.select { |e| e.code == "element_name_mismatch" }
        expect(name_errors).to be_empty
      end
    end

    context "when element name does not match" do
      let(:schema_element) do
        Object.new.tap do |obj|
          obj.define_singleton_method(:name) { "employee" }
          obj.define_singleton_method(:target_namespace) { "http://example.com" }
        end
      end

      it "reports name mismatch error" do
        rule.validate(xml_element, schema_element, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find { |e| e.code == "element_name_mismatch" }
        expect(error).not_to be_nil
        expect(error.message).to include("Expected element 'employee'")
        expect(error.message).to include("found 'person'")
      end
    end

    context "when namespace matches" do
      let(:schema_element) do
        Object.new.tap do |obj|
          obj.define_singleton_method(:name) { "person" }
          obj.define_singleton_method(:target_namespace) { "http://example.com" }
        end
      end

      it "does not report namespace error" do
        rule.validate(xml_element, schema_element, collector)

        ns_errors = collector.errors.select { |e| e.code == "namespace_mismatch" }
        expect(ns_errors).to be_empty
      end
    end

    context "when namespace does not match" do
      let(:schema_element) do
        Object.new.tap do |obj|
          obj.define_singleton_method(:name) { "person" }
          obj.define_singleton_method(:target_namespace) { "http://different.com" }
        end
      end

      it "reports namespace mismatch error" do
        rule.validate(xml_element, schema_element, collector)

        error = collector.errors.find { |e| e.code == "namespace_mismatch" }
        expect(error).not_to be_nil
        expect(error.message).to include("incorrect namespace")
      end

      it "includes expected and actual namespaces in context" do
        rule.validate(xml_element, schema_element, collector)

        error = collector.errors.find { |e| e.code == "namespace_mismatch" }
        expect(error.context[:expected_namespace]).to eq("http://different.com")
        expect(error.context[:actual_namespace]).to eq("http://example.com")
      end

      it "includes suggestion" do
        rule.validate(xml_element, schema_element, collector)

        error = collector.errors.find { |e| e.code == "namespace_mismatch" }
        expect(error.suggestion).not_to be_nil
      end
    end

    context "when both element and schema have no namespace" do
      let(:moxml_element_no_ns) do
        instance_double(
          "Moxml::Element",
          name: "person",
          namespace: nil
        )
      end
      let(:xml_element_no_ns) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element_no_ns, navigator) }
      let(:schema_element_no_ns) do
        Object.new.tap do |obj|
          obj.define_singleton_method(:name) { "person" }
          obj.define_singleton_method(:target_namespace) { nil }
        end
      end

      it "does not report namespace error" do
        rule.validate(xml_element_no_ns, schema_element_no_ns, collector)

        ns_errors = collector.errors.select { |e| e.code == "namespace_mismatch" }
        expect(ns_errors).to be_empty
      end
    end
  end
end