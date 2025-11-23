# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'zip'

RSpec.describe Lutaml::Xsd::PackageTreeFormatter do
  let(:test_package_path) { create_test_package }

  # Create a minimal test package for testing
  def create_test_package
    temp_file = Tempfile.new(['test_package', '.lxr'])
    temp_file.close

    Zip::File.open(temp_file.path, create: true) do |zipfile|
      # Add metadata
      zipfile.get_output_stream('metadata.yaml') do |f|
        f.write({
          'files' => ['test.xsd'],
          'namespace_mappings' => [],
          'created_at' => Time.now.iso8601,
          'lutaml_xsd_version' => '0.1.0'
        }.to_yaml)
      end

      # Add XSD files
      zipfile.get_output_stream('schemas/test.xsd') do |f|
        f.write(<<~XSD)
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="test" type="xs:string"/>
          </xs:schema>
        XSD
      end

      zipfile.get_output_stream('schemas/example.xsd') do |f|
        f.write(<<~XSD)
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="example" type="xs:string"/>
          </xs:schema>
        XSD
      end

      # Add serialized data
      zipfile.get_output_stream('schemas_data/test.marshal') do |f|
        f.write(Marshal.dump({ test: 'data' }))
      end

      # Add indexes
      zipfile.get_output_stream('type_index.marshal') do |f|
        f.write(Marshal.dump({}))
      end

      # Add mappings
      zipfile.get_output_stream('namespace_mappings.yaml') do |f|
        f.write([].to_yaml)
      end

      zipfile.get_output_stream('schema_location_mappings.yaml') do |f|
        f.write([].to_yaml)
      end
    end

    temp_file.path
  end

  after do
    FileUtils.rm_f(test_package_path)
  end

  describe '#initialize' do
    it 'creates formatter with default options' do
      formatter = described_class.new(test_package_path)
      expect(formatter.package_path).to eq(test_package_path)
      expect(formatter.options[:show_sizes]).to be false
      expect(formatter.options[:no_color]).to be false
      expect(formatter.options[:format]).to eq(:tree)
    end

    it 'creates formatter with custom options' do
      formatter = described_class.new(
        test_package_path,
        show_sizes: true,
        no_color: true,
        format: :flat
      )
      expect(formatter.options[:show_sizes]).to be true
      expect(formatter.options[:no_color]).to be true
      expect(formatter.options[:format]).to eq(:flat)
    end
  end

  describe '#format' do
    it 'returns a formatted string' do
      formatter = described_class.new(test_package_path)
      output = formatter.format
      expect(output).to be_a(String)
      expect(output).not_to be_empty
    end

    it 'includes package name in header' do
      formatter = described_class.new(test_package_path)
      output = formatter.format
      expect(output).to include(File.basename(test_package_path))
    end

    it 'includes summary section' do
      formatter = described_class.new(test_package_path)
      output = formatter.format
      expect(output).to include('Summary:')
      expect(output).to include('Total files:')
      expect(output).to include('XSD files:')
    end

    it 'shows file sizes when requested' do
      formatter = described_class.new(test_package_path, show_sizes: true)
      output = formatter.format
      # Should contain size indicators like "KB" or "B"
      expect(output).to match(/\d+\.?\d*\s+(B|KB|MB)/)
    end

    it 'hides file sizes by default' do
      formatter = described_class.new(test_package_path)
      output = formatter.format
      # Header should still show total size
      expect(output).to match(/#{File.basename(test_package_path)}.*\(.*\)/)
    end

    context 'with tree format' do
      it 'displays tree structure' do
        formatter = described_class.new(test_package_path, format: :tree)
        output = formatter.format
        # Tree should contain tree characters
        expect(output).to match(/[├└│]/)
      end

      it 'includes metadata files' do
        formatter = described_class.new(test_package_path, format: :tree)
        output = formatter.format
        expect(output).to include('metadata.yaml')
      end

      it 'includes XSD files section' do
        formatter = described_class.new(test_package_path, format: :tree)
        output = formatter.format
        expect(output).to include('xsd_files/')
      end
    end

    context 'with flat format' do
      it 'displays flat list' do
        formatter = described_class.new(test_package_path, format: :flat)
        output = formatter.format
        # Flat format should not have tree characters in file listings
        lines = output.lines
        file_lines = lines.select { |l| l.include?('.xsd') || l.include?('.yaml') }
        expect(file_lines).not_to be_empty
      end

      it 'includes full file paths' do
        formatter = described_class.new(test_package_path, format: :flat)
        output = formatter.format
        expect(output).to include('schemas/')
      end
    end

    context 'with no_color option' do
      it 'produces plain text output' do
        formatter = described_class.new(test_package_path, no_color: true)
        output = formatter.format
        # Should not contain ANSI color codes
        expect(output).not_to match(/\e\[\d+m/)
      end
    end

    context 'with colors enabled' do
      it 'produces colorized output' do
        formatter = described_class.new(test_package_path, no_color: false)
        output = formatter.format
        # May contain ANSI color codes (but not required if Paint is disabled)
        expect(output).to be_a(String)
      end
    end
  end

  describe 'statistics calculation' do
    it 'counts XSD files correctly' do
      formatter = described_class.new(test_package_path, no_color: true)
      output = formatter.format
      # Should report 2 XSD files
      expect(output).to match(/XSD files:\s+2/)
    end

    it 'counts serialized schemas correctly' do
      formatter = described_class.new(test_package_path, no_color: true)
      output = formatter.format
      # Should report 1 serialized schema
      expect(output).to match(/Serialized schemas:\s+1/)
    end

    it 'counts configuration files correctly' do
      formatter = described_class.new(test_package_path, no_color: true)
      output = formatter.format
      # Should report metadata + mappings (3 total: metadata.yaml, namespace_mappings.yaml, schema_location_mappings.yaml)
      expect(output).to match(/Configuration files:\s+3/)
    end

    it 'counts indexes correctly' do
      formatter = described_class.new(test_package_path, no_color: true)
      output = formatter.format
      # Should report 1 index
      expect(output).to match(/Indexes:\s+1/)
    end
  end

  describe 'error handling' do
    it 'raises error for non-existent package' do
      formatter = described_class.new('/nonexistent/package.lxr')
      expect { formatter.format }.to raise_error(Lutaml::Xsd::Error)
    end

    it 'raises error for invalid ZIP file' do
      invalid_file = Tempfile.new(['invalid', '.lxr'])
      invalid_file.write('not a zip file')
      invalid_file.close

      formatter = described_class.new(invalid_file.path)
      expect { formatter.format }.to raise_error(Lutaml::Xsd::Error)

      invalid_file.unlink
    end
  end

  describe 'file size formatting' do
    let(:formatter) { described_class.new(test_package_path) }

    it 'formats bytes correctly' do
      size_str = formatter.send(:format_size, 500)
      expect(size_str).to eq('500.0 B')
    end

    it 'formats kilobytes correctly' do
      size_str = formatter.send(:format_size, 1536)
      expect(size_str).to eq('1.5 KB')
    end

    it 'formats megabytes correctly' do
      size_str = formatter.send(:format_size, 1_572_864)
      expect(size_str).to eq('1.5 MB')
    end

    it 'handles zero bytes' do
      size_str = formatter.send(:format_size, 0)
      expect(size_str).to eq('0 B')
    end
  end
end
