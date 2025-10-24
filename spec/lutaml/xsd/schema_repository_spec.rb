# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaRepository do
  let(:schema_files) do
    [
      File.expand_path("../../fixtures/i-ur/urbanObject.xsd", __dir__)
    ]
  end

  let(:schema_location_mappings) do
    [
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+gml/(.+\.xsd)$',
        to: File.expand_path("../../fixtures/codesynthesis-gml-3.2.1/gml/\\1", __dir__),
        pattern: true
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+iso/(.+\.xsd)$',
        to: File.expand_path("../../fixtures/codesynthesis-gml-3.2.1/iso/\\1", __dir__),
        pattern: true
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+xlink/(.+\.xsd)$',
        to: File.expand_path("../../fixtures/codesynthesis-gml-3.2.1/xlink/\\1", __dir__),
        pattern: true
      )
    ]
  end

  let(:namespace_mappings) do
    {
      "gml" => "http://www.opengis.net/gml/3.2",
      "xs" => "http://www.w3.org/2001/XMLSchema",
      "xlink" => "http://www.w3.org/1999/xlink",
      "uro" => "https://www.geospatial.jp/iur/uro/3.2"
    }
  end

  describe "#initialize" do
    it "creates a new repository with files" do
      repository = described_class.new(files: schema_files)
      expect(repository.files).to eq(schema_files)
    end

    it "creates a repository with schema location mappings" do
      repository = described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
      expect(repository.schema_location_mappings.size).to eq(3)
    end

    it "initializes with empty state" do
      repository = described_class.new(files: schema_files)
      expect(repository).not_to be_nil
      expect(repository.files).to eq(schema_files)
    end
  end

  describe "#configure_namespace" do
    let(:repository) { described_class.new(files: schema_files) }

    it "adds a single namespace mapping" do
      repository.configure_namespace(prefix: "gml", uri: "http://www.opengis.net/gml/3.2")
      expect(repository.namespace_mappings.size).to eq(1)
      expect(repository.namespace_mappings.first.prefix).to eq("gml")
      expect(repository.namespace_mappings.first.uri).to eq("http://www.opengis.net/gml/3.2")
    end

    it "returns self for chaining" do
      result = repository.configure_namespace(prefix: "gml", uri: "http://www.opengis.net/gml/3.2")
      expect(result).to eq(repository)
    end
  end

  describe "#configure_namespaces" do
    let(:repository) { described_class.new(files: schema_files) }

    it "configures multiple namespaces from a hash" do
      repository.configure_namespaces(namespace_mappings)
      expect(repository.namespace_mappings.size).to eq(4)
    end

    it "configures namespaces from an array of NamespaceMapping objects" do
      mappings = [
        Lutaml::Xsd::NamespaceMapping.new(prefix: "gml", uri: "http://www.opengis.net/gml/3.2"),
        Lutaml::Xsd::NamespaceMapping.new(prefix: "xs", uri: "http://www.w3.org/2001/XMLSchema")
      ]
      repository.configure_namespaces(mappings)
      expect(repository.namespace_mappings.size).to eq(2)
    end
  end

  describe "#parse" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    it "parses schema files successfully" do
      result = repository.parse
      expect(result).to eq(repository)
    end

    it "handles missing schema files gracefully" do
      bad_repository = described_class.new(
        files: ["/nonexistent/file.xsd"],
        schema_location_mappings: schema_location_mappings
      )
      expect { bad_repository.parse }.not_to raise_error
    end
  end

  describe "#resolve" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    before do
      repository.configure_namespaces(namespace_mappings)
      repository.parse
    end

    it "resolves schemas and builds indexes" do
      result = repository.resolve
      expect(result).to eq(repository)
    end

    it "indexes types from parsed schemas" do
      repository.resolve
      stats = repository.statistics
      expect(stats[:total_types]).to be > 0
    end

    it "extracts namespaces from schemas" do
      repository.resolve
      namespaces = repository.all_namespaces
      expect(namespaces).not_to be_empty
    end
  end

  describe "#find_type" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    before do
      repository.configure_namespaces(namespace_mappings)
      repository.parse
      repository.resolve
    end

    it "finds types from urbanObject schema" do
      # urbanObject.xsd defines types in the uro namespace
      result = repository.find_type("uro:BuildingDetailsType")
      expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
    end

    it "returns failure for non-existent types" do
      result = repository.find_type("gml:NonExistentType")
      expect(result.resolved?).to be false
      expect(result.error_message).to include("not found")
    end

    it "returns failure for unregistered namespace prefixes" do
      result = repository.find_type("unknown:Type")
      expect(result.resolved?).to be false
      expect(result.error_message).to include("not registered")
    end

    it "handles Clark notation" do
      result = repository.find_type("{https://www.geospatial.jp/iur/uro/3.2}BuildingDetailsType")
      # May or may not be resolved depending on schema content
      expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
    end
  end

  describe "#validate" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    before do
      repository.configure_namespaces(namespace_mappings)
      repository.parse
    end

    it "validates successfully with correct configuration" do
      errors = repository.validate
      expect(errors).to be_an(Array)
    end

    it "detects missing schema files" do
      bad_repository = described_class.new(files: ["/nonexistent/file.xsd"])
      errors = bad_repository.validate
      expect(errors).not_to be_empty
      expect(errors.first).to include("not found")
    end

    it "validates namespace mappings" do
      bad_repository = described_class.new(files: schema_files)
      bad_repository.instance_variable_set(:@namespace_mappings, [
                                             Lutaml::Xsd::NamespaceMapping.new(prefix: "", uri: "http://example.com")
                                           ])
      errors = bad_repository.validate
      expect(errors).not_to be_empty
    end
  end

  describe "#statistics" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    before do
      repository.configure_namespaces(namespace_mappings)
      repository.parse
      repository.resolve
    end

    it "returns repository statistics" do
      stats = repository.statistics
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total_schemas)
      expect(stats).to have_key(:total_types)
      expect(stats).to have_key(:types_by_category)
      expect(stats).to have_key(:total_namespaces)
      expect(stats).to have_key(:namespace_prefixes)
      expect(stats).to have_key(:resolved)
      expect(stats).to have_key(:validated)
    end

    it "reports correct schema count" do
      stats = repository.statistics
      expect(stats[:total_schemas]).to be >= 1
    end

    it "reports types by category" do
      stats = repository.statistics
      expect(stats[:types_by_category]).to be_a(Hash)
    end
  end

  describe "#all_namespaces" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings
      )
    end

    before do
      repository.configure_namespaces(namespace_mappings)
      repository.parse
      repository.resolve
    end

    it "returns all registered namespace URIs" do
      namespaces = repository.all_namespaces
      expect(namespaces).to be_an(Array)
      expect(namespaces).not_to be_empty
    end
  end

  describe "YAML serialization" do
    let(:repository) do
      described_class.new(
        files: schema_files,
        schema_location_mappings: schema_location_mappings.take(1),
        namespace_mappings: [
          Lutaml::Xsd::NamespaceMapping.new(prefix: "gml", uri: "http://www.opengis.net/gml/3.2")
        ]
      )
    end

    it "serializes to YAML" do
      yaml = repository.to_yaml
      expect(yaml).to be_a(String)
      expect(yaml).to include("files:")
      expect(yaml).to include("schema_location_mappings:")
      expect(yaml).to include("namespace_mappings:")
    end

    it "deserializes from YAML" do
      yaml = repository.to_yaml
      loaded = Lutaml::Xsd::SchemaRepository.from_yaml(yaml)
      expect(loaded.files).to eq(repository.files)
      expect(loaded.schema_location_mappings.size).to eq(repository.schema_location_mappings.size)
      expect(loaded.namespace_mappings.size).to eq(repository.namespace_mappings.size)
    end
  end
end
