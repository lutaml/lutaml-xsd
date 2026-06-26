# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/stats/documentation_extractor"

RSpec.describe Lutaml::Xsd::Stats::DocumentationExtractor do
  let(:xsd_with_docs) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/test"
                 xmlns="http://example.com/test"
                 elementFormDefault="qualified">

        <xs:element name="WithDocs" type="xs:string">
          <xs:annotation>
            <xs:documentation>Primary documentation for the element.</xs:documentation>
          </xs:annotation>
        </xs:element>

        <xs:element name="WithoutDocs" type="xs:string"/>
      </xs:schema>
    XSD
  end

  let(:schema) do
    Lutaml::Xml::Schema::Xsd.parse(xsd_with_docs, location: "/tmp/")
  end

  let(:with_docs) { schema.element.find { |e| e.name == "WithDocs" } }
  let(:without_docs) { schema.element.find { |e| e.name == "WithoutDocs" } }

  describe ".call" do
    it "extracts documentation from an annotated element" do
      result = described_class.call(with_docs)
      expect(result).to eq("Primary documentation for the element.")
    end

    it "returns an empty string when the element has no annotation" do
      expect(described_class.call(without_docs)).to eq("")
    end
  end
end
