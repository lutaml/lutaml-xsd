# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/package_loader"

RSpec.describe Lutaml::Xsd::PackageLoader do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:parser) { Lutaml::Xsd::SchemaParser.new(repository) }
  let(:loader) { described_class.new(parser: parser, repository: repository) }

  describe "#normalize_base_packages_to_configs" do
    subject(:configs) { loader.normalize_base_packages_to_configs }

    it "returns an empty array when no base_packages are configured" do
      expect(configs).to eq([])
    end

    context "with String entries" do
      before { repository.base_packages = ["/tmp/a.lxr", "/tmp/b.lxr"] }

      it "wraps each String into a BasePackageConfig" do
        expect(configs).to all(be_a(Lutaml::Xsd::BasePackageConfig))
        expect(configs.map(&:package)).to eq(["/tmp/a.lxr", "/tmp/b.lxr"])
      end
    end

    context "with Hash entries" do
      before do
        repository.base_packages = [
          { "package" => "/tmp/a.lxr", "priority" => 5 },
          { package: "/tmp/b.lxr", conflict_resolution: "override" },
        ]
      end

      it "symbolizes keys and wraps into BasePackageConfig" do
        expect(configs).to all(be_a(Lutaml::Xsd::BasePackageConfig))
        expect(configs.first.package).to eq("/tmp/a.lxr")
        expect(configs.first.priority).to eq(5)
        expect(configs.last.package).to eq("/tmp/b.lxr")
        expect(configs.last.conflict_resolution.to_s).to eq("override")
      end
    end

    context "with BasePackageConfig entries" do
      let(:existing) { Lutaml::Xsd::BasePackageConfig.new(package: "/tmp/x.lxr") }

      before { repository.base_packages = [existing] }

      it "passes them through unchanged" do
        expect(configs).to eq([existing])
      end
    end

    context "with unknown entry types" do
      before { repository.base_packages = [123] }

      it "coerces to string and wraps" do
        expect(configs.first).to be_a(Lutaml::Xsd::BasePackageConfig)
        expect(configs.first.package).to eq("123")
      end
    end
  end

  describe "#load", if: File.exist?("spec/fixtures/test_schema.lxr") do
    let(:lxr_path) do
      File.expand_path("../../fixtures/test_schema.lxr", __dir__)
    end

    before do
      repository.base_packages = [
        Lutaml::Xsd::BasePackageConfig.new(
          package: lxr_path,
          priority: 0,
          conflict_resolution: :keep,
        ),
      ]
    end

    it "loads package schemas into the repository store" do
      loader.load([])
      expect(repository.parsed_schemas.all).not_to be_empty
    end

    it "registers each file from the package" do
      loader.load([])
      expect(repository.files).not_to be_empty
    end
  end
end
