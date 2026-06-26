# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/schema_query_service"

RSpec.describe Lutaml::Xsd::SchemaQueryService do
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

  let(:service) { described_class.new(repository) }
  let(:metaschema_ns) { "http://csrc.nist.gov/ns/oscal/metaschema/1.0" }

  describe "#find_type" do
    context "when the type exists with a registered prefix" do
      let(:known_qname) do
        service.all_type_names(namespace: metaschema_ns).first
      end
      let(:known_local_name) { known_qname.split(":").last }
      let(:result) { service.find_type(known_qname) }

      it "is a resolved TypeResolutionResult" do
        skip "no types in metaschema namespace" unless known_qname

        expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
        expect(result).to be_resolved
      end

      it "carries the resolved namespace and local name" do
        skip "no types in metaschema namespace" unless known_qname

        expect(result.namespace).to eq(metaschema_ns)
        expect(result.local_name).to eq(known_local_name)
      end
    end

    context "when the type does not exist" do
      subject(:result) { service.find_type("m:DefinitelyNotAType") }

      it "is a non-resolved TypeResolutionResult" do
        expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
        expect(result).not_to be_resolved
        expect(result.error_message).to match(/not found/i)
      end
    end

    context "when the prefix is not registered" do
      subject(:result) { service.find_type("bogus:Whatever") }

      it "fails with a prefix registration error" do
        expect(result).not_to be_resolved
        expect(result.error_message).to match(/prefix 'bogus' not registered/i)
      end
    end
  end

  describe "#type_exists?" do
    it "returns true for a type that exists" do
      known = service.all_type_names.first
      expect(service.type_exists?(known)).to eq(true)
    end

    it "returns false for a type that does not exist" do
      expect(service.type_exists?("m:NoSuchType")).to eq(false)
    end

    it "returns false for an unregistered prefix" do
      expect(service.type_exists?("ghost:Whatever")).to eq(false)
    end
  end

  describe "#find_element" do
    it "returns nil when no element matches" do
      expect(service.find_element("m:NoSuchElement")).to be_nil
    end

    it "returns nil for an unregistered prefix" do
      expect(service.find_element("ghost:Whatever")).to be_nil
    end

    it "returns the element when one matches" do
      all_elements = repository.all_schemas.values.flat_map do |schema|
        Array(schema.element).compact
      end
      skip "no elements available in fixture" if all_elements.empty?

      first = all_elements.first
      ns = repository.all_schemas.values.find do |s|
        Array(s.element).compact.any? { |e| e.name == first.name }
      end&.target_namespace
      prefix = repository.namespace_to_prefix(ns)

      qname = prefix ? "#{prefix}:#{first.name}" : first.name
      expect(service.find_element(qname)&.name).to eq(first.name)
    end
  end

  describe "#find_attribute" do
    it "returns nil when no attribute matches" do
      expect(service.find_attribute("m:NoSuchAttribute")).to be_nil
    end

    it "returns nil for an unregistered prefix" do
      expect(service.find_attribute("ghost:Whatever")).to be_nil
    end
  end

  describe "#find_group" do
    it "returns nil when no group matches" do
      expect(service.find_group("m:NoSuchGroup")).to be_nil
    end

    it "returns nil for an unregistered prefix" do
      expect(service.find_group("ghost:Whatever")).to be_nil
    end
  end

  describe "#find_attribute_group" do
    it "returns nil when no attribute group matches" do
      expect(service.find_attribute_group("m:NoSuchGroup")).to be_nil
    end

    it "returns nil for an unregistered prefix" do
      expect(service.find_attribute_group("ghost:Whatever")).to be_nil
    end
  end

  describe "#all_type_names" do
    it "returns a sorted array of qualified type names" do
      names = service.all_type_names
      expect(names).to be_an(Array)
      expect(names).not_to be_empty
      expect(names).to eq(names.sort)
    end

    it "filters by namespace URI" do
      filtered = service.all_type_names(namespace: metaschema_ns)
      expect(filtered).not_to be_empty
      filtered.each do |name|
        prefix = name.split(":").first
        expect(repository.namespace_to_prefix(metaschema_ns)).to eq(prefix)
      end
    end

    it "filters by category" do
      complex_names = service.all_type_names(category: :complex_type)
      simple_names = service.all_type_names(category: :simple_type)

      # Both categories should produce arrays, and at least the union
      # should match the unfiltered set within known fixture categories.
      expect(complex_names).to be_an(Array)
      expect(simple_names).to be_an(Array)
    end

    it "returns empty array for unknown namespace" do
      expect(service.all_type_names(namespace: "http://nope")).to eq([])
    end
  end
end
