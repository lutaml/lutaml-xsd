# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/strategies/multi_file_strategy"
require "json"

RSpec.describe Lutaml::Xsd::Spa::Strategies::MultiFileStrategy do
  let(:output_dir) { "/tmp/docs" }
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
      render: "<html><head></head><body></body></html>",
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
    described_class.new(output_dir, mock_config_loader, verbose: false)
  end

  before do
    allow(File).to receive(:write)
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:size).and_return(100)
    allow(Dir).to receive(:exist?).and_return(true)
    allow(FileUtils).to receive(:mkdir_p)
  end

  describe "#initialize" do
    it "accepts output_dir, config_loader, and options" do
      expect(strategy.output_dir).to eq(output_dir)
      expect(strategy.config_loader).to eq(mock_config_loader)
    end

    it "inherits from OutputStrategy" do
      expect(strategy).to be_a(Lutaml::Xsd::Spa::OutputStrategy)
    end

    it "accepts verbose option" do
      strategy = described_class.new(output_dir, mock_config_loader, verbose: true)
      expect(strategy.verbose).to be true
    end
  end

  describe "#generate" do
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

    it "creates output directory structure" do
      expect(strategy).to receive(:prepare_output)
      strategy.generate(serialized_data, mock_renderer)
    end

    it "generates index.html" do
      expect(File).to receive(:write).with(
        File.join(output_dir, "index.html"),
        anything
      )
      strategy.generate(serialized_data, mock_renderer)
    end

    it "generates CSS file" do
      expect(File).to receive(:write).with(
        File.join(output_dir, "css", "styles.css"),
        anything
      )
      strategy.generate(serialized_data, mock_renderer)
    end

    it "generates JavaScript file" do
      expect(File).to receive(:write).with(
        File.join(output_dir, "js", "app.js"),
        anything
      )
      strategy.generate(serialized_data, mock_renderer)
    end

    it "generates data JSON file" do
      expect(File).to receive(:write).with(
        File.join(output_dir, "data", "schemas.json"),
        anything
      )
      strategy.generate(serialized_data, mock_renderer)
    end

    it "returns array of all generated file paths" do
      result = strategy.generate(serialized_data, mock_renderer)

      expect(result).to be_an(Array)
      expect(result.size).to eq(4)
      expect(result).to include(File.join(output_dir, "index.html"))
      expect(result).to include(File.join(output_dir, "css", "styles.css"))
      expect(result).to include(File.join(output_dir, "js", "app.js"))
      expect(result).to include(File.join(output_dir, "data", "schemas.json"))
    end

    context "when verbose mode enabled" do
      subject(:strategy) do
        described_class.new(output_dir, mock_config_loader, verbose: true)
      end

      it "logs generation progress" do
        expect do
          strategy.generate(serialized_data, mock_renderer)
        end.to output(/Generating multi-file SPA/).to_stdout
      end

      it "logs completion message" do
        expect do
          strategy.generate(serialized_data, mock_renderer)
        end.to output(/Multi-file SPA generated/).to_stdout
      end
    end
  end

  describe "#prepare_output" do
    it "creates main output directory" do
      expect(FileUtils).to receive(:mkdir_p).with(output_dir)
      strategy.send(:prepare_output)
    end

    it "creates css subdirectory" do
      expect(FileUtils).to receive(:mkdir_p).with(File.join(output_dir, "css"))
      strategy.send(:prepare_output)
    end

    it "creates js subdirectory" do
      expect(FileUtils).to receive(:mkdir_p).with(File.join(output_dir, "js"))
      strategy.send(:prepare_output)
    end

    it "creates data subdirectory" do
      expect(FileUtils).to receive(:mkdir_p).with(File.join(output_dir, "data"))
      strategy.send(:prepare_output)
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

    it "includes multi_file_mode flag" do
      context = strategy.send(:build_context, serialized_data, theme, features, templates_config)
      expect(context["multi_file_mode"]).to be true
    end
  end

  describe "#generate_index_html" do
    let(:theme) { { "theme" => {} } }
    let(:features) { { "features" => {} } }
    let(:templates_config) { { "templates" => {} } }
    let(:context) do
      strategy.send(:build_context, serialized_data, theme, features, templates_config)
    end

    it "renders main content" do
      expect(mock_renderer).to receive(:render_partial)
      strategy.send(:generate_index_html, serialized_data, mock_renderer, context)
    end

    it "renders layout template" do
      expect(mock_renderer).to receive(:render).with("layout.html.liquid", anything)
      strategy.send(:generate_index_html, serialized_data, mock_renderer, context)
    end

    it "injects external resource links" do
      expect(strategy).to receive(:inject_external_resources)
      strategy.send(:generate_index_html, serialized_data, mock_renderer, context)
    end

    it "writes to index.html" do
      path = File.join(output_dir, "index.html")
      expect(File).to receive(:write).with(path, anything)
      strategy.send(:generate_index_html, serialized_data, mock_renderer, context)
    end
  end

  describe "#generate_css_file" do
    let(:theme) { { "theme" => {} } }

    it "writes CSS file" do
      path = File.join(output_dir, "css", "styles.css")
      expect(File).to receive(:write).with(path, anything)
      strategy.send(:generate_css_file, theme)
    end

    it "returns CSS file path" do
      result = strategy.send(:generate_css_file, theme)
      expect(result).to eq(File.join(output_dir, "css", "styles.css"))
    end
  end

  describe "#generate_js_file" do
    let(:features) { { "features" => {} } }

    it "writes JavaScript file" do
      path = File.join(output_dir, "js", "app.js")
      expect(File).to receive(:write).with(path, anything)
      strategy.send(:generate_js_file, features)
    end

    it "returns JS file path" do
      result = strategy.send(:generate_js_file, features)
      expect(result).to eq(File.join(output_dir, "js", "app.js"))
    end
  end

  describe "#generate_data_file" do
    it "writes JSON data file" do
      path = File.join(output_dir, "data", "schemas.json")
      expect(File).to receive(:write).with(path, anything)
      strategy.send(:generate_data_file, serialized_data)
    end

    it "writes pretty-printed JSON" do
      expect(JSON).to receive(:pretty_generate).with(serialized_data).and_call_original
      strategy.send(:generate_data_file, serialized_data)
    end

    it "returns JSON file path" do
      result = strategy.send(:generate_data_file, serialized_data)
      expect(result).to eq(File.join(output_dir, "data", "schemas.json"))
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

    it "handles empty schemas array" do
      data = { schemas: [] }
      content = strategy.send(:render_content, data, mock_renderer)
      expect(content).to eq("")
    end
  end

  describe "#inject_external_resources" do
    let(:html) do
      <<~HTML
        <html>
        <head></head>
        <body>
        const Search = {
          data: { schemas: [] }
        };
        </body>
        </html>
      HTML
    end

    it "adds CSS link to head" do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include('<link rel="stylesheet" href="css/styles.css">')
    end

    it "adds JS script to body" do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include('<script src="js/app.js"></script>')
    end

    it "updates data source reference" do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include("data: null")
      expect(result).to include("Loaded from external file")
    end
  end

  describe "edge cases" do
    it "handles deeply nested output directory" do
      deep_dir = "/tmp/a/b/c/d/docs"
      strategy = described_class.new(deep_dir, mock_config_loader)

      expect(FileUtils).to receive(:mkdir_p).with(deep_dir)
      expect(FileUtils).to receive(:mkdir_p).with(File.join(deep_dir, "css"))
      expect(FileUtils).to receive(:mkdir_p).with(File.join(deep_dir, "js"))
      expect(FileUtils).to receive(:mkdir_p).with(File.join(deep_dir, "data"))

      strategy.send(:prepare_output)
    end

    it "handles special characters in directory path" do
      special_dir = "/tmp/docs (2024)"
      strategy = described_class.new(special_dir, mock_config_loader)

      expect(FileUtils).to receive(:mkdir_p).with(special_dir)
      strategy.send(:prepare_output)
    end

    it "handles empty data" do
      empty_data = { metadata: {}, schemas: [], index: {} }

      result = strategy.generate(empty_data, mock_renderer)
      expect(result).to be_an(Array)
      expect(result.size).to eq(4)
    end
  end

  describe "integration with parent class" do
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
end