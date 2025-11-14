# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/strategies/single_file_strategy"

RSpec.describe Lutaml::Xsd::Spa::Strategies::SingleFileStrategy do
  let(:output_path) { "/tmp/docs.html" }
  let(:mock_config_loader) do
    instance_double(
      Lutaml::Xsd::Spa::ConfigurationLoader,
      load_ui_theme: { "theme" => { "colors" => { "primary" => "#000" } } },
      load_features: { "features" => { "search" => { "enabled" => true } } },
      load_templates: { "templates" => { "layout" => "default" } }
    )
  end
  let(:mock_renderer) do
    instance_double(
      Lutaml::Xsd::Spa::TemplateRenderer,
      render: "<html>Rendered</html>",
      render_partial: "<div>Partial</div>"
    )
  end
  let(:serialized_data) do
    {
      metadata: { title: "Test Docs" },
      schemas: [
        { id: "schema-0", name: "test-schema" }
      ],
      index: {}
    }
  end

  subject(:strategy) do
    described_class.new(output_path, mock_config_loader, verbose: false)
  end

  describe "#initialize" do
    it "accepts output_path, config_loader, and options" do
      expect(strategy.output_path).to eq(output_path)
      expect(strategy.config_loader).to eq(mock_config_loader)
    end

    it "inherits from OutputStrategy" do
      expect(strategy).to be_a(Lutaml::Xsd::Spa::OutputStrategy)
    end

    it "accepts verbose option" do
      strategy = described_class.new(output_path, mock_config_loader, verbose: true)
      expect(strategy.verbose).to be true
    end
  end

  describe "#generate" do
    before do
      allow(File).to receive(:write)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)
      allow(Dir).to receive(:exist?).and_return(true)
    end

    it "loads UI theme configuration" do
      expect(mock_config_loader).to receive(:load_ui_theme).and_call_original
      strategy.generate(serialized_data, mock_renderer)
    end

    it "loads features configuration" do
      expect(mock_config_loader).to receive(:load_features).and_call_original
      strategy.generate(serialized_data, mock_renderer)
    end

    it "loads templates configuration" do
      expect(mock_config_loader).to receive(:load_templates).and_call_original
      strategy.generate(serialized_data, mock_renderer)
    end

    it "renders main content" do
      expect(mock_renderer).to receive(:render_partial).with("schema_card", anything)
      strategy.generate(serialized_data, mock_renderer)
    end

    it "renders layout template" do
      expect(mock_renderer).to receive(:render).with("layout.html.liquid", anything)
      strategy.generate(serialized_data, mock_renderer)
    end

    it "writes HTML to output file" do
      expect(File).to receive(:write).with(output_path, anything)
      strategy.generate(serialized_data, mock_renderer)
    end

    it "returns array with single file path" do
      result = strategy.generate(serialized_data, mock_renderer)
      expect(result).to eq([output_path])
    end

    context "when output directory does not exist" do
      let(:output_path) { "/tmp/docs/output.html" }

      before do
        allow(Dir).to receive(:exist?).with("/tmp/docs").and_return(false)
      end

      it "creates output directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/tmp/docs")
        strategy.generate(serialized_data, mock_renderer)
      end
    end

    context "when output is in current directory" do
      let(:output_path) { "docs.html" }

      it "does not create directory" do
        expect(FileUtils).not_to receive(:mkdir_p)
        strategy.generate(serialized_data, mock_renderer)
      end
    end

    context "when verbose mode enabled" do
      subject(:strategy) do
        described_class.new(output_path, mock_config_loader, verbose: true)
      end

      it "logs generation progress" do
        expect do
          strategy.generate(serialized_data, mock_renderer)
        end.to output(/Generating single-file SPA/).to_stdout
      end

      it "logs completion message" do
        expect do
          strategy.generate(serialized_data, mock_renderer)
        end.to output(/Single file generated/).to_stdout
      end
    end
  end

  describe "#build_context" do
    let(:theme) { { "theme" => { "colors" => {} } } }
    let(:features) { { "features" => {} } }
    let(:templates_config) { { "templates" => {} } }

    it "builds context hash for template" do
      context = strategy.send(:build_context, serialized_data, theme, features, templates_config)

      expect(context).to be_a(Hash)
      expect(context["metadata"]).to eq(serialized_data[:metadata])
      expect(context["schemas"]).to eq(serialized_data[:schemas])
      expect(context["theme"]).to eq(theme["theme"])
      expect(context["features"]).to eq(features["features"])
      expect(context["templates"]).to eq(templates_config["templates"])
    end
  end

  describe "#render_content" do
    it "renders schema cards for all schemas" do
      expect(mock_renderer).to receive(:render_partial)
        .with("schema_card", { "schema" => serialized_data[:schemas].first })
        .and_return("<div>Schema</div>")

      content = strategy.send(:render_content, serialized_data, mock_renderer)
      expect(content).to include("<div>Schema</div>")
    end

    it "joins multiple schema cards with newline" do
      data = {
        schemas: [
          { id: "schema-0", name: "first" },
          { id: "schema-1", name: "second" }
        ]
      }

      allow(mock_renderer).to receive(:render_partial)
        .and_return("<div>Card</div>")

      content = strategy.send(:render_content, data, mock_renderer)
      expect(content.split("\n").size).to eq(2)
    end

    it "handles empty schemas array" do
      data = { schemas: [] }

      content = strategy.send(:render_content, data, mock_renderer)
      expect(content).to eq("")
    end

    it "handles nil schemas" do
      data = {}

      content = strategy.send(:render_content, data, mock_renderer)
      expect(content).to eq("")
    end
  end

  describe "#prepare_output" do
    context "when output directory exists" do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
      end

      it "does not create directory" do
        expect(FileUtils).not_to receive(:mkdir_p)
        strategy.send(:prepare_output)
      end
    end

    context "when output is in subdirectory" do
      let(:output_path) { "/tmp/subdir/docs.html" }

      before do
        allow(Dir).to receive(:exist?).and_return(false)
      end

      it "creates parent directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/tmp/subdir")
        strategy.send(:prepare_output)
      end
    end
  end

  describe "integration with parent class" do
    before do
      allow(File).to receive(:write)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)
      allow(Dir).to receive(:exist?).and_return(true)
    end

    it "inherits file writing behavior" do
      expect(strategy).to respond_to(:write_file)
    end

    it "inherits directory creation behavior" do
      expect(strategy).to respond_to(:ensure_directory)
    end

    it "inherits logging behavior" do
      expect(strategy).to respond_to(:log)
    end
  end

  describe "edge cases" do
    before do
      allow(File).to receive(:write)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)
      allow(Dir).to receive(:exist?).and_return(true)
    end

    it "handles deeply nested output path" do
      deep_path = "/tmp/a/b/c/d/docs.html"
      strategy = described_class.new(deep_path, mock_config_loader)

      allow(Dir).to receive(:exist?).with("/tmp/a/b/c/d").and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with("/tmp/a/b/c/d")

      strategy.generate(serialized_data, mock_renderer)
    end

    it "handles special characters in file path" do
      special_path = "/tmp/docs (2024).html"
      strategy = described_class.new(special_path, mock_config_loader)

      expect(File).to receive(:write).with(special_path, anything)
      strategy.generate(serialized_data, mock_renderer)
    end
  end
end