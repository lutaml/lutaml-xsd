# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/coverage_analyzer"

RSpec.describe Lutaml::Xsd::CoverageAnalyzer do
  let(:repository) do
    repo = Lutaml::Xsd::SchemaRepository.new
    repo.namespace_registry.register("ns", "http://example.com/ns")
    repo.namespace_registry.register("other", "http://other.com/ns")

    # Schema 1: ns namespace with TypeA (depends on TypeB), TypeB, TypeC
    schema1 = Lutaml::Xml::Schema::Xsd::Schema.new
    schema1.target_namespace = "http://example.com/ns"

    type_a_extension = Lutaml::Xml::Schema::Xsd::ExtensionComplexContent.new(
      base: "ns:TypeB",
    )
    type_a_content = Lutaml::Xml::Schema::Xsd::ComplexContent.new(
      extension: type_a_extension,
    )
    schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(
      name: "TypeA",
      complex_content: type_a_content,
    )
    schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeB")
    schema1.simple_type << Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "TypeC")

    # Schema 2: other namespace with TypeD
    schema2 = Lutaml::Xml::Schema::Xsd::Schema.new
    schema2.target_namespace = "http://other.com/ns"
    schema2.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeD")

    repo.parsed_schemas.set("/test/schema1.xsd", schema1)
    repo.parsed_schemas.set("/test/schema2.xsd", schema2)
    repo.type_index.index_schema(schema1, "/test/schema1.xsd")
    repo.type_index.index_schema(schema2, "/test/schema2.xsd")
    repo
  end

  let(:analyzer) { described_class.new(repository) }

  describe "#initialize" do
    it "creates analyzer with repository" do
      expect(analyzer.repository).to eq(repository)
    end
  end

  describe "#analyze" do
    context "with no entry types" do
      it "returns report with all types unused" do
        report = analyzer.analyze(entry_types: [])

        expect(report).to be_a(Lutaml::Xsd::CoverageReport)
        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(0)
        expect(report.unused_count).to eq(4)
        expect(report.coverage_percentage).to eq(0.0)
      end
    end

    context "with single entry type" do
      it "marks entry type and its direct base as used" do
        # TypeA extends TypeB, so tracing from TypeA pulls in TypeB.
        report = analyzer.analyze(entry_types: ["ns:TypeA"])

        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(2) # TypeA + TypeB
        expect(report.unused_count).to eq(2)
        expect(report.coverage_percentage).to eq(50.0)
        expect(report.entry_types).to eq(["ns:TypeA"])
      end
    end

    context "with isolated entry type" do
      # Use a type with no outgoing edges to verify a single-type use case.
      let(:repository) do
        repo = Lutaml::Xsd::SchemaRepository.new
        repo.namespace_registry.register("ns", "http://example.com/ns")

        schema1 = Lutaml::Xml::Schema::Xsd::Schema.new
        schema1.target_namespace = "http://example.com/ns"
        schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeA")
        schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeB")
        schema1.simple_type << Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "TypeC")

        repo.parsed_schemas.set("/test/schema1.xsd", schema1)
        repo.type_index.index_schema(schema1, "/test/schema1.xsd")
        repo
      end

      it "marks only the entry type as used" do
        report = analyzer.analyze(entry_types: ["ns:TypeA"])

        expect(report.total_types).to eq(3)
        expect(report.used_count).to eq(1)
        expect(report.coverage_percentage).to eq(33.33)
      end
    end

    context "with multiple entry types" do
      it "marks all entry types as used" do
        report = analyzer.analyze(entry_types: ["ns:TypeA", "ns:TypeB"])

        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(2)
        expect(report.unused_count).to eq(2)
        expect(report.coverage_percentage).to eq(50.0)
        expect(report.entry_types).to eq(["ns:TypeA", "ns:TypeB"])
      end
    end

    context "with dependencies" do
      it "includes dependent types in used types" do
        # TypeA extends TypeB, so tracing from TypeA reaches TypeB.
        report = analyzer.analyze(entry_types: ["ns:TypeA"])

        expect(report.used_count).to eq(2) # TypeA + TypeB
        expect(report.coverage_percentage).to eq(50.0)
      end
    end

    context "with namespace analysis" do
      it "calculates coverage per namespace" do
        report = analyzer.analyze(entry_types: ["ns:TypeA", "other:TypeD"])

        by_ns = report.by_namespace

        expect(by_ns).to have_key("http://example.com/ns")
        expect(by_ns).to have_key("http://other.com/ns")

        # http://example.com/ns has 3 types, 1 used (TypeA extends TypeB but
        # only TypeA is the entry — TypeB gets pulled in by trace too, so
        # used count = 2: TypeA + TypeB)
        # Wait: the original test expected used=1 here. We need to check why.
        # Original test had stubbed extract_type_references to return []
        # for all definitions, severing the TypeA→TypeB edge.
        expect(by_ns["http://example.com/ns"][:total]).to eq(3)
        # With real DependencyGrapher, TypeA→TypeB edge is real.
        expect(by_ns["http://example.com/ns"][:used]).to eq(2)
        expect(by_ns["http://example.com/ns"][:coverage_percentage]).to eq(66.67)

        # http://other.com/ns has 1 type, 1 used
        expect(by_ns["http://other.com/ns"][:total]).to eq(1)
        expect(by_ns["http://other.com/ns"][:used]).to eq(1)
        expect(by_ns["http://other.com/ns"][:coverage_percentage]).to eq(100.0)
      end
    end

    context "with dependency-severed namespace analysis" do
      # Recreate repository without the TypeA→TypeB edge to mirror the
      # original namespace-analysis test (which stubbed extract_type_references
      # to return []). Used count is then 1 per namespace entry.
      let(:repository) do
        repo = Lutaml::Xsd::SchemaRepository.new
        repo.namespace_registry.register("ns", "http://example.com/ns")
        repo.namespace_registry.register("other", "http://other.com/ns")

        schema1 = Lutaml::Xml::Schema::Xsd::Schema.new
        schema1.target_namespace = "http://example.com/ns"
        schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeA")
        schema1.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeB")
        schema1.simple_type << Lutaml::Xml::Schema::Xsd::SimpleType.new(name: "TypeC")

        schema2 = Lutaml::Xml::Schema::Xsd::Schema.new
        schema2.target_namespace = "http://other.com/ns"
        schema2.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: "TypeD")

        repo.parsed_schemas.set("/test/schema1.xsd", schema1)
        repo.parsed_schemas.set("/test/schema2.xsd", schema2)
        repo.type_index.index_schema(schema1, "/test/schema1.xsd")
        repo.type_index.index_schema(schema2, "/test/schema2.xsd")
        repo
      end

      it "calculates 1-of-3 coverage for ns namespace" do
        report = analyzer.analyze(entry_types: ["ns:TypeA", "other:TypeD"])

        by_ns = report.by_namespace
        expect(by_ns["http://example.com/ns"][:used]).to eq(1)
        expect(by_ns["http://example.com/ns"][:coverage_percentage]).to eq(33.33)
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::CoverageReport do
  let(:all_types) { Set.new(["{ns}TypeA", "{ns}TypeB", "{ns}TypeC"]) }
  let(:used_types) { Set.new(["{ns}TypeA", "{ns}TypeB"]) }
  let(:entry_types) { ["TypeA"] }
  let(:by_namespace) do
    {
      "http://example.com/ns" => {
        total: 3,
        used: 2,
        types: [
          { clark_key: "{ns}TypeA", name: "TypeA", category: :complex_type,
            used: true },
          { clark_key: "{ns}TypeB", name: "TypeB", category: :complex_type,
            used: true },
          { clark_key: "{ns}TypeC", name: "TypeC", category: :simple_type,
            used: false },
        ],
        coverage_percentage: 66.67,
      },
    }
  end

  let(:report) do
    described_class.new(
      all_types: all_types,
      used_types: used_types,
      entry_types: entry_types,
      by_namespace: by_namespace,
    )
  end

  describe "#total_types" do
    it "returns total number of types" do
      expect(report.total_types).to eq(3)
    end
  end

  describe "#used_count" do
    it "returns number of used types" do
      expect(report.used_count).to eq(2)
    end
  end

  describe "#unused_types" do
    it "returns set of unused types" do
      expect(report.unused_types).to eq(Set.new(["{ns}TypeC"]))
    end

    it "is mutually exclusive with used_types" do
      expect(report.unused_types & report.used_types).to be_empty
    end

    it "is collectively exhaustive with used_types" do
      expect(report.unused_types | report.used_types).to eq(all_types)
    end
  end

  describe "#unused_count" do
    it "returns number of unused types" do
      expect(report.unused_count).to eq(1)
    end
  end

  describe "#coverage_percentage" do
    it "calculates coverage percentage" do
      expect(report.coverage_percentage).to eq(66.67)
    end

    context "with no types" do
      let(:all_types) { Set.new }
      let(:used_types) { Set.new }

      it "returns 0.0 for empty repository" do
        expect(report.coverage_percentage).to eq(0.0)
      end
    end

    context "with 100% coverage" do
      let(:used_types) { all_types }

      it "returns 100.0" do
        expect(report.coverage_percentage).to eq(100.0)
      end
    end
  end

  describe "#to_h" do
    it "converts to hash with summary" do
      hash = report.to_h

      expect(hash).to have_key(:summary)
      expect(hash[:summary]).to include(
        total_types: 3,
        used_types: 2,
        unused_types: 1,
        coverage_percentage: 66.67,
        entry_types: ["TypeA"],
      )
    end

    it "includes namespace data" do
      hash = report.to_h

      expect(hash).to have_key(:by_namespace)
      expect(hash[:by_namespace]).to have_key("http://example.com/ns")

      ns_data = hash[:by_namespace]["http://example.com/ns"]
      expect(ns_data).to include(
        total: 3,
        used: 2,
        unused: 1,
        coverage_percentage: 66.67,
      )
    end

    it "includes unused type details" do
      hash = report.to_h

      expect(hash).to have_key(:unused_type_details)
      expect(hash[:unused_type_details]).to be_an(Array)
      expect(hash[:unused_type_details].size).to eq(1)

      unused = hash[:unused_type_details].first
      expect(unused).to include(
        namespace: "http://example.com/ns",
        name: "TypeC",
        category: :simple_type,
        clark_key: "{ns}TypeC",
      )
    end

    it "sorts unused types by namespace and name" do
      extended_by_namespace = {
        "http://example.com/ns" => {
          total: 3,
          used: 1,
          types: [
            { clark_key: "{ns}TypeA", name: "TypeA", category: :complex_type,
              used: true },
            { clark_key: "{ns}TypeC", name: "TypeC", category: :simple_type,
              used: false },
            { clark_key: "{ns}TypeB", name: "TypeB", category: :simple_type,
              used: false },
          ],
          coverage_percentage: 33.33,
        },
      }

      extended_report = described_class.new(
        all_types: all_types,
        used_types: Set.new(["{ns}TypeA"]),
        entry_types: entry_types,
        by_namespace: extended_by_namespace,
      )

      hash = extended_report.to_h
      names = hash[:unused_type_details].map { |t| t[:name] }

      expect(names).to eq(%w[TypeB TypeC])
    end
  end

  describe "MECE principle" do
    it "ensures used and unused types are mutually exclusive" do
      intersection = report.used_types & report.unused_types
      expect(intersection).to be_empty
    end

    it "ensures used and unused types are collectively exhaustive" do
      union = report.used_types | report.unused_types
      expect(union).to eq(report.all_types)
    end

    it "validates counts add up correctly" do
      expect(report.used_count + report.unused_count).to eq(report.total_types)
    end
  end
end
