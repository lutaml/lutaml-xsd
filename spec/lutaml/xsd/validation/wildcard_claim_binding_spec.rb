# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation"
require "lutaml/xsd/conformance/runner"

RSpec.describe "wildcard-claimed child binding" do
  # A child the content matcher claimed for a WILDCARD assesses
  # against its RESOLVED GLOBAL declaration — never against the
  # parent content model's same-named positional particle (which
  # never claimed it). The suite shape (wild063): lax ##local
  # wildcard, a global `e` of xs:positiveInteger, and a local
  # `e` of xs:integer in the sequence.
  def run_pipeline(schema_xml, instance_xml)
    schema = Lutaml::Xml::Schema::Xsd.parse(schema_xml)
    schemas = { nil => schema }
    config = Lutaml::Xsd::Validation::ValidationConfiguration.new
    job = Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: instance_xml,
      repository: Lutaml::Xsd::Conformance::Runner::Repository.new(schemas),
      rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
      config: config,
    )
    job.execute
  end

  let(:schema_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:complexType name="zing">
          <xs:sequence>
            <xs:element name="e" type="xs:integer"/>
            <xs:element name="f" type="xs:integer"/>
            <xs:any namespace="##local" processContents="lax"/>
          </xs:sequence>
        </xs:complexType>
        <xs:element name="doc" type="zing"/>
        <xs:element name="e" type="xs:positiveInteger"/>
      </xs:schema>
    XSD
  end

  it "assesses the wildcard-claimed namesake against the global" do
    result = run_pipeline(schema_xml, "<doc><e>-12</e><f>42</f><e>-12</e></doc>")
    expect(result.valid?).to be(false)
  end

  it "accepts the wildcard-claimed namesake when the global accepts it" do
    result = run_pipeline(schema_xml, "<doc><e>-12</e><f>42</f><e>12</e></doc>")
    expect(result.valid?).to be(true)
  end

  # (The positional binding for declared-particle children is pinned
  # by the 1.0 ledger itself — 4,696 cases whose bindings flow
  # through the same dispatch. A dedicated case here would need a
  # schema without a conflicting global, and the engine tier has its
  # own same-name collapse there — filed upstream separately.)
end
