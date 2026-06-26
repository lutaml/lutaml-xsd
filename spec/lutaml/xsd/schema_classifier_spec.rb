# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaClassifier do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:classifier) { described_class.new(repository) }

  describe "#initialize" do
    it "stores the repository" do
      expect(classifier.repository).to eq(repository)
    end
  end

  describe "#classify" do
    context "with empty repository" do
      it "returns classification structure with empty categories" do
        result = classifier.classify

        expect(result).to be_a(Hash)
        expect(result).to include(
          :entrypoint_schemas,
          :dependency_schemas,
          :fully_resolved,
          :partially_resolved,
          :summary,
        )
        expect(result[:entrypoint_schemas]).to eq([])
        expect(result[:dependency_schemas]).to eq([])
      end

      it "returns summary with zero counts" do
        result = classifier.classify
        summary = result[:summary]

        expect(summary[:total_schemas]).to eq(0)
        expect(summary[:entrypoint_count]).to eq(0)
        expect(summary[:dependency_count]).to eq(0)
        expect(summary[:fully_resolved_count]).to eq(0)
        expect(summary[:partially_resolved_count]).to eq(0)
        expect(summary[:resolution_percentage]).to eq(0.0)
      end
    end

    context "with schemas in repository" do
      let(:schema1_path) { "/path/to/schema1.xsd" }
      let(:schema2_path) { "/path/to/schema2.xsd" }
      let(:schema1) { xsd_schema(target_namespace: "http://example.com/schema1") }
      let(:schema2) { xsd_schema(target_namespace: "http://example.com/schema2") }

      before do
        repository.parsed_schemas.set(schema1_path, schema1)
        repository.parsed_schemas.set(schema2_path, schema2)
        repository.files = [schema1_path]
      end

      it "classifies entrypoint schemas correctly" do
        result = classifier.classify
        entrypoints = result[:entrypoint_schemas]

        expect(entrypoints.size).to eq(1)
        expect(entrypoints.first).to be_a(Lutaml::Xsd::SchemaClassificationInfo)
        expect(entrypoints.first.category).to eq(:entrypoint)
        expect(entrypoints.first.location).to eq(schema1_path)
      end

      it "classifies dependency schemas correctly" do
        result = classifier.classify
        dependencies = result[:dependency_schemas]

        expect(dependencies.size).to eq(1)
        expect(dependencies.first).to be_a(Lutaml::Xsd::SchemaClassificationInfo)
        expect(dependencies.first.category).to eq(:dependency)
        expect(dependencies.first.location).to eq(schema2_path)
      end

      it "generates accurate summary statistics" do
        result = classifier.classify
        summary = result[:summary]

        expect(summary[:total_schemas]).to eq(2)
        expect(summary[:entrypoint_count]).to eq(1)
        expect(summary[:dependency_count]).to eq(1)
        expect(summary[:fully_resolved_count]).to eq(2)
        expect(summary[:partially_resolved_count]).to eq(0)
        expect(summary[:resolution_percentage]).to eq(100.0)
      end
    end
  end

  describe "private methods exposed through #classify" do
    context "calculate_resolution_percentage via summary" do
      # Empty repository exercises total=0 → 0.0
      it "returns 0 for zero total" do
        expect(classifier.classify[:summary][:resolution_percentage]).to eq(0.0)
      end
    end

    context "determine_category via classify results" do
      let(:entry_schema) { xsd_schema(target_namespace: "http://example.com/a") }
      let(:dep_schema) { xsd_schema(target_namespace: "http://example.com/b") }

      before do
        repository.parsed_schemas.set("/path/to/schema.xsd", entry_schema)
        repository.parsed_schemas.set("/path/to/other.xsd", dep_schema)
        repository.files = ["/path/to/schema.xsd"]
      end

      it "classifies entrypoint vs dependency correctly" do
        result = classifier.classify
        entry_paths = result[:entrypoint_schemas].map(&:location)
        dep_paths = result[:dependency_schemas].map(&:location)

        expect(entry_paths).to include("/path/to/schema.xsd")
        expect(dep_paths).to include("/path/to/other.xsd")
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::SchemaClassificationInfo do
  # Reset the class-level processed-schemas cache before each test so we
  # drive real state rather than rely on cross-test leakage.
  before { Lutaml::Xml::Schema::Xsd::Schema.reset_processed_schemas }

  let(:location) { "/path/to/schema.xsd" }
  let(:category) { :entrypoint }

  let(:base_schema) { xsd_schema(target_namespace: "http://example.com/schema") }

  let(:info) do
    described_class.new(schema: base_schema, location: location, category: category)
  end

  describe "#initialize" do
    it "extracts basic information from schema" do
      expect(info.location).to eq(location)
      expect(info.category).to eq(category)
      expect(info.namespace).to eq("http://example.com/schema")
    end

    it "counts elements correctly" do
      schema = xsd_schema(
        target_namespace: "http://example.com/schema",
        elements: [
          Lutaml::Xml::Schema::Xsd::Element.new(name: "a"),
          Lutaml::Xml::Schema::Xsd::Element.new(name: "b"),
          Lutaml::Xml::Schema::Xsd::Element.new(name: "c"),
        ],
      )
      info = described_class.new(schema: schema, location: location, category: category)

      expect(info.elements_count).to eq(3)
    end

    it "counts types correctly" do
      schema = xsd_schema(
        target_namespace: "http://example.com/schema",
        complex_types: [
          Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "C1"),
          Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "C2"),
        ],
        simple_types: [
          Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "S1"),
          Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "S2"),
          Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "S3"),
        ],
      )
      info = described_class.new(schema: schema, location: location, category: category)

      expect(info.types_count).to eq(5)
    end
  end

  describe "#fully_resolved?" do
    context "with no external references" do
      it "returns true" do
        expect(info.fully_resolved?).to be true
      end
    end

    context "with unresolved external references" do
      let(:unresolved_path) { "/path/to/unresolved.xsd" }

      let(:schema) do
        s = xsd_schema(target_namespace: "http://example.com/schema")
        s.import << Lutaml::Xml::Schema::Xsd::Import.new(
          namespace: "http://example.com/other",
          schema_path: unresolved_path,
        )
        s
      end

      # Real state: don't mark unresolved_path as processed.
      let(:info) do
        described_class.new(schema: schema, location: location, category: category)
      end

      it "returns false" do
        expect(info.fully_resolved?).to be false
      end
    end
  end

  describe "#partially_resolved?" do
    it "is opposite of fully_resolved?" do
      expect(info.partially_resolved?).to eq(!info.fully_resolved?)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = info.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:location]).to eq(location)
      expect(hash[:filename]).to eq("schema.xsd")
      expect(hash[:category]).to eq(category)
      expect(hash[:namespace]).to eq("http://example.com/schema")
      expect(hash[:elements_count]).to eq(0)
      expect(hash[:types_count]).to eq(0)
      expect(%i[fully_resolved
                partially_resolved]).to include(hash[:resolution_status])
    end

    it "handles nil namespace" do
      schema = Lutaml::Xml::Schema::Xsd::Schema.new
      info = described_class.new(schema: schema, location: location, category: category)
      hash = info.to_h

      expect(hash[:namespace]).to eq("(no namespace)")
    end

    it "includes correct counts" do
      schema = xsd_schema(
        target_namespace: "http://example.com/schema",
        elements: [
          Lutaml::Xml::Schema::Xsd::Element.new(name: "a"),
          Lutaml::Xml::Schema::Xsd::Element.new(name: "b"),
        ],
        complex_types: [
          Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "c1"),
          Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "c2"),
          Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "c3"),
        ],
        simple_types: [
          Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "s1"),
        ],
      )
      schema.import << Lutaml::Xml::Schema::Xsd::Import.new(namespace: "ns1")
      schema.import << Lutaml::Xml::Schema::Xsd::Import.new(namespace: "ns2")
      schema.include << Lutaml::Xml::Schema::Xsd::Include.new

      info = described_class.new(schema: schema, location: location, category: category)
      hash = info.to_h

      expect(hash[:elements_count]).to eq(2)
      expect(hash[:complex_types_count]).to eq(3)
      expect(hash[:simple_types_count]).to eq(1)
      expect(hash[:types_count]).to eq(4)
      expect(hash[:imports_count]).to eq(2)
      expect(hash[:includes_count]).to eq(1)
    end
  end

  describe "external references extraction" do
    let(:import_path) { "/path/to/import.xsd" }
    let(:include_path) { "/path/to/include.xsd" }

    let(:schema) do
      s = xsd_schema(target_namespace: "http://example.com/schema")
      s.import << Lutaml::Xml::Schema::Xsd::Import.new(
        namespace: "http://example.com/import",
        schema_path: import_path,
      )
      s.include << Lutaml::Xml::Schema::Xsd::Include.new(schema_path: include_path)
      s
    end

    # Mark both refs as processed so resolution_status is fully_resolved
    # and we can focus on the count.
    before do
      Lutaml::Xml::Schema::Xsd::Schema.schema_processed(import_path, schema)
      Lutaml::Xml::Schema::Xsd::Schema.schema_processed(include_path, schema)
    end

    it "extracts import references" do
      info = described_class.new(schema: schema, location: location, category: category)
      hash = info.to_h

      expect(hash[:external_refs_count]).to eq(2)
    end
  end

  describe "resolution status determination" do
    context "with all references resolved" do
      let(:import_path) { "/path/to/import.xsd" }

      let(:schema) do
        s = xsd_schema(target_namespace: "http://example.com/schema")
        s.import << Lutaml::Xml::Schema::Xsd::Import.new(
          namespace: "http://example.com/import",
          schema_path: import_path,
        )
        s
      end

      # Drive real state: register the import path as processed.
      before do
        Lutaml::Xml::Schema::Xsd::Schema.schema_processed(import_path, schema)
      end

      it "sets status to fully_resolved" do
        info = described_class.new(schema: schema, location: location, category: category)
        expect(info.to_h[:resolution_status]).to eq(:fully_resolved)
      end
    end

    context "with unresolved references" do
      let(:unresolved_path) { "/path/to/unresolved.xsd" }

      let(:schema) do
        s = xsd_schema(target_namespace: "http://example.com/schema")
        s.import << Lutaml::Xml::Schema::Xsd::Import.new(
          namespace: "http://example.com/import",
          schema_path: unresolved_path,
        )
        s
      end

      it "sets status to partially_resolved" do
        info = described_class.new(schema: schema, location: location, category: category)
        expect(info.to_h[:resolution_status]).to eq(:partially_resolved)
      end
    end
  end
end
