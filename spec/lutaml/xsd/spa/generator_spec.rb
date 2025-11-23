# frozen_string_literal: true

require 'spec_helper'
require 'lutaml/xsd/spa/generator'

RSpec.describe Lutaml::Xsd::Spa::Generator do
  let(:mock_schema) do
    instance_double(
      Lutaml::Xsd::Schema,
      name: 'test-schema',
      target_namespace: 'http://example.com/test'
    )
  end

  let(:mock_package) do
    instance_double(
      Lutaml::Xsd::SchemaRepositoryPackage,
      schemas: [mock_schema]
    )
  end

  let(:output_path) { '/tmp/docs.html' }
  let(:output_dir) { '/tmp/docs' }

  describe '#initialize' do
    it 'accepts package, output_dir, and options' do
      generator = described_class.new(mock_package, output_path, mode: 'single_file')

      expect(generator.package).to eq(mock_package)
      expect(generator.output_dir).to eq(output_path)
      expect(generator.options[:mode]).to eq('single_file')
    end

    it 'creates configuration loader' do
      generator = described_class.new(mock_package, output_path)
      config_loader = generator.instance_variable_get(:@config_loader)

      expect(config_loader).to be_a(Lutaml::Xsd::Spa::ConfigurationLoader)
    end

    it 'creates schema serializer' do
      generator = described_class.new(mock_package, output_path)
      serializer = generator.instance_variable_get(:@serializer)

      expect(serializer).to be_a(Lutaml::Xsd::Spa::SchemaSerializer)
      expect(serializer.repository).to eq(mock_package)
    end

    it 'creates template renderer' do
      generator = described_class.new(mock_package, output_path)
      renderer = generator.instance_variable_get(:@renderer)

      expect(renderer).to be_a(Lutaml::Xsd::Spa::TemplateRenderer)
    end
  end

  describe '#generate' do
    let(:mock_strategy) do
      instance_double(
        Lutaml::Xsd::Spa::Strategies::SingleFileStrategy,
        generate: ['/tmp/docs.html']
      )
    end

    let(:serialized_data) do
      {
        metadata: { title: 'Test' },
        schemas: [{ id: 'schema-0', name: 'test' }],
        index: {}
      }
    end

    before do
      allow_any_instance_of(Lutaml::Xsd::Spa::SchemaSerializer)
        .to receive(:serialize)
        .and_return(serialized_data)
    end

    context 'when single_file mode' do
      it 'creates single file strategy' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: false)

        expect(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect(mock_strategy).to receive(:generate)

        generator.generate
      end

      it 'returns generated file paths' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: false)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        result = generator.generate
        expect(result).to eq(['/tmp/docs.html'])
      end
    end

    context 'when multi_file mode' do
      it 'creates multi file strategy' do
        generator = described_class.new(mock_package, output_dir, mode: 'multi_file', verbose: false)

        mock_multi_strategy = instance_double(
          Lutaml::Xsd::Spa::Strategies::MultiFileStrategy,
          generate: ['/tmp/docs/index.html']
        )

        expect(Lutaml::Xsd::Spa::Strategies::MultiFileStrategy)
          .to receive(:new)
          .and_return(mock_multi_strategy)

        expect(mock_multi_strategy).to receive(:generate)

        generator.generate
      end
    end

    context 'when mode not specified' do
      it 'defaults to single_file mode' do
        generator = described_class.new(mock_package, output_path, verbose: false)

        expect(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        generator.generate
      end
    end

    context 'when invalid mode' do
      it 'raises ArgumentError' do
        generator = described_class.new(mock_package, output_path, mode: 'invalid', verbose: false)

        expect do
          generator.generate
        end.to raise_error(ArgumentError, /Unknown mode: invalid/)
      end
    end

    context 'when verbose mode enabled' do
      it 'logs progress messages' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: true)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.to output(/Starting SPA generation/).to_stdout
      end

      it 'logs strategy selection' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: true)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.to output(/Using.*Single File Strategy/).to_stdout
      end

      it 'logs schema count' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: true)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.to output(/Serialized 1 schema/).to_stdout
      end

      it 'logs file count' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: true)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.to output(/Generated 1 file/).to_stdout
      end
    end

    context 'when verbose mode disabled' do
      it 'does not log messages' do
        generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: false)

        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.not_to output.to_stdout
      end
    end
  end

  describe 'dependency injection' do
    it 'injects configuration loader to strategy' do
      generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: false)
      config_loader = generator.instance_variable_get(:@config_loader)

      expect(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
        .to receive(:new)
        .with(output_path, config_loader, verbose: false)
        .and_call_original

      generator.send(:create_strategy)
    end

    it 'passes serialized data to strategy' do
      generator = described_class.new(mock_package, output_path, mode: 'single_file', verbose: false)

      serialized_data = { metadata: {}, schemas: [], index: {} }
      allow_any_instance_of(Lutaml::Xsd::Spa::SchemaSerializer)
        .to receive(:serialize)
        .and_return(serialized_data)

      mock_strategy = instance_double(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
      allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
        .to receive(:new)
        .and_return(mock_strategy)

      renderer = generator.instance_variable_get(:@renderer)

      expect(mock_strategy)
        .to receive(:generate)
        .with(serialized_data, renderer)
        .and_return(['/tmp/docs.html'])

      generator.generate
    end

    it 'registers URL filters with renderer' do
      generator = described_class.new(mock_package, output_path)
      renderer = generator.instance_variable_get(:@renderer)

      # Check that renderer has the filters registered
      expect(renderer.instance_variable_get(:@filters)).to include(Lutaml::Xsd::Spa::Filters::UrlFilters)
    end
  end

  describe 'integration with serializer' do
    it 'serializes package schemas' do
      # Create a more complete mock that allows all needed methods
      complete_mock_schema = instance_double(
        Lutaml::Xsd::Schema,
        name: 'test-schema',
        target_namespace: 'http://example.com/test'
      )

      complete_mock_package = instance_double(
        Lutaml::Xsd::SchemaRepositoryPackage,
        schemas: [complete_mock_schema]
      )

      generator = described_class.new(complete_mock_package, output_path, verbose: false)

      # Allow the serializer to actually work
      allow_any_instance_of(Lutaml::Xsd::Spa::SchemaSerializer)
        .to receive(:serialize)
        .and_call_original

      # But provide minimal structure for it to work
      allow_any_instance_of(Lutaml::Xsd::Spa::SchemaSerializer)
        .to receive(:serialize_schema)
        .and_return({
                      id: 'schema-0',
                      name: 'test-schema',
                      target_namespace: 'http://example.com/test'
                    })

      mock_strategy = instance_double(
        Lutaml::Xsd::Spa::Strategies::SingleFileStrategy,
        generate: []
      )
      allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
        .to receive(:new)
        .and_return(mock_strategy)

      generator.generate
    end
  end

  describe 'edge cases' do
    context 'when package has no schemas' do
      let(:empty_package) do
        instance_double(
          Lutaml::Xsd::SchemaRepositoryPackage,
          schemas: []
        )
      end

      it 'generates with empty schema list' do
        generator = described_class.new(empty_package, output_path, mode: 'single_file', verbose: true)

        mock_strategy = instance_double(
          Lutaml::Xsd::Spa::Strategies::SingleFileStrategy,
          generate: []
        )
        allow(Lutaml::Xsd::Spa::Strategies::SingleFileStrategy)
          .to receive(:new)
          .and_return(mock_strategy)

        expect do
          generator.generate
        end.to output(/Serialized 0 schema/).to_stdout
      end
    end

    context 'when nil options' do
      it 'handles nil options gracefully' do
        generator = described_class.new(mock_package, output_path)

        expect(generator.options).to be_a(Hash)
      end
    end
  end

  describe 'private methods' do
    let(:generator) { described_class.new(mock_package, output_path, verbose: true) }

    describe '#verbose?' do
      it 'returns true when verbose option is true' do
        generator = described_class.new(mock_package, output_path, verbose: true)
        expect(generator.send(:verbose?)).to be true
      end

      it 'returns false when verbose option is false' do
        generator = described_class.new(mock_package, output_path, verbose: false)
        expect(generator.send(:verbose?)).to be false
      end

      it 'returns false when verbose option is not set' do
        generator = described_class.new(mock_package, output_path)
        expect(generator.send(:verbose?)).to be false
      end
    end

    describe '#log' do
      it 'outputs message when verbose mode enabled' do
        generator = described_class.new(mock_package, output_path, verbose: true)

        expect do
          generator.send(:log, 'Test message')
        end.to output("Test message\n").to_stdout
      end

      it 'does not output when verbose mode disabled' do
        generator = described_class.new(mock_package, output_path, verbose: false)

        expect do
          generator.send(:log, 'Test message')
        end.not_to output.to_stdout
      end
    end
  end
end
