# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/attribute_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_attribute"
require "lutaml/xsd/validation/xml_navigator"
require "ostruct"

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
    let(:navigator) { instance_double(Lutaml::Xsd::Validation::XmlNavigator, current_xpath: "/root/element") }

    context "when schema element is nil" do
      let(:moxml_element) { instance_double("Moxml::Element", name: "person", attributes: []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with required attributes" do
      let(:xml_attrs) do
        [
          instance_double("Moxml::Attribute", name: "id", value: "123",
                                              namespace: nil),
        ]
      end
      let(:moxml_element) do
        instance_double("Moxml::Element", name: "person",
                                          attributes: xml_attrs, namespace: nil)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:required_attr) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Attribute,
          name: "id",
          use: "required",
        )
      end

      let(:complex_type) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::ComplexType,
          attribute: [required_attr],
        )
      end

      let(:schema_element) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Element,
          name: "person",
          complex_type: complex_type,
        )
      end

      it "does not report error when required attribute is present" do
        allow(complex_type).to receive(:attribute).and_return([required_attr])
        allow(complex_type).to receive(:attribute_group).and_return([])
        allow(complex_type).to receive(:complex_content).and_return(nil)
        allow(complex_type).to receive(:simple_content).and_return(nil)
        allow(schema_element).to receive(:is_a?).and_return(false)
        allow(schema_element).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::Element).and_return(true)
        allow(complex_type).to receive(:is_a?).and_return(false)
        allow(complex_type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(true)
        allow(required_attr).to receive(:fixed).and_return(nil)
        allow(required_attr).to receive(:default).and_return(nil)

        rule.validate(xml_element, schema_element, collector)

        required_errors = collector.errors.select do |e|
          e.code == "required_attribute_missing"
        end
        expect(required_errors).to be_empty
      end
    end

    context "with missing required attribute" do
      # Create a simple struct for moxml element
      let(:moxml_namespace) { Struct.new(:href, :prefix).new(nil, nil) }
      let(:moxml_element) do
        Struct.new(:name, :attributes, :namespace).new("person", [],
                                                       moxml_namespace)
      end
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      # Create simple test objects that mimic the XSD structure
      let(:required_attr) do
        obj = Object.new
        obj.define_singleton_method(:name) { "id" }
        obj.define_singleton_method(:use) { "required" }
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
        obj.define_singleton_method(:name) { "person" }
        obj.define_singleton_method(:complex_type) { ct }
        obj.define_singleton_method(:is_a?) do |klass|
          klass == Lutaml::Xml::Schema::Xsd::Element || super(klass)
        end
        obj.define_singleton_method(:respond_to?) do |method, include_private = false|
          %i[name
             complex_type].include?(method) || super(method, include_private)
        end
        obj
      end

      it "reports required attribute missing error" do
        rule.validate(xml_element, schema_element, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error).not_to be_nil
        expect(error.message).to include("Required attribute 'id' is missing")
      end

      it "includes suggestion" do
        rule.validate(xml_element, schema_element, collector)

        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error.suggestion).not_to be_nil
        expect(error.suggestion).to include("id")
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule,
               "xs:anyAttribute wildcard handling" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }
  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/w"
                 elementFormDefault="qualified">
        <xs:element name="settings">
          <xs:complexType>
            <xs:complexContent>
              <xs:restriction base="xs:anyType">
                <xs:attribute name="lang"/>
                <xs:anyAttribute namespace="##targetNamespace ##local"
                                 processContents="strict"/>
              </xs:restriction>
            </xs:complexContent>
          </xs:complexType>
        </xs:element>
        <xs:attribute name="known" type="xs:string"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "http://example.com/w" => schema })
  end
  let(:resolver) do
    Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(repository)
  end
  let(:schema_def) { resolver.resolve("settings", "http://example.com/w") }
  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/settings" }
    end
  end

  def validate_xml(xml)
    root = Moxml::Context.new.parse(xml).root
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    rule.validate(xml_element, schema_def, collector, repository: resolver)
    collector
  end

  it "accepts a wildcard-permitted declared attribute" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:w="http://example.com/w" lang="en" w:known="x"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "reports an undeclared attribute under strict processing" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" lang="en" bogus="1"/>',
    )

    codes = collector.errors.map(&:code)
    expect(codes).to include("wildcard_undeclared_attribute")
    expect(codes).not_to include("unexpected_attribute")
  end

  it "reports unexpected for a namespace outside the wildcard list" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:o="http://other.example" o:x="1"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end

  it "keeps the wildcard from bypassing namespace violations" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:o="http://other.example" lang="en" o:y="2"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end
end

# Whether lutaml-model maps the complexType-level anyAttribute; older
# parses expose no accessor and types carrying the wildcard keep the
# pre-wildcard behavior.
COMPLEX_WILDCARD_MAPPED = begin
  probe = Lutaml::Xml::Schema::Xsd.parse(
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
    '<xs:complexType name="t"><xs:anyAttribute namespace="##local"/>' \
    "</xs:complexType></xs:schema>",
  )
  !probe.complex_type.first.any_attribute.nil?
rescue StandardError
  false
end

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule,
               "complexType-level anyAttribute" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }
  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/c"
                 elementFormDefault="qualified">
        <xs:element name="item">
          <xs:complexType>
            <xs:attribute name="id"/>
            <xs:anyAttribute namespace="##local"
                             processContents="strict"/>
          </xs:complexType>
        </xs:element>
        <xs:attribute name="known" type="xs:string"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "http://example.com/c" => schema })
  end
  let(:resolver) do
    Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(repository)
  end
  let(:schema_def) { resolver.resolve("item", "http://example.com/c") }
  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/item" }
    end
  end

  def validate_xml(xml)
    root = Moxml::Context.new.parse(xml).root
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    rule.validate(xml_element, schema_def, collector, repository: resolver)
    collector
  end

  it "accepts a declared attribute beside a complexType wildcard",
     if: COMPLEX_WILDCARD_MAPPED do
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" known="x"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "rejects an undeclared attribute under strict processing",
     if: COMPLEX_WILDCARD_MAPPED do
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" bogus="1"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("wildcard_undeclared_attribute")
  end

  it "degrades to unexpected_attribute while the mapping is absent",
     unless: COMPLEX_WILDCARD_MAPPED do
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" known="x"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end
end
