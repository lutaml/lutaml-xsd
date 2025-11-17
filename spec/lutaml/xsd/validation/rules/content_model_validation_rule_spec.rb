# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
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
    let(:navigator) do
      Object.new.tap do |nav|
        nav.define_singleton_method(:current_xpath) { "/root" }
      end
    end

    context "when schema definition is nil" do
      let(:moxml_element) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "parent" }
          el.define_singleton_method(:children) { [] }
        end
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with sequence content model" do
      let(:moxml_namespace) { Struct.new(:href, :prefix).new(nil, nil) }

      let(:child1_moxml) { Struct.new(:name, :namespace, :element?).new("first", moxml_namespace, true) }
      let(:child2_moxml) { Struct.new(:name, :namespace, :element?).new("second", moxml_namespace, true) }
      let(:moxml_children) { [child1_moxml, child2_moxml] }
      let(:moxml_element) { Struct.new(:name, :children, :namespace).new("parent", moxml_children, moxml_namespace) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema_element1) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "first" }
          el.define_singleton_method(:min_occurs) { "1" }
          el.define_singleton_method(:max_occurs) { "1" }
          el.define_singleton_method(:target_namespace) { nil }
          el.define_singleton_method(:schema) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:name, :min_occurs, :max_occurs, :target_namespace, :schema].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:schema_element2) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "second" }
          el.define_singleton_method(:min_occurs) { "1" }
          el.define_singleton_method(:max_occurs) { "1" }
          el.define_singleton_method(:target_namespace) { nil }
          el.define_singleton_method(:schema) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:name, :min_occurs, :max_occurs, :target_namespace, :schema].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:sequence) do
        el1 = schema_element1
        el2 = schema_element2
        # Use allocate to create instance without initialization
        seq = Lutaml::Xsd::Sequence.allocate
        seq.define_singleton_method(:element) { [el1, el2] }
        seq.define_singleton_method(:min_occurs) { nil }
        seq.define_singleton_method(:max_occurs) { nil }
        seq
      end

      let(:complex_type) do
        seq = sequence
        Object.new.tap do |ct|
          ct.define_singleton_method(:sequence) { seq }
          ct.define_singleton_method(:choice) { nil }
          ct.define_singleton_method(:all) { nil }
          ct.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:sequence, :choice, :all, :complex_content].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:schema_def) do
        ct = complex_type
        Object.new.tap do |el|
          el.define_singleton_method(:complex_type) { ct }
          el.define_singleton_method(:simple_type) { nil }
          el.define_singleton_method(:type) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:complex_type, :simple_type, :type].include?(method)
            super(method, include_private)
          end
        end
      end

      it "validates sequence order" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for correct sequence
        sequence_errors = collector.errors.select { |e| e.code.include?("sequence") }
        expect(sequence_errors).to be_empty
      end
    end

    context "with choice content model" do
      let(:moxml_namespace) { Struct.new(:href, :prefix).new(nil, nil) }

      let(:child_moxml) { Struct.new(:name, :namespace, :element?).new("option1", moxml_namespace, true) }
      let(:moxml_children) { [child_moxml] }
      let(:moxml_element) { Struct.new(:name, :children, :namespace).new("parent", moxml_children, moxml_namespace) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:option1) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "option1" }
          el.define_singleton_method(:min_occurs) { "1" }
          el.define_singleton_method(:max_occurs) { "1" }
          el.define_singleton_method(:target_namespace) { nil }
          el.define_singleton_method(:schema) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:name, :min_occurs, :max_occurs, :target_namespace, :schema].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:option2) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "option2" }
          el.define_singleton_method(:min_occurs) { "1" }
          el.define_singleton_method(:max_occurs) { "1" }
          el.define_singleton_method(:target_namespace) { nil }
          el.define_singleton_method(:schema) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:name, :min_occurs, :max_occurs, :target_namespace, :schema].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:choice) do
        opt1 = option1
        opt2 = option2
        # Use allocate to create instance without initialization
        ch = Lutaml::Xsd::Choice.allocate
        ch.define_singleton_method(:element) { [opt1, opt2] }
        ch.define_singleton_method(:min_occurs) { "1" }
        ch.define_singleton_method(:max_occurs) { "1" }
        ch
      end

      let(:complex_type) do
        ch = choice
        Object.new.tap do |ct|
          ct.define_singleton_method(:sequence) { nil }
          ct.define_singleton_method(:choice) { ch }
          ct.define_singleton_method(:all) { nil }
          ct.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:sequence, :choice, :all, :complex_content].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:schema_def) do
        ct = complex_type
        Object.new.tap do |el|
          el.define_singleton_method(:complex_type) { ct }
          el.define_singleton_method(:simple_type) { nil }
          el.define_singleton_method(:type) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:complex_type, :simple_type, :type].include?(method)
            super(method, include_private)
          end
        end
      end

      it "validates choice alternatives" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for valid choice
        choice_errors = collector.errors.select { |e| e.code.include?("choice") }
        expect(choice_errors).to be_empty
      end
    end

    context "when choice is not satisfied" do
      let(:moxml_namespace) { Struct.new(:href, :prefix).new(nil, nil) }
      let(:moxml_element) { Struct.new(:name, :children, :namespace).new("parent", [], moxml_namespace) }
      let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:option1) do
        Object.new.tap do |el|
          el.define_singleton_method(:name) { "option1" }
          el.define_singleton_method(:target_namespace) { nil }
          el.define_singleton_method(:schema) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:name, :target_namespace, :schema].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:choice) do
        opt1 = option1
        # Use allocate to create instance without initialization
        ch = Lutaml::Xsd::Choice.allocate
        ch.define_singleton_method(:element) { [opt1] }
        ch.define_singleton_method(:min_occurs) { "1" }
        ch.define_singleton_method(:max_occurs) { "1" }
        ch
      end

      let(:complex_type) do
        ch = choice
        Object.new.tap do |ct|
          ct.define_singleton_method(:sequence) { nil }
          ct.define_singleton_method(:choice) { ch }
          ct.define_singleton_method(:all) { nil }
          ct.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:sequence, :choice, :all, :complex_content].include?(method)
            super(method, include_private)
          end
        end
      end

      let(:schema_def) do
        ct = complex_type
        Object.new.tap do |el|
          el.define_singleton_method(:complex_type) { ct }
          el.define_singleton_method(:simple_type) { nil }
          el.define_singleton_method(:type) { nil }
          el.define_singleton_method(:is_a?) do |klass|
            klass == Lutaml::Xsd::Element || super(klass)
          end
          el.define_singleton_method(:respond_to?) do |method, include_private = false|
            return true if [:complex_type, :simple_type, :type].include?(method)
            super(method, include_private)
          end
        end
      end

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