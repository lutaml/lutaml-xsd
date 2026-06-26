# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SchemaRepository namespace aliases" do
  describe "nested constants" do
    it "exposes Metadata via SchemaRepository::Metadata" do
      expect(Lutaml::Xsd::SchemaRepository::Metadata)
        .to eq(Lutaml::Xsd::SchemaRepositoryMetadata)
    end

    it "exposes Statistics via SchemaRepository::Statistics" do
      expect(Lutaml::Xsd::SchemaRepository::Statistics)
        .to eq(Lutaml::Xsd::SchemaRepositoryStatistics)
    end

    it "exposes Package via SchemaRepository::Package" do
      expect(Lutaml::Xsd::SchemaRepository::Package)
        .to eq(Lutaml::Xsd::SchemaRepositoryPackage)
    end
  end

  describe "legacy top-level constants" do
    it "still resolves SchemaRepositoryMetadata" do
      expect(Lutaml::Xsd::SchemaRepositoryMetadata).to be_a(Class)
    end

    it "still resolves SchemaRepositoryStatistics" do
      expect(Lutaml::Xsd::SchemaRepositoryStatistics).to be_a(Class)
    end

    it "still resolves SchemaRepositoryPackage" do
      expect(Lutaml::Xsd::SchemaRepositoryPackage).to be_a(Class)
    end
  end

  describe "nested constants construction works" do
    it "builds a Statistics instance from a stats hash" do
      stats = Lutaml::Xsd::SchemaRepository::Statistics.from_statistics(
        total_schemas: 1,
        total_types: 2,
        types_by_category: { complex_type: 1, simple_type: 1 },
        total_namespaces: 1,
        namespace_prefixes: 1,
        resolved: true,
        validated: false,
      )
      expect(stats).to be_a(Lutaml::Xsd::SchemaRepository::Statistics)
      expect(stats.total_schemas).to eq(1)
    end
  end
end
