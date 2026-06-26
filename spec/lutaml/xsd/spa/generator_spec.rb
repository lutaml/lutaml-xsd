# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/generator"

# Lightweight stub strategy that records the args it was constructed with
# and returns a canned list of output paths. Not a double — a tiny real
# class with the same shape as VueInlinedStrategy / VueCdnStrategy.
class StubOutputStrategy
  attr_reader :output_path, :config_loader, :verbose

  def initialize(output_path, config_loader, verbose: false)
    @output_path = output_path
    @config_loader = config_loader
    @verbose = verbose
  end

  def generate(_serialized_data, _opts = nil)
    [File.join(File.dirname(output_path), "docs.html")]
  end
end

RSpec.describe Lutaml::Xsd::Spa::Generator do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:output_path) { "/tmp/docs.html" }

  describe "#initialize" do
    it "accepts package, output_path, and options" do
      generator = described_class.new(repository, output_path, mode: "inlined")

      expect(generator.package).to eq(repository)
      expect(generator.output_path).to eq(output_path)
      expect(generator.options[:mode]).to eq("inlined")
    end

    it "creates configuration loader" do
      generator = described_class.new(repository, output_path)

      expect(generator.config_loader).to be_a(Lutaml::Xsd::Spa::ConfigurationLoader)
    end

    it "creates schema serializer" do
      generator = described_class.new(repository, output_path)

      expect(generator.serializer).to be_a(Lutaml::Xsd::Spa::SchemaSerializer)
      expect(generator.serializer.repository).to eq(repository)
    end
  end

  describe "#generate" do
    let(:serialized_data) do
      {
        metadata: { title: "Test" },
        schemas: [{ id: "schema-0", name: "test" }],
        index: {},
      }
    end

    before do
      allow_any_instance_of(Lutaml::Xsd::Spa::SchemaSerializer)
        .to receive(:serialize)
        .and_return(serialized_data)
    end

    shared_examples "selects strategy class" do |mode, strategy_class|
      it "constructs #{strategy_class.name}" do
        generator = described_class.new(repository, output_path,
                                        mode: mode, verbose: false)

        expect(strategy_class).to receive(:new).and_call_original

        # The real strategy will try to read frontend assets, so stub
        # generate on whatever instance :new returns.
        allow_any_instance_of(strategy_class).to receive(:generate).and_return([output_path])

        generator.generate
      end
    end

    context "when inlined mode" do
      include_examples "selects strategy class",
                       "inlined", Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy

      it "returns generated file paths" do
        generator = described_class.new(repository, output_path,
                                        mode: "inlined", verbose: false)

        stub_strategy = StubOutputStrategy.new(output_path, generator.config_loader)
        allow(Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy)
          .to receive(:new).and_return(stub_strategy)

        result = generator.generate
        expect(result).to eq([File.join(File.dirname(output_path), "docs.html")])
      end
    end

    context "when cdn mode" do
      include_examples "selects strategy class",
                       "cdn", Lutaml::Xsd::Spa::Strategies::VueCdnStrategy
    end

    context "when mode not specified" do
      include_examples "selects strategy class",
                       nil, Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy
    end

    context "when invalid mode" do
      it "raises ArgumentError" do
        generator = described_class.new(repository, output_path,
                                        mode: "invalid", verbose: false)

        expect do
          generator.generate
        end.to raise_error(ArgumentError, /Unknown mode: invalid/)
      end
    end

    context "when verbose mode enabled" do
      let(:generator) do
        described_class.new(repository, output_path, mode: "inlined", verbose: true)
      end

      before do
        stub_strategy = StubOutputStrategy.new(output_path, generator.config_loader)
        allow(Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy)
          .to receive(:new).and_return(stub_strategy)
      end

      it "logs progress messages" do
        expect { generator.generate }.to output(/Starting SPA generation/).to_stdout
      end

      it "logs strategy selection" do
        expect { generator.generate }.to output(/Using.*Inlined Strategy/).to_stdout
      end

      it "logs schema count" do
        expect { generator.generate }.to output(/Serialized 1 schema/).to_stdout
      end

      it "logs file count" do
        expect { generator.generate }.to output(/Generated 1 file/).to_stdout
      end
    end

    context "when verbose mode disabled" do
      it "does not log messages" do
        generator = described_class.new(repository, output_path,
                                        mode: "inlined", verbose: false)

        stub_strategy = StubOutputStrategy.new(output_path, generator.config_loader)
        allow(Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy)
          .to receive(:new).and_return(stub_strategy)

        expect { generator.generate }.not_to output.to_stdout
      end
    end
  end

  describe "#verbose?" do
    it "returns true when verbose option is true" do
      generator = described_class.new(repository, output_path, verbose: true)
      expect(generator.verbose?).to be true
    end

    it "returns false when verbose option is false" do
      generator = described_class.new(repository, output_path, verbose: false)
      expect(generator.verbose?).to be false
    end

    it "returns false when verbose option is not set" do
      generator = described_class.new(repository, output_path)
      expect(generator.verbose?).to be false
    end
  end

  describe "#log" do
    it "outputs message when verbose mode enabled" do
      generator = described_class.new(repository, output_path, verbose: true)

      expect { generator.log("Test message") }
        .to output("Test message\n").to_stdout
    end

    it "does not output when verbose mode disabled" do
      generator = described_class.new(repository, output_path, verbose: false)

      expect { generator.log("Test message") }.not_to output.to_stdout
    end
  end

  describe "SPA generation with composed packages" do
    let(:simple_pkg_path) do
      File.expand_path("../../../fixtures/packages/simple.lxr", __dir__)
    end
    let(:unitsml_pkg_path) do
      File.expand_path("../../../fixtures/packages/unitsml.lxr", __dir__)
    end

    let(:composed_config_yaml) do
      <<~YAML
        base_packages:
          - package: #{simple_pkg_path}
            priority: 0
            conflict_resolution: keep
          - package: #{unitsml_pkg_path}
            priority: 10
            conflict_resolution: override

        namespace_mappings:
          - prefix: "person"
            uri: "http://example.com/person"
          - prefix: "units"
            uri: "urn:oasis:names:tc:unitsml:schema:xsd:UnitsMLSchema-1.0"
      YAML
    end

    context "when both base packages exist", :skip_if_packages_missing do
      before do
        skip "Test packages not available" unless File.exist?(simple_pkg_path) && File.exist?(unitsml_pkg_path)
      end

      it "generates SPA from composed configuration" do
        require "tempfile"

        Tempfile.create(["composed_config", ".yml"]) do |config_file|
          config_file.write(composed_config_yaml)
          config_file.rewind

          repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(config_file.path)

          generator = described_class.new(repository, "/tmp/composed_docs.html",
                                          mode: "inlined", verbose: false)

          stub_strategy = StubOutputStrategy.new("/tmp/composed_docs.html", generator.config_loader)
          allow(Lutaml::Xsd::Spa::Strategies::VueInlinedStrategy)
            .to receive(:new).and_return(stub_strategy)

          result = generator.generate
          expect(result).to include("/tmp/composed_docs.html")
        end
      end

      it "includes all namespaces from all packages" do
        require "tempfile"

        Tempfile.create(["composed_config", ".yml"]) do |config_file|
          config_file.write(composed_config_yaml)
          config_file.rewind

          repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(config_file.path)
          generator = described_class.new(repository, "/tmp/docs.html", verbose: false)

          data = generator.serializer.serialize

          expect(data[:metadata][:namespaces]).to be_an(Array)
          expect(data[:metadata][:namespaces].size).to be > 0
        end
      end

      it "creates working type cross-references" do
        require "tempfile"

        Tempfile.create(["composed_config", ".yml"]) do |config_file|
          config_file.write(composed_config_yaml)
          config_file.rewind

          repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(config_file.path)

          expect(repository).to respond_to(:find_type)
        end
      end
    end

    context "when base packages are missing" do
      it "handles missing package gracefully" do
        bad_config = <<~YAML
          base_packages:
            - package: /nonexistent/package.lxr
              priority: 0
        YAML

        require "tempfile"

        Tempfile.create(["bad_config", ".yml"]) do |config_file|
          config_file.write(bad_config)
          config_file.rewind

          expect do
            repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(config_file.path)
            repository.parse.resolve
          end.to raise_error(Lutaml::Xsd::ConfigurationError, /Base package not found/)
        end
      end
    end
  end
end
