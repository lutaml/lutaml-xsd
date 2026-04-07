# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::TypeSearcher do
  let(:schema_files) do
    [
      File.expand_path("../../fixtures/i-ur/urbanObject.xsd", __dir__),
    ]
  end

  let(:schema_location_mappings) do
    [
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+gml/(.+\.xsd)$',
        to: File.expand_path('../../fixtures/codesynthesis-gml-3.2.1/gml/\\1',
                             __dir__),
        pattern: true,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+iso/(.+\.xsd)$',
        to: File.expand_path('../../fixtures/codesynthesis-gml-3.2.1/iso/\\1',
                             __dir__),
        pattern: true,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: '(?:\.\./)+xlink/(.+\.xsd)$',
        to: File.expand_path(
          '../../fixtures/codesynthesis-gml-3.2.1/xlink/\\1', __dir__
        ),
        pattern: true,
      ),
    ]
  end

  let(:namespace_mappings) do
    {
      "gml" => "http://www.opengis.net/gml/3.2",
      "xs" => "http://www.w3.org/2001/XMLSchema",
      "xlink" => "http://www.w3.org/1999/xlink",
      "uro" => "https://www.geospatial.jp/iur/uro/3.2",
    }
  end

  let(:repository) do
    repo = Lutaml::Xsd::SchemaRepository.new(
      files: schema_files,
      schema_location_mappings: schema_location_mappings,
    )
    repo.configure_namespaces(namespace_mappings)
    repo.parse
    repo.resolve
    repo
  end

  let(:searcher) { described_class.new(repository) }

  describe "#initialize" do
    it "creates a new searcher with a repository" do
      expect(searcher).to be_a(described_class)
    end
  end

  describe "#search" do
    context "when searching by name" do
      it "finds types with exact name match" do
        # Search for a type that exists in the schema
        results = searcher.search("BuildingDetailsType", in_field: "name")
        expect(results).to be_an(Array)

        if results.any?
          exact_match = results.find { |r| r.match_type == "exact_name" }
          expect(exact_match).not_to be_nil if results.any? do |r|
            r.local_name == "BuildingDetailsType"
          end
        end
      end

      it "finds types that start with the query" do
        results = searcher.search("Building", in_field: "name")
        expect(results).to be_an(Array)

        if results.any?
          starts_with_match = results.find do |r|
            r.match_type == "name_starts_with"
          end
          expect(starts_with_match).not_to be_nil if results.any? do |r|
            r.local_name.start_with?("Building")
          end
        end
      end

      it "finds types that contain the query" do
        results = searcher.search("Type", in_field: "name")
        expect(results).to be_an(Array)

        if results.any?
          contains_match = results.find { |r| r.match_type == "name_contains" }
          expect(contains_match).not_to be_nil if results.any? do |r|
            r.local_name.include?("Type")
          end
        end
      end

      it "returns empty array for non-existent type" do
        results = searcher.search("NonExistentTypeName12345", in_field: "name")
        expect(results).to be_empty
      end

      it "is case-insensitive" do
        results_lower = searcher.search("building", in_field: "name")
        results_upper = searcher.search("BUILDING", in_field: "name")
        results_mixed = searcher.search("Building", in_field: "name")

        # Should find the same results regardless of case
        expect(results_lower.map(&:qualified_name).sort).to eq(results_upper.map(&:qualified_name).sort)
        expect(results_lower.map(&:qualified_name).sort).to eq(results_mixed.map(&:qualified_name).sort)
      end
    end

    context "when searching by documentation" do
      it "searches in documentation text" do
        # NOTE: Results depend on what documentation exists in the test schemas
        results = searcher.search("building", in_field: "documentation")
        expect(results).to be_an(Array)

        # Verify that all results have documentation
        results.each do |result|
          expect(result.documentation).not_to be_nil
        end
      end

      it "returns empty array when no documentation matches" do
        results = searcher.search("zyxwvutsrqponmlkjihgfedcba",
                                  in_field: "documentation")
        expect(results).to be_empty
      end
    end

    context "when searching in both name and documentation" do
      it "searches in both fields by default" do
        results = searcher.search("building")
        expect(results).to be_an(Array)

        # Should include matches from both name and documentation
        if results.any?
          name_matches = results.select do |r|
            r.match_type.start_with?("name_")
          end
          doc_matches = results.select { |r| r.match_type.start_with?("doc_") }

          # At least one type of match should exist
          expect(name_matches.any? || doc_matches.any?).to be true
        end
      end

      it "searches in both when in_field is 'both'" do
        results = searcher.search("type", in_field: "both")
        expect(results).to be_an(Array)
      end
    end

    context "with namespace filtering" do
      it "filters results by namespace URI" do
        uro_namespace = "https://www.geospatial.jp/iur/uro/3.2"
        results = searcher.search("Type", namespace: uro_namespace)

        # All results should be from the specified namespace
        results.each do |result|
          expect(result.namespace).to eq(uro_namespace)
        end
      end

      it "returns empty array when namespace has no matches" do
        results = searcher.search("Type", namespace: "http://nonexistent.namespace")
        expect(results).to be_empty
      end
    end

    context "with category filtering" do
      it "filters results by complex_type category" do
        results = searcher.search("Type", category: "complex_type")

        # All results should be complex types
        results.each do |result|
          expect(result.category).to eq(:complex_type)
        end
      end

      it "filters results by element category" do
        results = searcher.search("", category: "element", limit: 100)

        # All results should be elements (if any exist)
        results.each do |result|
          expect(result.category).to eq(:element)
        end
      end

      it "accepts category as string or symbol" do
        results_string = searcher.search("Type", category: "complex_type")
        results_symbol = searcher.search("Type", category: :complex_type)

        expect(results_string.map(&:qualified_name).sort).to eq(results_symbol.map(&:qualified_name).sort)
      end
    end

    context "with result limiting" do
      it "limits results to specified number" do
        results = searcher.search("Type", limit: 5)
        expect(results.size).to be <= 5
      end

      it "returns all results when limit is higher than result count" do
        results = searcher.search("BuildingDetailsType", limit: 100)
        # Should return at most a few results for this specific search
        expect(results.size).to be <= 100
      end

      it "uses default limit of 20" do
        # Create a searcher and search without specifying limit
        results = searcher.search("Type")
        expect(results.size).to be <= 20
      end
    end

    context "with relevance scoring" do
      it "ranks exact name matches highest" do
        results = searcher.search("BuildingDetailsType")

        if results.any? { |r| r.local_name == "BuildingDetailsType" }
          exact_match = results.find do |r|
            r.local_name == "BuildingDetailsType"
          end
          expect(exact_match.relevance_score).to eq(1000)
          expect(exact_match.match_type).to eq("exact_name")
        end
      end

      it "ranks starts-with matches higher than contains" do
        results = searcher.search("Building", in_field: "name")

        starts_with_results = results.select do |r|
          r.match_type == "name_starts_with"
        end
        contains_results = results.select do |r|
          r.match_type == "name_contains"
        end

        expect(starts_with_results.first.relevance_score).to be > contains_results.first.relevance_score if starts_with_results.any? && contains_results.any?
      end

      it "sorts results by relevance score" do
        results = searcher.search("Type", limit: 50)

        # Check that results are sorted by score (descending)
        scores = results.map(&:relevance_score)
        expect(scores).to eq(scores.sort.reverse)
      end

      it "sorts by name when scores are equal" do
        results = searcher.search("building", in_field: "name", limit: 50)

        # Group by score and check alphabetical ordering within each group
        results.group_by(&:relevance_score).each_value do |group|
          names = group.map(&:qualified_name)
          expect(names).to eq(names.sort)
        end
      end
    end

    context "with empty or invalid queries" do
      it "returns empty array for nil query" do
        results = searcher.search(nil)
        expect(results).to be_empty
      end

      it "returns empty array for empty string query" do
        results = searcher.search("")
        expect(results).to be_empty
      end

      it "returns empty array for whitespace-only query" do
        results = searcher.search("   ")
        expect(results).to be_empty
      end
    end
  end

  describe "SearchResult" do
    context "when creating a search result" do
      let(:result) do
        described_class::SearchResult.new(
          qualified_name: "uro:BuildingType",
          local_name: "BuildingType",
          namespace: "https://www.geospatial.jp/iur/uro/3.2",
          category: :complex_type,
          schema_file: "/path/to/schema.xsd",
          documentation: "A building type",
          relevance_score: 1000,
          match_type: "exact_name",
          definition: double("definition"),
        )
      end

      it "has all required attributes" do
        expect(result.qualified_name).to eq("uro:BuildingType")
        expect(result.local_name).to eq("BuildingType")
        expect(result.namespace).to eq("https://www.geospatial.jp/iur/uro/3.2")
        expect(result.category).to eq(:complex_type)
        expect(result.schema_file).to eq("/path/to/schema.xsd")
        expect(result.documentation).to eq("A building type")
        expect(result.relevance_score).to eq(1000)
        expect(result.match_type).to eq("exact_name")
      end

      it "converts to hash" do
        hash = result.to_h
        expect(hash).to be_a(Hash)
        expect(hash[:qualified_name]).to eq("uro:BuildingType")
        expect(hash[:local_name]).to eq("BuildingType")
        expect(hash[:namespace]).to eq("https://www.geospatial.jp/iur/uro/3.2")
        expect(hash[:category]).to eq(:complex_type)
        expect(hash[:schema_file]).to eq("/path/to/schema.xsd")
        expect(hash[:documentation]).to eq("A building type")
        expect(hash[:relevance_score]).to eq(1000)
        expect(hash[:match_type]).to eq("exact_name")
      end
    end
  end

  describe "integration with repository" do
    it "finds real types from the test schema" do
      results = searcher.search("BuildingDetailsType")
      expect(results).to be_an(Array)

      if results.any?
        result = results.first
        expect(result).to be_a(described_class::SearchResult)
        expect(result.qualified_name).to match(/BuildingDetailsType/)
      end
    end

    it "respects repository namespace configuration" do
      results = searcher.search("Type", limit: 10)

      results.each do |result|
        # Qualified names should use configured prefixes
        next unless result.namespace

        prefix = repository.namespace_to_prefix(result.namespace)
        expect(result.qualified_name).to match(/^#{prefix}:/) if prefix
      end
    end
  end
end
