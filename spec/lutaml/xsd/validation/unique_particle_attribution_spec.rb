# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/unique_particle_attribution"

RSpec.describe Lutaml::Xsd::Validation::UniqueParticleAttribution do
  def findings_for(xsd)
    schema = Lutaml::Xml::Schema::Xsd.parse(xsd)
    described_class.new(schema).findings
  end

  it "reports an optional element followed by the same element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" minOccurs="0"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings.map(&:code)).to eq(["upa_violation"])
    expect(findings.first.message).to include("'a'")
  end

  it "reports a choice with duplicate alternatives" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:choice>
              <xs:element name="a"/>
              <xs:element name="a"/>
            </xs:choice>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports an optional choice whose names overlap the next element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:choice minOccurs="0">
                <xs:element name="a"/>
                <xs:element name="b"/>
              </xs:choice>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports an unbounded element followed by itself" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" maxOccurs="unbounded"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "accepts two required occurrences of the same element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "accepts an optional element followed by a different element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" minOccurs="0"/>
              <xs:element name="b"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "reports a wildcard overlapping a sibling element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:any namespace="##any" minOccurs="0"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports ambiguity across a repeated nested group" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:sequence minOccurs="0">
                <xs:element name="a"/>
              </xs:sequence>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end
end
