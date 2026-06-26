# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Lutaml::Xsd::PackageConflictDetector do
  let(:config1) do
    Lutaml::Xsd::BasePackageConfig.new(
      package: pkg_path("pkg1.lxr"),
      priority: 0,
      conflict_resolution: "keep",
    )
  end

  let(:config2) do
    Lutaml::Xsd::BasePackageConfig.new(
      package: pkg_path("pkg2.lxr"),
      priority: 10,
      conflict_resolution: "override",
    )
  end

  # Real repositories built via factories, wired into the detector through
  # the loader: callable seam. No File.stubbing or class-level allow.
  let(:repos_by_path) do
    {
      pkg_path("pkg1.lxr") => repo1,
      pkg_path("pkg2.lxr") => repo2,
    }
  end

  let(:loader) { ->(path) { repos_by_path[path] } }

  let(:repo1) do
    repo_with(
      namespaces: { "ns1" => "http://example.com/ns1" },
      types_by_namespace: {},
      files: ["schemas/person.xsd", "schemas/company.xsd"],
    )
  end

  let(:repo2) do
    repo_with(
      namespaces: { "ns2" => "http://example.com/ns2" },
      types_by_namespace: {},
      files: ["xsd/person.xsd", "xsd/address.xsd"],
    )
  end

  describe "#initialize" do
    it "accepts package configs array" do
      detector = described_class.new([config1, config2], loader: loader)
      expect(detector.package_configs).to eq([config1, config2])
    end
  end

  describe "#detect_conflicts" do
    context "with no conflicts" do
      let(:repo1) do
        repo_with(
          namespaces: { "ns1" => "http://example.com/ns1" },
          types_by_namespace: {},
          files: ["schemas/person.xsd"],
        )
      end

      let(:repo2) do
        repo_with(
          namespaces: { "ns2" => "http://example.com/ns2" },
          types_by_namespace: {},
          files: ["schemas/company.xsd"],
        )
      end

      it "returns report with no conflicts" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report).to be_a(Lutaml::Xsd::ConflictReport)
        expect(report.has_conflicts?).to be false
        expect(report.total_conflicts).to eq(0)
      end

      it "includes package info" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report.package_info.size).to eq(2)
        expect(report.package_info[0].package_path).to eq(pkg_path("pkg1.lxr"))
        expect(report.package_info[1].package_path).to eq(pkg_path("pkg2.lxr"))
      end
    end

    context "with namespace conflicts" do
      let(:shared_ns) { "http://example.com/shared" }

      let(:repo1) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => [] },
          files: ["schemas/person.xsd", "schemas/company.xsd"],
        )
      end

      let(:repo2) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => [] },
          files: ["xsd/person.xsd", "xsd/address.xsd"],
        )
      end

      it "detects namespace URI conflicts" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report.namespace_conflicts.size).to eq(1)
        conflict = report.namespace_conflicts.first
        expect(conflict.namespace_uri).to eq(shared_ns)
        expect(conflict.package_paths).to contain_exactly(
          pkg_path("pkg1.lxr"), pkg_path("pkg2.lxr")
        )
      end
    end

    context "with type conflicts" do
      let(:shared_ns) { "http://example.com/ns1" }

      let(:repo1) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => %w[PersonType UniqueType1] },
          files: ["schemas/person.xsd", "schemas/company.xsd"],
        )
      end

      let(:repo2) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => %w[PersonType UniqueType2] },
          files: ["xsd/person.xsd", "xsd/address.xsd"],
        )
      end

      it "detects type name conflicts" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report.type_conflicts.size).to eq(1)
        conflict = report.type_conflicts.first
        expect(conflict.type_name).to eq("ns1:PersonType")
        expect(conflict.namespace_uri).to eq(shared_ns)
        expect(conflict.package_paths).to contain_exactly(
          pkg_path("pkg1.lxr"), pkg_path("pkg2.lxr")
        )
      end
    end

    context "with schema conflicts" do
      let(:repo1) do
        repo_with(
          namespaces: {},
          types_by_namespace: {},
          files: ["schemas/person.xsd", "schemas/company.xsd"],
        )
      end

      let(:repo2) do
        repo_with(
          namespaces: {},
          types_by_namespace: {},
          files: ["xsd/person.xsd", "xsd/address.xsd"],
        )
      end

      it "detects schema file conflicts by basename" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report.schema_conflicts.size).to eq(1)
        conflict = report.schema_conflicts.first
        expect(conflict.schema_basename).to eq("person.xsd")
        expect(conflict.source_files.size).to eq(2)
        expect(conflict.file_paths).to contain_exactly(
          "schemas/person.xsd",
          "xsd/person.xsd",
        )
      end
    end

    context "with multiple conflict types" do
      let(:shared_ns) { "http://example.com/shared" }

      let(:repo1) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => %w[SharedType] },
          files: ["schemas/person.xsd", "schemas/company.xsd"],
        )
      end

      let(:repo2) do
        repo_with(
          namespaces: { "ns1" => shared_ns },
          types_by_namespace: { shared_ns => %w[SharedType] },
          files: ["xsd/person.xsd", "xsd/address.xsd"],
        )
      end

      it "detects all types of conflicts" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config1, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report.namespace_conflicts.size).to eq(1)
        expect(report.type_conflicts.size).to eq(1)
        expect(report.schema_conflicts.size).to eq(1)
        expect(report.total_conflicts).to eq(3)
      end
    end

    context "with namespace remapping" do
      let(:config_with_remap) do
        Lutaml::Xsd::BasePackageConfig.new(
          package: pkg_path("pkg1.lxr"),
          priority: 0,
          conflict_resolution: "keep",
          namespace_remapping: [
            Lutaml::Xsd::NamespaceUriRemapping.new(
              from_uri: "http://old.example.com/ns",
              to_uri: "http://new.example.com/ns",
            ),
          ],
        )
      end

      let(:repo1) do
        Lutaml::Xsd::SchemaRepository.new(
          files: ["schemas/person.xsd", "schemas/company.xsd"],
          namespace_mappings: [
            ns_mapping(prefix: "ex", uri: "http://old.example.com/ns"),
          ],
        )
      end

      it "applies namespace remapping during load" do
        touch_packages("pkg1.lxr", "pkg2.lxr")
        detector = described_class.new([config_with_remap, config2], loader: loader)
        report = detector.detect_conflicts

        expect(report).to be_a(Lutaml::Xsd::ConflictReport)
      end
    end

    context "with missing package file" do
      it "raises ConfigurationError" do
        bad_config = Lutaml::Xsd::BasePackageConfig.new(
          package: "/nonexistent/missing.lxr",
          priority: 0,
        )

        detector = described_class.new([bad_config], loader: loader)

        expect { detector.detect_conflicts }.to raise_error(
          Lutaml::Xsd::ConfigurationError,
          /Base package not found: \/nonexistent\/missing\.lxr/,
        )
      end
    end  end

  describe "private methods behavior" do
    let(:shared_ns) { "http://example.com/ns1" }

    let(:repo1) do
      repo_with(
        namespaces: { "ns1" => shared_ns },
        types_by_namespace: {},
        files: ["schemas/person.xsd", "schemas/company.xsd"],
      )
    end

    let(:repo2) do
      repo_with(
        namespaces: { "ns1" => shared_ns },
        types_by_namespace: {},
        files: ["xsd/person.xsd", "xsd/address.xsd"],
      )
    end

    it "creates PackageSource objects" do
      touch_packages("pkg1.lxr", "pkg2.lxr")
      detector = described_class.new([config1, config2], loader: loader)
      report = detector.detect_conflicts

      expect(report.package_sources).to all(be_a(Lutaml::Xsd::PackageSource))
      expect(report.package_sources.size).to eq(2)
    end

    it "preserves package priorities" do
      touch_packages("pkg1.lxr", "pkg2.lxr")
      detector = described_class.new([config1, config2], loader: loader)
      report = detector.detect_conflicts

      sources = report.package_sources
      expect(sources[0].priority).to eq(0)
      expect(sources[1].priority).to eq(10)
    end

    it "preserves conflict resolution strategies" do
      touch_packages("pkg1.lxr", "pkg2.lxr")
      detector = described_class.new([config1, config2], loader: loader)
      report = detector.detect_conflicts

      sources = report.package_sources
      expect(sources[0].conflict_resolution).to eq("keep")
      expect(sources[1].conflict_resolution).to eq("override")
    end
  end

  private

  # Use a per-test tmp dir to avoid touching the working directory.
  def pkg_dir
    @pkg_dir ||= Dir.mktmpdir
  end

  def pkg_path(name)
    File.join(pkg_dir, name)
  end

  # Real files on disk so File.exist? returns true without stubbing.
  def touch_packages(*names)
    names.each do |n|
      path = pkg_path(n)
      FileUtils.touch(path) unless File.exist?(path)
    end
  end
end
