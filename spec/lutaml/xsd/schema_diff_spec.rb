# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "json"

FIXTURE_DIR = File.expand_path("../../fixtures/schema_diff", __dir__)

RSpec.describe Lutaml::Xsd::SchemaDiff do
  # The engine consumes repositories' OWNED schemas (isolated from
  # the process-global cache); the fixture repos register their
  # schemas through the ownership API (real parsed models).
  def build_repository(paths)
    repo = Lutaml::Xsd::SchemaRepository.new
    paths.each do |path|
      schema = Lutaml::Xml::Schema::Xsd.parse(File.read(path), location: path)
      repo.register_owned_schema(path, schema)
    end
    repo
  end

  def version_repo(version)
    build_repository(Dir.glob(File.join(FIXTURE_DIR, version, "*.xsd")))
  end

  let(:changeset) do
    described_class.new(version_repo("v1"), version_repo("v2")).diff
  end

  def change_for(category, local_name)
    changeset.changes.find do |c|
      c.category == category && c.local_name == local_name
    end
  end

  it "captures every taxonomy branch in the summary" do
    expect(changeset.summary).to eq(
      "added" => 2,
      "modified" => 6,
      "moved_namespace" => 1,
      "renamed" => 1,
    )
  end

  it "reports modified components with their modifications" do
    base = change_for("modified", "BaseType")
    expect(base.modifications.map(&:aspect)).to contain_exactly("attributes",
                                                                "particles")
    expect(base.modifications.map(&:new)).to contain_exactly("version", "gamma")

    element = change_for("modified", "document")
    expect(element.modifications).to contain_exactly(
      have_attributes(aspect: "type", old: "tns:BaseType",
                      new: "tns:DerivedType"),
    )

    attribute = change_for("modified", "mode")
    expect(attribute.modifications).to contain_exactly(
      have_attributes(aspect: "use", old: "optional", new: "required"),
    )

    level = change_for("modified", "LevelType")
    expect(level.modifications.map(&:new)).to contain_exactly("enumeration=medium")
  end

  it "pairs a pure rename by fingerprint" do
    renamed = change_for("renamed", "NewNameType")
    expect(renamed).not_to be_nil
    expect(renamed.renamed_from).to end_with("OldNameType")
  end

  it "pairs a namespace move across corpora" do
    moved = change_for("moved_namespace", "MoveTargetType")
    expect(moved).not_to be_nil
    expect(moved.namespace).to eq("http://example.com/diff-new")
    expect(moved.renamed_from).to eq("{http://example.com/diff-old}MoveTargetType")
  end

  it "normalizes namespaces through the namespace map" do
    remapped = described_class.new(
      build_repository([File.join(FIXTURE_DIR, "v1", "moved.xsd")]),
      build_repository([File.join(FIXTURE_DIR, "v2", "moved.xsd")]),
      namespace_map: {
        "http://example.com/diff-old" => "http://example.com/diff-new",
      },
    ).diff

    expect(remapped.summary).to be_empty
  end

  it "matches the golden ChangeSet contract" do
    golden = JSON.parse(
      File.read(File.join(FIXTURE_DIR, "golden_changeset.json")),
    )
    expect(JSON.parse(changeset.to_json)).to eq(golden)
  end
end
