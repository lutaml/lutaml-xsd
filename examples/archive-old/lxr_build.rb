#!/usr/bin/env ruby
# frozen_string_literal: true

# LXR Package Building Example
#
# This example demonstrates building LXR packages from YAML configuration:
# - Creating YAML configuration files
# - Building packages using CLI commands
# - Adding package metadata
# - Validating packages
# - Smart caching
#
# Usage:
#   ruby examples/lxr_build.rb

require 'bundler/setup'
require 'lutaml/xsd'
require 'fileutils'
require 'yaml'

# Helper methods
def format_file_size(bytes)
  if bytes < 1024
    "#{bytes} B"
  elsif bytes < 1024 * 1024
    "#{(bytes / 1024.0).round(1)} KB"
  else
    "#{(bytes / (1024.0 * 1024)).round(2)} MB"
  end
end

def format_time(seconds)
  if seconds < 0.001
    "#{(seconds * 1_000_000).round(0)} μs"
  elsif seconds < 1
    "#{(seconds * 1000).round(1)} ms"
  else
    "#{seconds.round(2)} s"
  end
end

# Configuration
SCHEMAS_DIR = File.expand_path('validation/sample_schemas', __dir__)
OUTPUT_DIR = File.expand_path('output', __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, 'person.xsd')
COMPANY_XSD = File.join(SCHEMAS_DIR, 'company.xsd')

# Create output directory
FileUtils.mkdir_p(OUTPUT_DIR)

puts '=' * 80
puts 'LXR Package Building Example'
puts '=' * 80
puts

# Step 1: Create YAML configuration file
# ---------------------------------------
puts 'Step 1: Creating YAML configuration'
puts '-' * 80

config_path = File.join(OUTPUT_DIR, 'schemas_config.yml')
config = {
  'files' => [PERSON_XSD, COMPANY_XSD],
  'namespace_mappings' => [
    { 'prefix' => 'p', 'uri' => 'http://example.com/person' },
    { 'prefix' => 'c', 'uri' => 'http://example.com/company' }
  ]
}

File.write(config_path, config.to_yaml)
puts "✓ Configuration created: #{File.basename(config_path)}"
puts "  Files: #{config['files'].size}"
puts "  Namespace mappings: #{config['namespace_mappings'].size}"
puts

# Step 2: Build package from YAML configuration
# ----------------------------------------------
puts 'Step 2: Building package from YAML configuration'
puts '-' * 80

output_path = File.join(OUTPUT_DIR, 'schemas_marshal.lxr')

puts 'Building package with Marshal serialization...'
start_time = Time.now

# Use the CLI-like approach via Ruby API
system("bundle exec exe/lutaml-xsd build from-config '#{config_path}' " \
       "-o '#{output_path}' " \
       '--xsd-mode include_all ' \
       '--resolution-mode resolved ' \
       '--serialization-format marshal ' \
       "--name 'Example Schemas' " \
       "--version '1.0.0' " \
       "--description 'Person and Company schemas for demonstration' " \
       '--validate')

build_time = Time.now - start_time

if File.exist?(output_path)
  file_size = File.size(output_path)
  puts "✓ Package created: #{File.basename(output_path)}"
  puts "  Size: #{format_file_size(file_size)}"
  puts "  Build time: #{format_time(build_time)}"
else
  puts '✗ Package creation failed'
  exit 1
end

puts

# Step 3: Load and inspect package
# --------------------------------
puts 'Step 3: Loading and inspecting package'
puts '-' * 80

puts 'Loading package...'
start_time = Time.now
repository = Lutaml::Xsd::SchemaRepository.from_package(output_path)
load_time = Time.now - start_time

puts '✓ Package loaded'
puts "  Load time: #{format_time(load_time)}"
puts

# Display statistics
stats = repository.statistics
puts 'Repository statistics:'
puts "  - Total schemas: #{stats[:total_schemas]}"
puts "  - Total types: #{stats[:total_types]}"
puts "  - Namespaces: #{stats[:total_namespaces]}"
puts

# Step 4: Alternative - Build more complex package
# ------------------------------------------------
puts 'Step 4: Building a more complex package (example config)'
puts '-' * 80

# Show example of a more complex configuration
complex_config = {
  'files' => [
    'spec/fixtures/i-ur/urbanFunction.xsd'
  ],
  'schema_location_mappings' => [
    {
      'from' => '../../uro/3.2/urbanObject.xsd',
      'to' => 'spec/fixtures/i-ur/urbanObject.xsd'
    },
    {
      'from' => '(?:\.\./)+gml/(.+\.xsd)$',
      'to' => 'spec/fixtures/codesynthesis-gml-3.2.1/gml/\1',
      'pattern' => true
    }
  ],
  'namespace_mappings' => [
    { 'prefix' => 'urf', 'uri' => 'https://www.geospatial.jp/iur/urf/3.2' },
    { 'prefix' => 'gml', 'uri' => 'http://www.opengis.net/gml/3.2' }
  ]
}

complex_config_path = File.join(OUTPUT_DIR, 'urban_function_config.yml')
File.write(complex_config_path, complex_config.to_yaml)

puts "✓ Example configuration created: #{File.basename(complex_config_path)}"
puts '  This demonstrates:'
puts '    - Single entry point XSD'
puts '    - Schema location mappings for imports'
puts '    - Namespace prefix mappings'
puts
puts '  To build this package:'
puts "    lutaml-xsd build from-config #{complex_config_path} -o pkg/urban_function.lxr"
puts

# Summary
puts '=' * 80
puts 'Example completed successfully!'
puts
puts 'This example demonstrated:'
puts '  ✓ Creating YAML configuration files'
puts '  ✓ Building packages from YAML using CLI'
puts '  ✓ Using Marshal serialization (recommended)'
puts '  ✓ Adding custom metadata'
puts '  ✓ Validating packages'
puts '  ✓ Loading and inspecting packages'
puts
puts 'Configuration files created:'
puts "  - #{File.basename(config_path)} (simple example)"
puts "  - #{File.basename(complex_config_path)} (complex example)"
puts
puts 'Package created:'
puts "  - #{File.basename(output_path)} (#{format_file_size(File.size(output_path))})"
puts
puts 'Recommendations:'
puts '  • Use Marshal format for production (fastest, binary)'
puts '  • Store YAML configs in version control'
puts '  • Use schema_location_mappings for offline work'
puts '  • Add metadata for package versioning'
puts
puts 'Next steps:'
puts '  - Try examples/lxr_search.rb to explore package contents'
puts '  - Try examples/lxr_type_resolution.rb for type queries'
puts '  - See examples/urban_function_repository.yml for real-world config'
puts '=' * 80
