#!/usr/bin/env ruby
# frozen_string_literal: true

# LXR Package Building Example
#
# This example demonstrates building LXR packages from schemas:
# - Building from YAML configuration
# - Different serialization formats (marshal, JSON, YAML)
# - Adding package metadata
# - Validation after building
# - Comparing package sizes and load times
#
# Usage:
#   ruby examples/lxr_build.rb

require "bundler/setup"
require "lutaml/xsd"
require "fileutils"

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
SCHEMAS_DIR = File.expand_path("validation/sample_schemas", __dir__)
OUTPUT_DIR = File.expand_path("output", __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, "person.xsd")
COMPANY_XSD = File.join(SCHEMAS_DIR, "company.xsd")

# Create output directory
FileUtils.mkdir_p(OUTPUT_DIR)

puts "=" * 80
puts "LXR Package Building Example"
puts "=" * 80
puts

# Step 1: Build package from XSD files directly
# ---------------------------------------------
puts "Step 1: Building package from XSD files"
puts "-" * 80

puts "Creating schema repository from XSD files..."
repository = Lutaml::Xsd::SchemaRepository.new

# Set schema files
repository.instance_variable_set(:@files, [PERSON_XSD, COMPANY_XSD])

# Configure namespaces
repository.configure_namespaces({
  "p" => "http://example.com/person",
  "c" => "http://example.com/company"
})

puts "  - Parsing schemas..."
repository.parse(verbose: false)

puts "  - Resolving dependencies..."
repository.resolve(verbose: false)

# Display statistics
stats = repository.statistics
puts "✓ Repository created:"
puts "  - Total schemas: #{stats[:total_schemas]}"
puts "  - Total types: #{stats[:total_types]}"
puts "  - Namespaces: #{stats[:total_namespaces]}"

puts

# Step 2: Build packages with different serialization formats
# -----------------------------------------------------------
puts "Step 2: Building packages with different serialization formats"
puts "-" * 80

formats = [
  { format: :marshal, desc: "Marshal (binary, fastest)" },
  { format: :json, desc: "JSON (text, portable)" },
  { format: :yaml, desc: "YAML (text, human-readable)" }
]

package_info = []

formats.each do |format_config|
  format = format_config[:format]
  output_path = File.join(OUTPUT_DIR, "schemas_#{format}.lxr")

  puts "Building #{format.to_s.upcase} package..."

  start_time = Time.now

  repository.to_package(
    output_path,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: format,
    metadata: {
      title: "Example Schemas Package",
      description: "Person and Company schemas for demonstration",
      version: "1.0.0",
      created_at: Time.now.utc.iso8601,
      serialization_format: format.to_s
    }
  )

  build_time = Time.now - start_time
  file_size = File.size(output_path)

  package_info << {
    format: format,
    path: output_path,
    size: file_size,
    build_time: build_time
  }

  puts "  ✓ Package created: #{File.basename(output_path)}"
  puts "    Size: #{format_file_size(file_size)}"
  puts "    Build time: #{format_time(build_time)}"
  puts
end

# Step 3: Compare package sizes and load times
# --------------------------------------------
puts "Step 3: Comparing package formats"
puts "-" * 80

puts "Package Size Comparison:"
puts
package_info.sort_by { |p| p[:size] }.each do |info|
  percentage = (info[:size].to_f / package_info.map { |p| p[:size] }.max * 100).round(1)
  bar = "█" * (percentage / 5).to_i
  puts "  #{info[:format].to_s.upcase.ljust(10)} #{format_file_size(info[:size]).rjust(12)} #{bar}"
end

puts
puts "Build Time Comparison:"
puts
package_info.sort_by { |p| p[:build_time] }.each do |info|
  puts "  #{info[:format].to_s.upcase.ljust(10)} #{format_time(info[:build_time])}"
end

puts
puts "Load Time Comparison:"
puts
package_info.each do |info|
  start_time = Time.now
  loaded_repo = Lutaml::Xsd::SchemaRepository.from_package(info[:path])
  load_time = Time.now - start_time

  info[:load_time] = load_time
  puts "  #{info[:format].to_s.upcase.ljust(10)} #{format_time(load_time)}"
end

puts

# Step 4: Build package from YAML configuration
# ---------------------------------------------
puts "Step 4: Building package from YAML configuration"
puts "-" * 80

