# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/type_hierarchy_analyzer"
require "lutaml/xsd/dependency_grapher"

RSpec.describe "analyzer loading path" do
  # The analyzers consume a repository's type index and namespace
  # registry. Those used to stay EMPTY on package loads (the resolve
  # step that builds them never ran), so every query resolved nothing.
  # The metaschema example carries a real derivation chain
  # (UseNameType > ModelNameType > TokenDatatype) through a package
  # round-trip.
  let(:package_path) do
    File.expand_path("../../../examples/04-metaschema/metaschema.lxr",
                     __dir__)
  end

  let(:repository) do
    Lutaml::Xsd::SchemaRepositoryPackage.load(package_path).load_repository
  end

  let(:analyzer) { Lutaml::Xsd::TypeHierarchyAnalyzer.new(repository) }

  let(:metaschema_ns) { "http://csrc.nist.gov/ns/oscal/metaschema/1.0" }

  def clark(local_name)
    "{#{metaschema_ns}}#{local_name}"
  end

  it "builds the type index on load" do
    expect(repository.type_index.all).not_to be_empty
    expect(repository.all_schemas).not_to be_empty
  end

  it "resolves types by Clark notation" do
    expect(repository.find_type(clark("UseNameType"))).to be_resolved
  end

  describe "derivation queries" do
    it "walks the supertype chain" do
      chain = analyzer.supertypes(clark("UseNameType"))
      locals = chain.map { |a| a[:local_name] }
      expect(locals).to include("ModelNameType")
    end

    it "answers subtype_of through the resolved chain" do
      expect(analyzer.subtype_of(clark("UseNameType"),
                                 clark("ModelNameType"))).to be(true)
      expect(analyzer.subtype_of(clark("ModelNameType"),
                                 clark("UseNameType"))).to be(false)
    end

    it "enumerates descendants by derivation base" do
      locals = analyzer.descendants(clark("ModelNameType"))
        .map { |d| d[:local_name] }
      expect(locals).to include("UseNameType")
    end

    it "returns nil for unresolvable type names" do
      expect(analyzer.supertypes("no-such:Type")).to be_nil
      expect(analyzer.descendants("no-such:Type")).to be_nil
      expect(analyzer.subtype_of("no-such:Type", clark("ModelNameType")))
        .to be_nil
    end
  end

  describe "the dependency graph" do
    it "finds the element referencing a type" do
      dependents = Lutaml::Xsd::DependencyGrapher.new(repository)
        .dependents(clark("ModelNameType"))
      locals = dependents[:dependents].map { |d| d[:local_name] }
      expect(locals).to include("UseNameType")
    end

    it "tolerates attributeGroup entries in the index" do
      # AttributeGroup definitions lack the derivation accessors; the
      # reference extraction must skip them instead of raising through
      # the model's method_missing.
      expect do
        Lutaml::Xsd::DependencyGrapher.new(repository)
          .dependents(clark("ModelNameType"))
      end.not_to raise_error
    end
  end
end
