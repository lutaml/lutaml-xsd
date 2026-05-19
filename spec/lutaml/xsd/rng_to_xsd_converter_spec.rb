# frozen_string_literal: true

require "spec_helper"
require "rng"
require "lutaml/xsd/rng_to_xsd_converter"

RSpec.describe Lutaml::Xsd::RngToXsdConverter do
  describe "#convert" do
    let(:fixture_path) do
      "spec/fixtures/metanorma-model-iso-grammars/bsi.rnc"
    end

    let(:grammar) { Rng.parse_file(fixture_path) }
    let(:converter) { described_class.new(grammar, file_path: fixture_path) }
    let(:schema) { converter.convert }

    it "returns a Schema object" do
      expect(schema).to be_a(Lutaml::Xml::Schema::Xsd::Schema)
    end

    it "produces 14 complex types and elements " \
       "(including types from the elements in the included paths)" do
      expect(schema.complex_type.length + schema.element.length).to eq(14)
    end

    it "includes complex types in the included paths" do
      names = schema.complex_type.map(&:name)
      expect(names).to include("Content-Section")
    end

    it "includes complex type Clause-Section" do
      complex_type = schema.complex_type.find do |ct|
        ct.name == "Clause-Section"
      end
      expect(complex_type.name).to eq("Clause-Section")

      attr = complex_type.attribute.first
      expect(attr).to be_a(Lutaml::Xml::Schema::Xsd::Attribute)
      expect(attr.name).to eq("type")

      attr_group = complex_type.attribute_group.first
      expect(attr_group).to be_a(Lutaml::Xml::Schema::Xsd::AttributeGroup)
      expect(attr_group.ref).to eq("Section-Attributes")
    end

    it "includes complex type section-title_type" do
      complex_type = schema.complex_type.find do |ct|
        ct.name == "section-title_type"
      end
      expect(complex_type.name).to eq("section-title_type")
      expect(complex_type.mixed).to eq(true)
    end

    it "produces 1 simple type" do
      expect(schema.simple_type.length).to eq(1)
    end

    it "produces 10 elements (including elements in the included paths)" do
      expect(schema.element.length).to eq(10)
    end

    it "produces 3 groups (including groups in the included paths)" do
      expect(schema.group.length).to eq(3)
    end

    it "produces 1 attribute_group (including groups in the included paths)" do
      expect(schema.attribute_group.length).to eq(1)
      expect(schema.attribute_group.first.name).to eq("AdmonitionAttributes")
      expect(schema.attribute_group.first.attribute.length).to eq(1)
      expect(schema.attribute_group.first.attribute.first.name).to eq("target")
    end
  end
end
