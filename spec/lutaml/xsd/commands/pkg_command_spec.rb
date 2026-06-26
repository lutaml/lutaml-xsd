# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/pkg_command"
require "lutaml/xsd/commands/package_command"
require "tempfile"
require "fileutils"
require "json"
require "yaml"

RSpec.describe Lutaml::Xsd::Commands::PkgCommand do
  let(:simple_schema) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="root" type="xs:string"/>
      </xs:schema>
    XSD
  end

  def build_package_in_tmpdir
    Dir.mktmpdir("pkg_command_spec") do |tmpdir|
      schema_file = File.join(tmpdir, "test.xsd")
      File.write(schema_file, simple_schema)

      config_content = <<~YAML
        output_package: #{tmpdir}/test.lxr
        files:
          - #{schema_file}
        namespace_mappings:
          - prefix: test
            uri: http://example.com/test
      YAML

      config_file = File.join(tmpdir, "config.yml")
      File.write(config_file, config_content)

      build_cmd = Lutaml::Xsd::Commands::PackageCommand::BuildCommand.new(
        config_file,
        verbose: false,
        xsd_mode: "include_all",
        resolution_mode: "resolved",
        serialization_format: "marshal",
        validate: false,
      )
      build_cmd.run

      yield File.join(tmpdir, "test.lxr")
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def command_with_options(**opts)
    described_class.new.tap do |cmd|
      allow(cmd).to receive(:options).and_return(opts.merge(verbose: false))
    end
  end

  describe "#ls" do
    context "with --show-tree option" do
      it "shows basic package tree structure" do
        build_package_in_tmpdir do |package_path|
          command = command_with_options(format: "text", classify: false, show_tree: true)

          output = capture_stdout { command.ls(package_path) }

          expect(output).to match(/test\.xsd/)
        end
      end
    end

    context "with json format" do
      it "emits valid JSON" do
        build_package_in_tmpdir do |package_path|
          command = command_with_options(format: "json", classify: false, show_tree: false)

          output = capture_stdout { command.ls(package_path) }

          expect { JSON.parse(output) }.not_to raise_error
        end
      end
    end

    context "with yaml format" do
      it "emits valid YAML" do
        build_package_in_tmpdir do |package_path|
          command = command_with_options(format: "yaml", classify: false, show_tree: false)

          output = capture_stdout { command.ls(package_path) }

          expect { YAML.unsafe_load(output) }.not_to raise_error
        end
      end
    end
  end

  describe "#tree" do
    it "displays package file tree structure" do
      build_package_in_tmpdir do |package_path|
        command = command_with_options(show_sizes: false, no_color: true, format: "tree")

        output = capture_stdout { command.tree(package_path) }

        expect(output).to match(/test\.lxr/)
      end
    end

    it "shows file sizes when requested" do
      build_package_in_tmpdir do |package_path|
        command = command_with_options(show_sizes: true, no_color: true, format: "tree")

        output = capture_stdout { command.tree(package_path) }

        expect(output).to match(/\d+\.?\d*\s+(B|KB|MB)/)
      end
    end
  end

  describe "command aliases" do
    it "maps cov to coverage" do
      expect(described_class.all_commands.key?("coverage")).to be true
    end

    it "maps s to search" do
      expect(described_class.all_commands.key?("search")).to be true
    end
  end
end
