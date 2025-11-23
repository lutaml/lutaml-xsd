# frozen_string_literal: true

require 'spec_helper'
require 'lutaml/xsd'
require 'lutaml/xsd/validation/rules/attribute_validation_rule'
require 'lutaml/xsd/validation/result_collector'
require 'lutaml/xsd/validation/validation_configuration'
require 'lutaml/xsd/validation/xml_element'
require 'lutaml/xsd/validation/xml_attribute'
require 'lutaml/xsd/validation/xml_navigator'
require 'ostruct'

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  describe '#category' do
    it 'returns :constraint' do
      expect(rule.category).to eq(:constraint)
    end
  end

  describe '#description' do
    it 'returns a description' do
      expect(rule.description).to be_a(String)
      expect(rule.description).not_to be_empty
    end
  end

  describe '#validate' do
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: '/root/element') }

    context 'when schema element is nil' do
      let(:moxml_element) { instance_double('Moxml::Element', name: 'person', attributes: []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it 'does not validate' do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context 'with required attributes' do
      let(:xml_attrs) do
        [
          instance_double('Moxml::Attribute', name: 'id', value: '123', namespace: nil)
        ]
      end
      let(:moxml_element) do
        instance_double('Moxml::Element', name: 'person', attributes: xml_attrs, namespace: nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:required_attr) do
        instance_double(
          Lutaml::Xsd::Attribute,
          name: 'id',
          use: 'required'
        )
      end

      let(:complex_type) do
        instance_double(
          Lutaml::Xsd::ComplexType,
          attribute: [required_attr]
        )
      end

      let(:schema_element) do
        instance_double(
          Lutaml::Xsd::Element,
          name: 'person',
          complex_type: complex_type
        )
      end

      it 'does not report error when required attribute is present' do
        allow(complex_type).to receive(:respond_to?).with(:attribute).and_return(true)
        allow(complex_type).to receive(:respond_to?).with(:attribute_group).and_return(false)
        allow(complex_type).to receive(:respond_to?).with(:complex_content).and_return(false)
        allow(complex_type).to receive(:respond_to?).with(:simple_content).and_return(false)

        rule.validate(xml_element, schema_element, collector)

        required_errors = collector.errors.select { |e| e.code == 'required_attribute_missing' }
        expect(required_errors).to be_empty
      end
    end

    context 'with missing required attribute' do
      # Create a simple struct for moxml element
      let(:moxml_namespace) { Struct.new(:href, :prefix).new(nil, nil) }
      let(:moxml_element) do
        Struct.new(:name, :attributes, :namespace).new('person', [], moxml_namespace)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      # Create simple test objects that mimic the XSD structure
      let(:required_attr) do
        obj = Object.new
        obj.define_singleton_method(:name) { 'id' }
        obj.define_singleton_method(:use) { 'required' }
        obj.define_singleton_method(:respond_to?) do |method, include_private = false|
          %i[name use].include?(method) || super(method, include_private)
        end
        obj
      end

      let(:complex_type) do
        attr = required_attr
        obj = Object.new
        obj.define_singleton_method(:attribute) { [attr] }
        obj.define_singleton_method(:attribute_group) { [] }
        obj.define_singleton_method(:complex_content) { nil }
        obj.define_singleton_method(:simple_content) { nil }
        obj.define_singleton_method(:respond_to?) do |method, include_private = false|
          %i[attribute attribute_group complex_content
             simple_content].include?(method) || super(method, include_private)
        end
        obj
      end

      let(:schema_element) do
        ct = complex_type
        obj = Object.new
        obj.define_singleton_method(:name) { 'person' }
        obj.define_singleton_method(:complex_type) { ct }
        obj.define_singleton_method(:is_a?) do |klass|
          klass == Lutaml::Xsd::Element || super(klass)
        end
        obj.define_singleton_method(:respond_to?) do |method, include_private = false|
          %i[name complex_type].include?(method) || super(method, include_private)
        end
        obj
      end

      it 'reports required attribute missing error' do
        rule.validate(xml_element, schema_element, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find { |e| e.code == 'required_attribute_missing' }
        expect(error).not_to be_nil
        expect(error.message).to include("Required attribute 'id' is missing")
      end

      it 'includes suggestion' do
        rule.validate(xml_element, schema_element, collector)

        error = collector.errors.find { |e| e.code == 'required_attribute_missing' }
        expect(error.suggestion).not_to be_nil
        expect(error.suggestion).to include('id')
      end
    end
  end
end
