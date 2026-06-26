# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/stats/collector"

RSpec.describe Lutaml::Xsd::Stats::Collector do
  let(:schema_files) do
    [
      File.expand_path("../../../fixtures/metaschema.xsd", __dir__),
    ]
  end

  let(:schema_location_mappings) do
    [
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-datatypes.xsd",
        to: File.expand_path("../../../fixtures/metaschema-datatypes.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-base.xsd",
        to: File.expand_path("../../../fixtures/metaschema-prose-base.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-line.xsd",
        to: File.expand_path("../../../fixtures/metaschema-markup-line.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-multiline.xsd",
        to: File.expand_path("../../../fixtures/metaschema-markup-multiline.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-module.xsd",
        to: File.expand_path("../../../fixtures/metaschema-prose-module.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-meta-constraints.xsd",
        to: File.expand_path("../../../fixtures/metaschema-meta-constraints.xsd",
                             __dir__),
        pattern: false,
      ),
    ]
  end

  let(:namespace_mappings) do
    {
      "xs" => "http://www.w3.org/2001/XMLSchema",
      "m" => "http://csrc.nist.gov/ns/oscal/metaschema/1.0",
    }
  end

  let(:repository) do
    Lutaml::Xsd::SchemaRepository.new(
      files: schema_files,
      schema_location_mappings: schema_location_mappings,
    ).tap do |repo|
      repo.configure_namespaces(namespace_mappings)
      repo.parse
      repo.resolve
    end
  end

  let(:collector) { described_class.new(repository) }

  describe "#call" do
    subject(:stats) { collector.call }

    it "returns the expected keys" do
      expect(stats.keys).to contain_exactly(
        :total_schemas, :total_types, :types_by_category,
        :total_namespaces, :namespace_prefixes, :resolved, :validated
      )
    end

    it "counts parsed schemas as an integer" do
      expect(stats[:total_schemas]).to be_an(Integer)
      expect(stats[:total_schemas]).to be > 0
    end

    it "counts total types as an integer" do
      expect(stats[:total_types]).to be_an(Integer)
      expect(stats[:total_types]).to be > 0
    end

    it "groups type counts by category as a Hash" do
      expect(stats[:types_by_category]).to be_a(Hash)
      expect(stats[:types_by_category]).not_to be_empty
    end

    it "counts total namespaces as an integer" do
      expect(stats[:total_namespaces]).to be_an(Integer)
    end

    it "counts registered namespace prefixes as an integer" do
      expect(stats[:namespace_prefixes]).to eq(2)
    end

    it "reflects the repository's resolved state" do
      expect(stats[:resolved]).to eq(true)
    end

    it "reflects the repository's validated state" do
      expect(stats[:validated]).to eq(false)
    end
  end

  describe "#namespace_summary" do
    subject(:summary) { collector.namespace_summary }

    it "returns one entry per namespace URI" do
      expect(summary).to be_an(Array)
      expect(summary.size).to eq(repository.all_namespaces.size)
    end

    it "shapes each entry as {uri, prefix, types}" do
      expect(summary.first.keys).to contain_exactly(:uri, :prefix, :types)
    end

    it "counts types per namespace as a non-negative integer" do
      summary.each do |entry|
        expect(entry[:types]).to be_an(Integer)
        expect(entry[:types]).to be >= 0
      end
    end
  end
end
