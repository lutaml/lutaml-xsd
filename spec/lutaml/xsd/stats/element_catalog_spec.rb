# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/stats/element_catalog"

RSpec.describe Lutaml::Xsd::Stats::ElementCatalog do
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

  let(:catalog) { described_class.new(repository) }
  let(:all_results) { catalog.by_namespace }

  describe "#by_namespace" do
    it "groups element info hashes by namespace URI" do
      expect(all_results).to be_a(Hash)
      expect(all_results.keys).to all(satisfy { |k| k.nil? || k.is_a?(String) })
    end

    it "shapes each element entry with the documented contract" do
      all_results.each_value do |elements|
        elements.each do |entry|
          expect(entry.keys).to contain_exactly(
            :name, :qualified_name, :type, :min_occurs, :max_occurs, :documentation
          )
        end
      end
    end

    it "qualifies each element name with its namespace prefix" do
      all_results.each do |ns_uri, elements|
        prefix = repository.namespace_to_prefix(ns_uri)
        elements.each do |entry|
          expect(entry[:qualified_name]).to start_with("#{prefix}:")
        end
      end
    end

    context "when filtering by a known namespace" do
      subject(:filtered) { catalog.by_namespace(namespace_uri: target_ns) }

      let(:target_ns) { all_results.keys.compact.first }

      it "returns only that namespace's elements" do
        expect(filtered.keys).to eq([target_ns])
      end
    end

    context "when filtering by an unknown namespace" do
      subject(:filtered) { catalog.by_namespace(namespace_uri: "http://nope") }

      it { is_expected.to be_empty }
    end
  end
end
