# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/strategies/single_file_strategy"
require "lutaml/xsd/spa/configuration_loader"
require "lutaml/xsd/spa/template_renderer"
require "tmpdir"
require "fileutils"

RSpec.describe Lutaml::Xsd::Spa::Strategies::SingleFileStrategy do
  let(:temp_dir) { Dir.mktmpdir }
  let(:output_path) { File.join(temp_dir, "docs.html") }
  let(:config_dir) { Dir.mktmpdir }

  # Create real configuration files
  let(:config_loader) do
    # Create config files
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "ui_theme.yml"), "theme:\n  colors:\n    primary: '#000'\n")
    File.write(File.join(config_dir, "features.yml"), "features:\n  search:\n    enabled: true\n")
    File.write(File.join(config_dir, "templates.yml"), "templates:\n  layout: default\n")

    Lutaml::Xsd::Spa::ConfigurationLoader.new(config_dir: config_dir)
  end

  let(:template_dir) { Dir.mktmpdir }
  let(:renderer) do
    # Create real template files
    FileUtils.mkdir_p(File.join(template_dir, "components"))
    File.write(File.join(template_dir, "layout.html.liquid"), "<html><body>{{ content }}</body></html>")
    File.write(File.join(template_dir, "components", "schema_card.liquid"), "<div>{{ schema.name }}</div>")
    File.write(File.join(template_dir, "components", "_schema_detail.liquid"), "<section>{{ schema.name }}</section>")

    Lutaml::Xsd::Spa::TemplateRenderer.new(template_dir: template_dir)
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
    described_class.new(output_path, config_loader, verbose: false)
  end

  after do
    FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
    FileUtils.remove_entry(config_dir) if Dir.exist?(config_dir)
    FileUtils.remove_entry(template_dir) if Dir.exist?(template_dir)
  end

  describe "#initialize" do
    it "accepts output_path, config_loader, and options" do
      expect(strategy.output_path).to eq(output_path)
      expect(strategy.config_loader).to eq(config_loader)
    end

    it "accepts verbose option" do
      strategy = described_class.new(output_path, config_loader, verbose: true)
      expect(strategy.verbose).to be true
    end
  end

  describe "#generate" do
    it "loads UI theme configuration" do
      theme = config_loader.load_ui_theme
      expect(theme).to be_a(Hash)
      expect(theme).to have_key("theme")
    end

    it "loads features configuration" do
      features = config_loader.load_features
      expect(features).to be_a(Hash)
      expect(features).to have_key("features")
    end

    it "loads templates configuration" do
      templates = config_loader.load_templates
      expect(templates).to be_a(Hash)
      expect(templates).to have_key("templates")
    end

    it "renders main content" do
      content = renderer.render_partial("schema_card", { "schema" => serialized_data[:schemas].first })
      expect(content).to include("test-schema")
    end

    it "renders layout template" do
      result = renderer.render("layout.html.liquid", { "content" => "Test" })
      expect(result).to include("<html>")
      expect(result).to include("Test")
    end

    it "writes HTML to output file" do
      strategy.generate(serialized_data, renderer)
      expect(File.exist?(output_path)).to be true
    end

    it "returns array with single file path" do
      result = strategy.generate(serialized_data, renderer)
      expect(result).to eq([output_path])
    end

    context "when output directory does not exist" do
      let(:output_path) { File.join(temp_dir, "subdir", "docs", "output.html") }

      it "creates output directory" do
        strategy.generate(serialized_data, renderer)
        expect(File.exist?(output_path)).to be true
        expect(Dir.exist?(File.dirname(output_path))).to be true
      end
    end

    context "when output is in current directory" do
      let(:output_path) { File.join(temp_dir, "docs.html") }

      it "writes file successfully" do
        strategy.generate(serialized_data, renderer)
        expect(File.exist?(output_path)).to be true
      end
    end

    context "when verbose mode enabled" do
      subject(:strategy) do
        described_class.new(output_path, config_loader, verbose: true)
      end

      it "logs generation progress" do
        expect do
          strategy.generate(serialized_data, renderer)
        end.to output(/Generating|single/).to_stdout
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
      content = strategy.send(:render_content, serialized_data, renderer)
      expect(content).to include("test-schema")
    end

    it "joins multiple schema cards with newline" do
      data = {
        schemas: [
          { id: "schema-0", name: "first" },
          { id: "schema-1", name: "second" }
        ]
      }

      content = strategy.send(:render_content, data, renderer)
      expect(content).to include("first")
      expect(content).to include("second")
      expect(content.split("\n").size).to be >= 2
    end

    it "handles empty schemas array" do
      data = { schemas: [] }

      content = strategy.send(:render_content, data, renderer)
      # render_content always returns HTML wrapper, even for empty schemas
      expect(content).to include("schema-list-container")
      expect(content).to include("no-schema-selected")
    end

    it "handles nil schemas" do
      data = {}

      content = strategy.send(:render_content, data, renderer)
      # render_content always returns HTML wrapper, even for nil schemas
      expect(content).to include("schema-list-container")
      expect(content).to include("no-schema-selected")
    end
  end

  describe "#prepare_output" do
    context "when output directory exists" do
      it "does not raise error" do
        expect { strategy.send(:prepare_output) }.not_to raise_error
      end
    end

    context "when output is in subdirectory" do
      let(:output_path) { File.join(temp_dir, "subdir", "docs.html") }

      it "creates parent directory" do
        strategy.send(:prepare_output)
        expect(Dir.exist?(File.dirname(output_path))).to be true
      end
    end
  end

  describe "integration with parent class" do
    it "inherits from OutputStrategy" do
      expect(strategy).to be_a(Lutaml::Xsd::Spa::OutputStrategy)
    end
  end

  describe "edge cases" do
    it "handles deeply nested output path" do
      deep_path = File.join(temp_dir, "a", "b", "c", "d", "docs.html")
      strategy = described_class.new(deep_path, config_loader)

      result = strategy.generate(serialized_data, renderer)
      expect(File.exist?(deep_path)).to be true
      expect(result).to eq([deep_path])
    end

    it "handles special characters in file path" do
      special_path = File.join(temp_dir, "docs (2024).html")
      strategy = described_class.new(special_path, config_loader)

      strategy.generate(serialized_data, renderer)
      expect(File.exist?(special_path)).to be true
    end
  end
end