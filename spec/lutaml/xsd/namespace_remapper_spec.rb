# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"

RSpec.describe Lutaml::Xsd::NamespaceRemapper do
  let(:repository) do
    Lutaml::Xsd::SchemaRepository.new(
      files: ["/path/to/schema.xsd"],
      namespace_mappings: [
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "gml",
          uri: "http://www.opengis.net/gml/3.2"
        ),
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "xlink",
          uri: "http://www.w3.org/1999/xlink"
        )
      ]
    )
  end

  let(:remapper) { described_class.new(repository) }

  describe "#initialize" do
    it "sets the repository" do
      expect(remapper.repository).to eq(repository)
    end
  end

  describe "#remap" do
    context "with valid changes" do
      let(:changes) { { "gml" => "gml32" } }

      it "returns new repository with updated mappings" do
        new_repo = remapper.remap(changes)

        expect(new_repo).to be_a(Lutaml::Xsd::SchemaRepository)
        expect(new_repo).not_to eq(repository)
      end

      it "updates prefix in namespace mappings" do
        new_repo = remapper.remap(changes)

        gml_mapping = new_repo.namespace_mappings.find { |m| m.uri == "http://www.opengis.net/gml/3.2" }
        expect(gml_mapping.prefix).to eq("gml32")
      end

      it "preserves other namespace mappings" do
        new_repo = remapper.remap(changes)

        xlink_mapping = new_repo.namespace_mappings.find { |m| m.prefix == "xlink" }
        expect(xlink_mapping).not_to be_nil
        expect(xlink_mapping.uri).to eq("http://www.w3.org/1999/xlink")
      end

      it "preserves files and schema location mappings" do
        new_repo = remapper.remap(changes)

        expect(new_repo.files).to eq(repository.files)
        expect(new_repo.schema_location_mappings).to eq(repository.schema_location_mappings)
      end
    end

    context "with multiple changes" do
      let(:changes) { { "gml" => "gml32", "xlink" => "xl" } }

      it "applies all changes" do
        new_repo = remapper.remap(changes)

        gml_mapping = new_repo.namespace_mappings.find { |m| m.uri == "http://www.opengis.net/gml/3.2" }
        xlink_mapping = new_repo.namespace_mappings.find { |m| m.uri == "http://www.w3.org/1999/xlink" }

        expect(gml_mapping.prefix).to eq("gml32")
        expect(xlink_mapping.prefix).to eq("xl")
      end
    end

    context "with swapped prefixes" do
      let(:changes) { { "gml" => "xlink", "xlink" => "gml" } }

      it "successfully swaps prefixes" do
        new_repo = remapper.remap(changes)

        gml_uri_mapping = new_repo.namespace_mappings.find { |m| m.uri == "http://www.opengis.net/gml/3.2" }
        xlink_uri_mapping = new_repo.namespace_mappings.find { |m| m.uri == "http://www.w3.org/1999/xlink" }

        expect(gml_uri_mapping.prefix).to eq("xlink")
        expect(xlink_uri_mapping.prefix).to eq("gml")
      end
    end

    context "with invalid changes" do
      it "raises error for non-existent prefix" do
        changes = { "nonexistent" => "new" }

        expect {
          remapper.remap(changes)
        }.to raise_error(ArgumentError, /Prefix 'nonexistent' not found/)
      end

      it "raises error for empty new prefix" do
        changes = { "gml" => "" }

        expect {
          remapper.remap(changes)
        }.to raise_error(ArgumentError, /New prefix cannot be empty/)
      end

      it "raises error for nil new prefix" do
        changes = { "gml" => nil }

        expect {
          remapper.remap(changes)
        }.to raise_error(ArgumentError, /New prefix cannot be empty/)
      end

      it "raises error for conflicting new prefix" do
        changes = { "gml" => "xlink" }

        expect {
          remapper.remap(changes)
        }.to raise_error(ArgumentError, /Prefix 'xlink' already exists/)
      end
    end
  end

  describe "internal state copying" do
    before do
      # Set up some internal state
      repository.instance_variable_set(:@resolved, true)
      repository.instance_variable_set(:@validated, true)
      repository.instance_variable_set(:@lazy_load, false)
      repository.instance_variable_set(:@verbose, true)
      repository.instance_variable_set(:@parsed_schemas, { "test.xsd" => double("Schema") })
    end

    it "copies internal state to new repository" do
      changes = { "gml" => "gml32" }
      new_repo = remapper.remap(changes)

      expect(new_repo.instance_variable_get(:@resolved)).to eq(true)
      expect(new_repo.instance_variable_get(:@validated)).to eq(true)
      expect(new_repo.instance_variable_get(:@lazy_load)).to eq(false)
      expect(new_repo.instance_variable_get(:@verbose)).to eq(true)
    end

    it "duplicates parsed schemas" do
      changes = { "gml" => "gml32" }
      new_repo = remapper.remap(changes)

      original_schemas = repository.instance_variable_get(:@parsed_schemas)
      new_schemas = new_repo.instance_variable_get(:@parsed_schemas)

      expect(new_schemas).to eq(original_schemas)
      expect(new_schemas.object_id).not_to eq(original_schemas.object_id)
    end
  end
end