yaml_config_path = File.join(OUTPUT_DIR, "schemas_config.yml")

# Create YAML configuration
yaml_config = {
  "files" => [PERSON_XSD, COMPANY_XSD],
  "namespace_mappings" => [
    { "prefix" => "p", "uri" => "http://example.com/person" },
    { "prefix" => "c", "uri" => "http://example.com/company" }
  ]
}

File.write(yaml_config_path, yaml_config.to_yaml)
puts "Created YAML configuration: #{File.basename(yaml_config_path)}"

# Load from YAML configuration
puts "Loading repository from YAML configuration..."
yaml_repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(yaml_config_path)
yaml_repository.parse.resolve

# Build package
yaml_package_path = File.join(OUTPUT_DIR, "schemas_from_yaml.lxr")
yaml_repository.to_package(
  yaml_package_path,
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal,
  metadata: {
    title: "Schemas from YAML Config",
    description: "Built from YAML configuration file",
    config_file: File.basename(yaml_config_path),
    version: "1.0.0"
  }
)

puts "✓ Package created from YAML: #{File.basename(yaml_package_path)}"

puts

# Step 5: Validate package contents
# ---------------------------------
puts "Step 5: Validating package contents"
puts "-" * 80

sample_package = package_info.first[:path]
puts "Validating: #{File.basename(sample_package)}"

validation_result = Lutaml::Xsd::SchemaRepository.validate_package(sample_package)

if validation_result.valid?
  puts "✓ Package is valid"
else
  puts "✗ Package has errors:"
  validation_result.errors.each do |error|
    puts "  - #{error}"
  end
end

# Load and inspect package metadata
puts
puts "Package metadata:"
loaded = Lutaml::Xsd::SchemaRepository.from_package(sample_package)
package_metadata = loaded.instance_variable_get(:@metadata) rescue nil

if package_metadata
  puts "  Title: #{package_metadata.title}"
  puts "  Description: #{package_metadata.description}"
  puts "  Version: #{package_metadata.version}"
  puts "  Created: #{package_metadata.created_at}"
else
  puts "  (No metadata available)"
end

puts

# Step 6: Demonstrate smart caching
# ---------------------------------
puts "Step 6: Smart caching demonstration"
puts "-" * 80

cached_package = File.join(OUTPUT_DIR, "cached_schemas.lxr")

puts "First load (will build package)..."
start_time = Time.now
repo1 = Lutaml::Xsd::SchemaRepository.from_file_cached(PERSON_XSD, lxr_path: cached_package)
first_load_time = Time.now - start_time
puts "  Time: #{format_time(first_load_time)}"

puts
puts "Second load (using cached package)..."
start_time = Time.now
repo2 = Lutaml::Xsd::SchemaRepository.from_file_cached(PERSON_XSD, lxr_path: cached_package)
second_load_time = Time.now - start_time
puts "  Time: #{format_time(second_load_time)}"

speedup = (first_load_time / second_load_time).round(1)
puts
puts "  Speedup: #{speedup}x faster using cache"

puts

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "This example demonstrated:"
puts "  ✓ Building LXR packages from XSD files"
puts "  ✓ Different serialization formats (Marshal, JSON, YAML)"
puts "  ✓ Adding custom metadata to packages"
puts "  ✓ Validating package contents"
puts "  ✓ Building from YAML configuration"
puts "  ✓ Smart caching for improved performance"
puts
puts "Packages created in: #{OUTPUT_DIR}"
puts "  - schemas_marshal.lxr (fastest, binary)"
puts "  - schemas_json.lxr (portable, text)"
puts "  - schemas_yaml.lxr (human-readable, text)"
puts "  - schemas_from_yaml.lxr (built from YAML config)"
puts "  - cached_schemas.lxr (smart cache example)"
puts
puts "Recommendations:"
puts "  • Use Marshal format for production (smallest, fastest)"
puts "  • Use JSON for portability across platforms"
puts "  • Use YAML for debugging and human inspection"
puts "  • Use smart caching for development workflows"
puts
puts "Next steps:"
puts "  - Try examples/lxr_search.rb to explore package contents"
puts "  - Try examples/lxr_type_resolution.rb for type queries"
puts "=" * 80