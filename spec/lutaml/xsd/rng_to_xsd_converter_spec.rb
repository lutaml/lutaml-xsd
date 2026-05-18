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

    it "produces 12 complex types " \
       "(including types from the elements in the included paths)" do
      expect(schema.complex_type.length + schema.element.length).to eq(12)
    end

    it "includes complex types in the included paths" do
      names = schema.complex_type.map(&:name)
      expect(names).to include("Content-Section")
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
