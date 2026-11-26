# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "json"

FIXTURE_DIR = File.expand_path("../../../fixtures/schema_diff", __dir__)

RSpec.describe "spa generation with --diff" do
  # Real end-to-end: package the two fixture versions, generate the
  # SPA with --diff, and assert the embedded ChangeSet payload.
  def build_package(version, path)
    files = Dir.glob(File.join(FIXTURE_DIR, version, "*.xsd"))
      .map { |f| File.expand_path(f) }
    repo = Lutaml::Xsd::SchemaRepository.new(files: files)
    repo.parse.resolve
    repo.to_package(path, xsd_mode: :include_all,
                          resolution_mode: :resolved,
                          serialization_format: :marshal)
    path
  end

  it "embeds the component-level changeset in the payload" do
    Dir.mktmpdir do |dir|
      old_path = build_package("v1", File.join(dir, "v1.lxr"))
      new_path = build_package("v2", File.join(dir, "v2.lxr"))
      output = File.join(dir, "docs.html")

      command = Lutaml::Xsd::Commands::GenerateSpaCommand.new(
        new_path,
        { output: output, diff: old_path },
      )
      command.run

      html = File.read(output)
      marker = html.index("window.SCHEMA_DATA = ")
      expect(marker).not_to be_nil
      blob = html[marker..][/window\.SCHEMA_DATA = (\{.*?\});/m, 1]
      payload = JSON.parse(blob)

      changes = payload["diff"]["changes"]
      expect(changes.size).to eq(10)
      expect(changes.group_by { |c| c["category"] }.transform_values(&:size))
        .to eq("added" => 2, "modified" => 6,
               "moved_namespace" => 1, "renamed" => 1)

      renamed = changes.find { |c| c["category"] == "renamed" }
      expect(renamed["local_name"]).to eq("NewNameType")
      expect(renamed["renamed_from"]).to end_with("OldNameType")
    end
  end
end
