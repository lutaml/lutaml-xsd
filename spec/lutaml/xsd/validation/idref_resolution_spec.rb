# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/validator"

RSpec.describe "IDREF(S) resolution to document IDs" do
  let(:validator) do
    repository = Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ nil => schema })
    config = {
      "validation" => {
        "features" => { "engine_validation" => false },
      },
    }
    Lutaml::Xsd::Validation::Validator.new(repository, config: config)
  end

  context "with a defaulted IDREFS and no ID in the document (idZ012)" do
    let(:schema) do
      Lutaml::Xml::Schema::Xsd.parse(<<~XSD)
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:attribute name="drefs" type="xs:IDREFS" default="abc"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "rejects the defaulted reference" do
      result = validator.validate("<root/>")

      expect(result.valid?).to be(false)
      expect(result.errors.map(&:code)).to include("idref_violation")
    end
  end

  context "with a defaulted IDREFS matching a present ID" do
    let(:schema) do
      Lutaml::Xml::Schema::Xsd.parse(<<~XSD)
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="item" type="xs:ID" maxOccurs="unbounded"/>
              </xs:sequence>
              <xs:attribute name="dref" type="xs:IDREF" default="a1"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "accepts the defaulted reference" do
      result = validator.validate("<root><item>a1</item></root>")

      expect(result.valid?).to be(true)
    end
  end

  context "with instance IDREF attributes" do
    let(:schema) do
      Lutaml::Xml::Schema::Xsd.parse(<<~XSD)
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="item" maxOccurs="unbounded">
                  <xs:complexType>
                    <xs:attribute name="id" type="xs:ID"/>
                    <xs:attribute name="ref" type="xs:IDREF"/>
                  </xs:complexType>
                </xs:element>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "accepts a reference that resolves" do
      result = validator.validate(
        '<root><item id="a1" ref="a1"/></root>',
      )

      expect(result.valid?).to be(true)
    end

    it "rejects a dangling reference" do
      result = validator.validate(
        '<root><item id="a1" ref="zzz"/></root>',
      )

      expect(result.valid?).to be(false)
      expect(result.errors.map(&:code)).to include("idref_violation")
    end

    it "resolves a forward reference" do
      result = validator.validate(
        '<root><item id="a1" ref="b2"/><item id="b2"/></root>',
      )

      expect(result.valid?).to be(true)
    end
  end

  context "with IDREFS token values" do
    let(:schema) do
      Lutaml::Xml::Schema::Xsd.parse(<<~XSD)
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="item" type="xs:ID" maxOccurs="unbounded"/>
              </xs:sequence>
              <xs:attribute name="refs" type="xs:IDREFS"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "rejects when any token dangles" do
      result = validator.validate(
        '<root refs="a1 zzz"><item>a1</item></root>',
      )

      expect(result.valid?).to be(false)
      expect(result.errors.map(&:code)).to include("idref_violation")
    end

    it "accepts when every token resolves" do
      result = validator.validate(
        '<root refs="a1 b2"><item>a1</item><item>b2</item></root>',
      )

      expect(result.valid?).to be(true)
    end
  end
end
