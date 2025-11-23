# frozen_string_literal: true

require 'spec_helper'
require 'lutaml/xsd/spa/strategies/multi_file_strategy'
require 'lutaml/xsd/spa/configuration_loader'
require 'lutaml/xsd/spa/template_renderer'
require 'json'
require 'tmpdir'
require 'fileutils'

RSpec.describe Lutaml::Xsd::Spa::Strategies::MultiFileStrategy do
  let(:temp_dir) { Dir.mktmpdir }
  let(:output_dir) { File.join(temp_dir, 'docs') }
  let(:config_dir) { Dir.mktmpdir }

  # Create real configuration files
  let(:config_loader) do
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, 'ui_theme.yml'), "theme:\n  colors:\n    primary: '#000'\n")
    File.write(File.join(config_dir, 'features.yml'), "features:\n  search:\n    enabled: true\n")
    File.write(File.join(config_dir, 'templates.yml'), "templates:\n  layout: default\n")

    Lutaml::Xsd::Spa::ConfigurationLoader.new(config_dir: config_dir)
  end

  let(:template_dir) { Dir.mktmpdir }
  let(:renderer) do
    # Create real template files
    FileUtils.mkdir_p(File.join(template_dir, 'components'))
    File.write(File.join(template_dir, 'layout.html.liquid'), '<html><head></head><body>{{ content }}</body></html>')
    File.write(File.join(template_dir, 'components', 'schema_card.liquid'), '<div>{{ schema.name }}</div>')

    Lutaml::Xsd::Spa::TemplateRenderer.new(template_dir: template_dir)
  end

  let(:serialized_data) do
    {
      metadata: { title: 'Test Docs' },
      schemas: [
        { id: 'schema-0', name: 'test-schema' }
      ],
      index: {}
    }
  end

  subject(:strategy) do
    described_class.new(output_dir, config_loader, verbose: false)
  end

  after do
    FileUtils.rm_rf(temp_dir)
    FileUtils.rm_rf(config_dir)
    FileUtils.rm_rf(template_dir)
  end

  describe '#initialize' do
    it 'accepts output_dir, config_loader, and options' do
      expect(strategy.output_dir).to eq(output_dir)
      expect(strategy.config_loader).to eq(config_loader)
    end

    it 'inherits from OutputStrategy' do
      expect(strategy).to be_a(Lutaml::Xsd::Spa::OutputStrategy)
    end

    it 'accepts verbose option' do
      strategy = described_class.new(output_dir, config_loader, verbose: true)
      expect(strategy.verbose).to be true
    end
  end

  describe '#generate' do
    it 'loads UI theme configuration' do
      theme = config_loader.load_ui_theme
      expect(theme).to be_a(Hash)
      expect(theme).to have_key('theme')
    end

    it 'loads features configuration' do
      features = config_loader.load_features
      expect(features).to be_a(Hash)
      expect(features).to have_key('features')
    end

    it 'loads templates configuration' do
      templates = config_loader.load_templates
      expect(templates).to be_a(Hash)
      expect(templates).to have_key('templates')
    end

    it 'creates output directory structure' do
      strategy.generate(serialized_data, renderer)

      expect(Dir.exist?(output_dir)).to be true
      expect(Dir.exist?(File.join(output_dir, 'css'))).to be true
      expect(Dir.exist?(File.join(output_dir, 'js'))).to be true
      expect(Dir.exist?(File.join(output_dir, 'data'))).to be true
    end

    it 'generates index.html' do
      strategy.generate(serialized_data, renderer)

      path = File.join(output_dir, 'index.html')
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include('<html>')
    end

    it 'generates CSS file' do
      strategy.generate(serialized_data, renderer)

      path = File.join(output_dir, 'css', 'styles.css')
      expect(File.exist?(path)).to be true
    end

    it 'generates JavaScript file' do
      strategy.generate(serialized_data, renderer)

      path = File.join(output_dir, 'js', 'app.js')
      expect(File.exist?(path)).to be true
    end

    it 'generates data JSON file' do
      strategy.generate(serialized_data, renderer)

      path = File.join(output_dir, 'data', 'schemas.json')
      expect(File.exist?(path)).to be true

      json_content = JSON.parse(File.read(path))
      expect(json_content).to have_key('metadata')
      expect(json_content).to have_key('schemas')
    end

    it 'returns array of all generated file paths' do
      result = strategy.generate(serialized_data, renderer)

      expect(result).to be_an(Array)
      expect(result.size).to eq(4)
      expect(result).to include(File.join(output_dir, 'index.html'))
      expect(result).to include(File.join(output_dir, 'css', 'styles.css'))
      expect(result).to include(File.join(output_dir, 'js', 'app.js'))
      expect(result).to include(File.join(output_dir, 'data', 'schemas.json'))
    end

    context 'when verbose mode enabled' do
      subject(:strategy) do
        described_class.new(output_dir, config_loader, verbose: true)
      end

      it 'logs generation progress' do
        expect do
          strategy.generate(serialized_data, renderer)
        end.to output(/Generating|multi/).to_stdout
      end
    end
  end

  describe '#build_context' do
    let(:theme) { { 'theme' => { 'colors' => {} } } }
    let(:features) { { 'features' => {} } }
    let(:templates_config) { { 'templates' => {} } }

    it 'builds context hash for template' do
      context = strategy.send(:build_context, serialized_data, theme, features, templates_config)

      expect(context).to be_a(Hash)
      expect(context['metadata']).to eq(serialized_data[:metadata])
      expect(context['schemas']).to eq(serialized_data[:schemas])
      expect(context['theme']).to eq(theme['theme'])
      expect(context['features']).to eq(features['features'])
      expect(context['templates']).to eq(templates_config['templates'])
    end

    it 'includes multi_file_mode flag' do
      context = strategy.send(:build_context, serialized_data, {}, {}, {})
      expect(context['multi_file_mode']).to be true
    end
  end

  describe '#generate_css_file' do
    let(:theme) { { 'theme' => {} } }

    before do
      strategy.send(:prepare_output)  # Ensure directories exist
    end

    it 'writes CSS file' do
      result = strategy.send(:generate_css_file, theme)

      path = File.join(output_dir, 'css', 'styles.css')
      expect(File.exist?(path)).to be true
      expect(result).to eq(path)
    end

    it 'returns CSS file path' do
      result = strategy.send(:generate_css_file, theme)
      expect(result).to eq(File.join(output_dir, 'css', 'styles.css'))
    end
  end

  describe '#generate_js_file' do
    let(:features) { { 'features' => {} } }

    before do
      strategy.send(:prepare_output)  # Ensure directories exist
    end

    it 'writes JavaScript file' do
      result = strategy.send(:generate_js_file, features)

      path = File.join(output_dir, 'js', 'app.js')
      expect(File.exist?(path)).to be true
      expect(result).to eq(path)
    end

    it 'returns JS file path' do
      result = strategy.send(:generate_js_file, features)
      expect(result).to eq(File.join(output_dir, 'js', 'app.js'))
    end
  end

  describe '#generate_data_file' do
    before do
      strategy.send(:prepare_output)  # Ensure directories exist
    end

    it 'writes JSON data file' do
      result = strategy.send(:generate_data_file, serialized_data)

      path = File.join(output_dir, 'data', 'schemas.json')
      expect(File.exist?(path)).to be true
      expect(result).to eq(path)
    end

    it 'writes pretty-printed JSON' do
      strategy.send(:generate_data_file, serialized_data)

      path = File.join(output_dir, 'data', 'schemas.json')
      json_str = File.read(path)
      expect(json_str).to include("\n") # Pretty-printed has newlines

      json_content = JSON.parse(json_str)
      expect(json_content).to eq(JSON.parse(serialized_data.to_json))
    end

    it 'returns JSON file path' do
      result = strategy.send(:generate_data_file, serialized_data)
      expect(result).to eq(File.join(output_dir, 'data', 'schemas.json'))
    end
  end

  describe '#render_content' do
    it 'renders schema cards for all schemas' do
      content = strategy.send(:render_content, serialized_data, renderer)
      expect(content).to include('test-schema')
    end

    it 'handles empty schemas array' do
      data = { schemas: [] }
      content = strategy.send(:render_content, data, renderer)
      expect(content).to eq('')
    end
  end

  describe '#inject_external_resources' do
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

    it 'adds CSS link to head' do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include('<link rel="stylesheet" href="css/styles.css">')
    end

    it 'adds JS script to body' do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include('<script src="js/app.js"></script>')
    end

    it 'updates data source reference' do
      result = strategy.send(:inject_external_resources, html)
      expect(result).to include('data: null')
      expect(result).to include('Loaded from external file')
    end
  end

  describe 'edge cases' do
    it 'handles deeply nested output directory' do
      deep_dir = File.join(temp_dir, 'a', 'b', 'c', 'd', 'docs')
      strategy = described_class.new(deep_dir, config_loader)

      strategy.generate(serialized_data, renderer)

      expect(Dir.exist?(deep_dir)).to be true
      expect(File.exist?(File.join(deep_dir, 'index.html'))).to be true
    end

    it 'handles special characters in directory path' do
      special_dir = File.join(temp_dir, 'docs (2024)')
      strategy = described_class.new(special_dir, config_loader)

      strategy.generate(serialized_data, renderer)
      expect(Dir.exist?(special_dir)).to be true
    end

    it 'handles empty data' do
      empty_data = { metadata: {}, schemas: [], index: {} }

      result = strategy.generate(empty_data, renderer)
      expect(result).to be_an(Array)
      expect(result.size).to eq(4)

      # Verify all files were created
      result.each do |file_path|
        expect(File.exist?(file_path)).to be true
      end
    end
  end

  describe 'integration with parent class' do
    it 'inherits from OutputStrategy' do
      expect(strategy).to be_a(Lutaml::Xsd::Spa::OutputStrategy)
    end
  end
end
