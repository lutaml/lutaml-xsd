# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/generate_spa_command"

# Tiny stand-in for Spa::Generator. Mirrors the constructor shape and
# returns a canned list of output paths. Avoids the network/filesystem
# work the real Generator would do during a CLI unit test.
class StubSpaGenerator
  attr_reader :package, :output_path, :options

  def initialize(package, output_path, **options)
    @package = package
    @output_path = output_path
    @options = options
  end

  def generate
    [output_path]
  end
end

RSpec.describe Lutaml::Xsd::Commands::GenerateSpaCommand do
  let(:package_path) { "/tmp/test.lxr" }
  let(:output_path) { "/tmp/docs.html" }
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }

  describe "#initialize" do
    it "accepts package_path and options" do
      command = described_class.new(package_path, output: output_path)

      expect(command.package_path).to eq(package_path)
      expect(command.output_path).to eq(output_path)
    end

    it "extracts output option" do
      command = described_class.new(package_path, output: output_path)
      expect(command.output_path).to eq(output_path)
    end
  end

  describe "#run" do
    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load)
        .and_return(repository)
      allow(Lutaml::Xsd::Spa::Generator).to receive(:new)
        .and_return(StubSpaGenerator.new(repository, output_path))
    end

    context "with inlined mode" do
      let(:command) do
        described_class.new(
          package_path,
          output: output_path,
          mode: "inlined",
        )
      end

      it "displays successful generation output" do
        expect { command.run }
          .to output(/SPA Documentation Generated Successfully/).to_stdout
      end
    end

    context "with cdn mode" do
      let(:command) do
        described_class.new(
          package_path,
          output: output_path,
          mode: "cdn",
        )
      end

      it "displays successful generation output" do
        expect { command.run }
          .to output(/SPA Documentation Generated Successfully/).to_stdout
      end
    end

    context "when error occurs" do
      let(:command) { described_class.new(package_path, output: output_path) }

      it "exits with SystemExit" do
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load)
          .and_raise(StandardError, "Test error")

        expect { command.run }.to raise_error(SystemExit)
      end

      it "outputs error message to stderr" do
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load)
          .and_raise(StandardError, "Test error")

        expect do
          command.run
        rescue SystemExit
          # Expected
        end.to output(/SPA generation failed/).to_stderr
      end
    end
  end

  describe "#validate_inputs" do
    context "when package_path is nil" do
      let(:command) { described_class.new(nil) }

      it "exits with error" do
        expect { command.validate_inputs }.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.validate_inputs
        rescue SystemExit
          # Expected
        end.to output(/No package file specified/).to_stderr
      end
    end

    context "when package file does not exist" do
      let(:command) { described_class.new(package_path, output: output_path) }

      before do
        allow(File).to receive(:exist?).with(package_path).and_return(false)
      end

      it "exits with error" do
        expect { command.validate_inputs }.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.validate_inputs
        rescue SystemExit
          # Expected
        end.to output(/Package file not found/).to_stderr
      end
    end

    context "when no output option" do
      let(:command) { described_class.new(package_path) }

      before do
        allow(File).to receive(:exist?).with(package_path).and_return(true)
      end

      it "exits with error" do
        expect { command.validate_inputs }.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.validate_inputs
        rescue SystemExit
          # Expected
        end.to output(/No output file specified/).to_stderr
      end
    end
  end

  describe "#load_package" do
    let(:command) { described_class.new(package_path, output: output_path) }

    before do
      allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load)
        .and_return(repository)
    end

    it "returns the loaded package" do
      expect(command.load_package).to eq(repository)
    end

    context "when verbose mode enabled" do
      let(:command) do
        described_class.new(package_path, output: output_path, verbose: true)
      end

      it "outputs loading message" do
        expect { command.load_package }.to output(/Loading package/).to_stdout
      end

      it "outputs success message" do
        expect { command.load_package }.to output(/Package loaded/).to_stdout
      end
    end
  end

  describe "#create_generator" do
    before do
      allow(Lutaml::Xsd::Spa::Generator).to receive(:new) do |pkg, out, **opts|
        StubSpaGenerator.new(pkg, out, **opts)
      end
    end

    context "with inlined mode" do
      let(:command) do
        described_class.new(package_path, output: output_path, mode: "inlined")
      end

      it "returns a generator initialized with inlined mode" do
        generator = command.create_generator(repository)
        expect(generator.options[:mode]).to eq("inlined")
      end
    end

    context "with cdn mode" do
      let(:command) do
        described_class.new(package_path, output: output_path, mode: "cdn")
      end

      it "returns a generator initialized with cdn mode" do
        generator = command.create_generator(repository)
        expect(generator.options[:mode]).to eq("cdn")
      end
    end

    context "when verbose mode enabled" do
      let(:command) do
        described_class.new(package_path, output: output_path, verbose: true)
      end

      it "outputs initialization message" do
        expect { command.create_generator(repository) }
          .to output(/Initializing SPA generator/).to_stdout
      end

      it "outputs success message" do
        expect { command.create_generator(repository) }
          .to output(/Generator initialized/).to_stdout
      end
    end
  end

  describe "#display_results" do
    let(:command) { described_class.new(package_path, output: output_path) }

    context "with single file" do
      let(:files) { ["/tmp/docs.html"] }

      it "displays single file message" do
        expect { command.display_results(files) }
          .to output(/Output file/).to_stdout
      end

      it "displays file path" do
        expect { command.display_results(files) }
          .to output(%r{/tmp/docs\.html}).to_stdout
      end
    end

    context "with multiple files" do
      let(:files) { ["/tmp/index.html", "/tmp/styles.css", "/tmp/app.js"] }

      it "displays multiple files message" do
        expect { command.display_results(files) }
          .to output(/Output files.*3 total/).to_stdout
      end

      it "lists all files" do
        expect { command.display_results(files) }
          .to output(/index\.html.*styles\.css.*app\.js/m).to_stdout
      end
    end

    it "displays success message" do
      expect { command.display_results([output_path]) }
        .to output(/Generation complete/).to_stdout
    end
  end
end
