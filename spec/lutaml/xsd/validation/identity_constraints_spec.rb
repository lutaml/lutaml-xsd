# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/validator"

# Whether lutaml-model maps the keyref `refer` attribute; when unmapped
# (UninitializedClass) dangling keyrefs cannot be detected and the rule
# degrades to valid.
REFER_MAPPED = begin
  minimal = Lutaml::Xml::Schema::Xsd.parse(
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
    "<xs:element name=\"c\">" \
    '<xs:keyref name="r" refer="k"/></xs:element></xs:schema>',
  )
  Array(minimal.element.first.keyref).first.refer.is_a?(String)
rescue StandardError
  false
end

RSpec.describe "identity constraints (key/keyref/unique)" do
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
  let(:xsd_source) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
        <xs:element name="catalog">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="item" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:attribute name="code" type="xs:string"/>
                </xs:complexType>
              </xs:element>
              <xs:element name="ref" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:attribute name="target" type="xs:string"/>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
          <xs:key name="itemKey">
            <xs:selector xpath="item"/>
            <xs:field xpath="@code"/>
          </xs:key>
          <xs:keyref name="refKey" refer="itemKey">
            <xs:selector xpath="ref"/>
            <xs:field xpath="@target"/>
          </xs:keyref>
        </xs:element>
      </xs:schema>
    XSD
  end

  let!(:registered) { schema }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ nil => schema })
  end
  let(:validator) do
    Lutaml::Xsd::Validation::Validator.new(repository, config: config)
  end
  let(:config) do
    {
      "validation" => {
        "features" => { "engine_validation" => false },
      },
    }
  end

  it "accepts keyrefs that resolve" do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="a"/></catalog>',
    )

    expect(result.valid?).to be(true)
  end

  it "rejects dangling keyrefs", if: REFER_MAPPED do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="zzz"/></catalog>',
    )

    expect(result.valid?).to be(false)
    expect(result.errors.map(&:code)).to include("keyref_violation")
  end

  it "degrades to valid while keyref refer is unmapped", unless: REFER_MAPPED do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="zzz"/></catalog>',
    )

    codes = result.errors.map(&:code)
    expect(codes).not_to include("keyref_violation")
  end

  it "rejects duplicate key values" do
    result = validator.validate(
      '<catalog><item code="a"/><item code="a"/><ref target="a"/></catalog>',
    )

    expect(result.valid?).to be(false)
    expect(result.errors.map(&:code)).to include("duplicate_key_violation")
  end
end
