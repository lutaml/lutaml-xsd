# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation"
require "lutaml/xsd/conformance/runner"

RSpec.describe "cyclic derivation guards" do
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

  # A derivation cycle (A extends B extends A) is writable in XML but
  # illegal per the spec; the suite's ibm composition sets carry such
  # schemas. The attribute walks must terminate, not exhaust the stack
  # (SystemStackError is not a StandardError — it used to kill the
  # whole measure batch).
  %w[simpleContent complexContent].each do |content_kind|
    inner = content_kind == "simpleContent" ? "text" : "<inner/>"

    it "terminates the base walk on a #{content_kind} cycle" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc" type="a"/>
          <xs:complexType name="a">
            <xs:#{content_kind}>
              <xs:extension base="b">
                <xs:attribute name="x" type="xs:int"/>
              </xs:extension>
            </xs:#{content_kind}>
          </xs:complexType>
          <xs:complexType name="b">
            <xs:#{content_kind}>
              <xs:extension base="a"/>
            </xs:#{content_kind}>
          </xs:complexType>
        </xs:schema>
      XSD

      # The cycle makes the schema illegal, so only the no-crash
      # property is asserted (the complexContent fallback leaves the
      # content model incomplete; the verdict is underdetermined).
      expect { run_pipeline(schema, "<doc x=\"1\">#{inner}</doc>") }
        .not_to raise_error
    end

    it "still assesses attributes on a #{content_kind} cycle" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc" type="a"/>
          <xs:complexType name="a">
            <xs:#{content_kind}>
              <xs:extension base="b">
                <xs:attribute name="x" type="xs:int"/>
              </xs:extension>
            </xs:#{content_kind}>
          </xs:complexType>
          <xs:complexType name="b">
            <xs:#{content_kind}>
              <xs:extension base="a"/>
            </xs:#{content_kind}>
          </xs:complexType>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<doc x=\"nope\">#{inner}</doc>")
      expect(result.valid?).to be(false)
    end
  end
end
