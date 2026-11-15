# frozen_string_literal: true

require "spec_helper"
require "json"
require "lutaml/xsd"
require "lutaml/xsd/dim_exporter"

RSpec.describe Lutaml::Xsd::DimExporter do
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
  let(:document) { described_class.new(schema).export }
  let(:graph) { document["graph"] }

  let(:xsd_source) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:tns="http://example.com/test"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="person" type="tns:t_person"/>
        <xs:complexType name="t_person">
          <xs:complexContent>
            <xs:extension base="tns:t_party">
              <xs:sequence>
                <xs:element name="name" type="xs:string"/>
                <xs:element name="address" type="tns:t_address"/>
              </xs:sequence>
            </xs:extension>
          </xs:complexContent>
        </xs:complexType>
        <xs:complexType name="t_party">
          <xs:sequence>
            <xs:element name="id" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
        <xs:complexType name="t_address">
          <xs:sequence>
            <xs:element name="street" type="xs:string" minOccurs="0"/>
            <xs:element name="lines" type="xs:string" maxOccurs="unbounded"/>
          </xs:sequence>
        </xs:complexType>
        <xs:simpleType name="t_status">
          <xs:restriction base="xs:string">
            <xs:enumeration value="active"/>
          </xs:restriction>
        </xs:simpleType>
      </xs:schema>
    XSD
  end

  it "emits a DIM 0.1 document in the xsd notation" do
    expect(document.values_at("dim", "notation")).to eq(["0.1", "xsd"])
  end

  it "steers the engine with layered layout flowing down" do
    expect(graph["layoutOptions"]).to include(
      "elk.algorithm" => "layered",
      "elk.direction" => "DOWN",
    )
  end

  it "draws one node per top-level type and global element" do
    expect(graph["children"].map { |n| n["id"] }).to contain_exactly(
      "element-person", "type-t_person", "type-t_party", "type-t_address",
      "type-t_status"
    )
  end

  it "marks each node with its stereotype" do
    person = graph["children"].find { |n| n["id"] == "type-t_person" }
    stereotype = person["content"].find { |c| c["role"] == "stereotype" }

    expect(stereotype["text"]).to eq("complexType")
  end

  it "lists particle members with occurrence suffixes" do
    address = graph["children"].find { |n| n["id"] == "type-t_address" }
    members = address["content"].select { |c| c["role"] == "member" }

    expect(members.map { |c| c["text"] })
      .to contain_exactly("street?: xs:string", "lines[]: xs:string")
  end

  it "generalizes extension to its base" do
    derivation = graph["edges"].find { |e| e["id"] == "derive-t_person" }

    expect(derivation.values_at("sources", "targets", "style"))
      .to eq([["type-t_person"], ["type-t_party"], "generalization"])
  end

  it "keeps simpleType bases as members, not edges to builtins" do
    status = graph["children"].find { |n| n["id"] == "type-t_status" }
    restricts = status["content"].find do |c|
      c["role"] == "member" && c["text"].start_with?("restricts")
    end

    expect(restricts["text"]).to eq("restricts xs:string")
    expect(graph["edges"]).not_to include(
      hash_including("targets" => ["type-xs_string"]),
    )
  end

  it "associates a global element with its type" do
    uses = graph["edges"].find { |e| e["id"] == "uses-person" }

    expect(uses.values_at("sources", "targets", "style"))
      .to eq([["element-person"], ["type-t_person"], "association"])
  end

  it "references in-graph member types only" do
    references = graph["edges"].select { |e| e["style"] == "reference" }

    expect(references.map { |e| e["targets"] }.flatten)
      .to contain_exactly("type-t_address")
  end

  it "serializes to JSON that parses back" do
    expect(JSON.parse(described_class.new(schema).export_json))
      .to eq(document)
  end
end
