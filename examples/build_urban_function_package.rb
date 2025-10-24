#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"
require "fileutils"

# This example demonstrates building a schema repository package from
# the urban function XSD schema using YAML configuration (DRY approach).

puts "=" * 80
puts "Building Schema Repository Package from urbanFunction.xsd"
puts "=" * 80
puts

# Setup paths
yaml_config = File.expand_path("urban_function_repository.yml", __dir__)
output_package = File.expand_path("../pkg/urban_function_repository.lxr", __dir__)

# Ensure output directory exists
FileUtils.mkdir_p(File.dirname(output_package))

puts "Configuration:"
puts "  YAML Config: #{File.basename(yaml_config)}"
puts "  Output Package: #{output_package}"
puts

begin
  # Step 1: Load repository from YAML configuration
  puts "Step 1: Loading repository from YAML configuration..."
  repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(yaml_config)
  puts "  ✓ Configuration loaded"
  puts "    Files: #{repository.files.size}"
  puts "    Schema Location Mappings: #{repository.schema_location_mappings.size}"
  puts "    Namespace Mappings: #{repository.namespace_mappings.size}"
  puts

  # Step 2: Parse and resolve schemas
  puts "Step 2: Parsing and resolving schemas..."
  puts "  (This may take a moment due to the complexity of the schema...)"
  repository.parse.resolve
  puts "  ✓ Schemas parsed and resolved successfully"
  puts

  # Step 3: Create package with configuration
  puts "Step 3: Creating package with configuration..."
  puts "  XSD Mode: include_all (bundle all XSD dependencies)"
  puts "  Resolution Mode: resolved (pre-serialize schemas for instant loading)"

  package = repository.to_package(
    output_package,
    xsd_mode: :include_all, # Bundle all XSD dependencies
    resolution_mode: :resolved, # Pre-serialize for instant loading
    metadata: {
      name: "Urban Function Schema Repository",
      version: "3.2",
      description: "i-UR Urban Function schema with dependencies",
      created_by: "lutaml-xsd package builder"
    }
  )
  puts "  ✓ Package created: #{output_package}"
  puts "  Package size: #{File.size(output_package)} bytes"
  puts

  # Step 4: Validate the package
  puts "Step 4: Validating package..."
  validation = package.validate

  puts "  Validation Result: #{validation.valid? ? "✓ VALID" : "✗ INVALID"}"
  puts

  if validation.errors.any?
    puts "  Errors (#{validation.errors.size}):"
    validation.errors.each do |error|
      puts "    - #{error}"
    end
    puts
  end

  if validation.warnings.any?
    puts "  Warnings (#{validation.warnings.size}):"
    validation.warnings.each do |warning|
      puts "    - #{warning}"
    end
    puts
  end

  # Step 5: Display package metadata
  puts "Step 5: Package Metadata:"
  puts "-" * 80
  validation.metadata.each do |key, value|
    if value.is_a?(Array)
      puts "  #{key}: (#{value.size} items)"
      value.first(3).each { |item| puts "    - #{item.inspect}" }
      puts "    ..." if value.size > 3
    else
      puts "  #{key}: #{value}"
    end
  end
  puts

  # Summary
  puts "=" * 80
  puts "SUMMARY"
  puts "=" * 80
  puts "✓ Package successfully created and validated!"
  puts
  puts "Package Details:"
  puts "  Location: #{output_package}"
  puts "  Size: #{File.size(output_package)} bytes"
  puts "  Valid: #{validation.valid?}"
  puts "  Errors: #{validation.errors.size}"
  puts "  Warnings: #{validation.warnings.size}"
  puts
  puts "You can now:"
  puts "  1. Share this package as a self-contained schema repository"
  puts "  2. Load it back using SchemaRepositoryPackage.new(path).load_repository"
  puts "  3. Validate other packages using SchemaRepository.validate_package(path)"
  puts "=" * 80
rescue StandardError => e
  puts "✗ ERROR: #{e.class}: #{e.message}"
  puts
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
