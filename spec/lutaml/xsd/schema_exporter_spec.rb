# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/schema_exporter"

RSpec.describe Lutaml::Xsd::SchemaExporter do
  let(:schema_files) do
    [
      File.expand_path("../../fixtures/metaschema.xsd", __dir__),
    ]
  end

  let(:schema_location_mappings) do
    [
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-datatypes.xsd",
        to: File.expand_path("../../fixtures/metaschema-datatypes.xsd", __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-base.xsd",
        to: File.expand_path("../../fixtures/metaschema-prose-base.xsd", __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-line.xsd",
        to: File.expand_path("../../fixtures/metaschema-markup-line.xsd", __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-multiline.xsd",
        to: File.expand_path("../../fixtures/metaschema-markup-multiline.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-module.xsd",
        to: File.expand_path("../../fixtures/metaschema-prose-module.xsd", __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-meta-constraints.xsd",
        to: File.expand_path("../../fixtures/metaschema-meta-constraints.xsd",
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

  let(:exporter) { described_class.new(repository) }

  describe "#statistics" do
    subject(:stats) { exporter.statistics }

    it "matches Stats::Collector's output" do
      expected = Lutaml::Xsd::Stats::Collector.new(repository).call
      expect(stats).to eq(expected)
    end
  end

  describe "#export_statistics" do
    it "delegates to Stats::Formatters with the requested format" do
      output = exporter.export_statistics(format: :text)
      expect(output).to start_with("Schema Repository Statistics")
    end

    it "defaults to YAML format" do
      default = exporter.export_statistics
      explicit = exporter.export_statistics(format: :yaml)
      expect(default).to eq(explicit)
    end
  end

  describe "#namespace_summary" do
    it "matches Stats::Collector's namespace_summary" do
      expected = Lutaml::Xsd::Stats::Collector.new(repository).namespace_summary
      expect(exporter.namespace_summary).to eq(expected)
    end
  end

  describe "#elements_by_namespace" do
    it "delegates to Stats::ElementCatalog" do
      expected = Lutaml::Xsd::Stats::ElementCatalog.new(repository).by_namespace
      expect(exporter.elements_by_namespace).to eq(expected)
    end

    it "forwards the namespace filter" do
      ns = exporter.elements_by_namespace.keys.compact.first
      filtered = exporter.elements_by_namespace(namespace_uri: ns)
      expect(filtered.keys).to eq([ns])
    end
  end
end
