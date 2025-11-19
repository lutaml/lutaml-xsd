#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"
require "fileutils"
require "benchmark"

# This example demonstrates the four package configuration types
# and compares their characteristics

puts "=" * 80
puts "Package Configuration Types Comparison"
puts "=" * 80
puts

# Setup paths
yaml_config = File.expand_path("urban_function_repository.yml", __dir__)
pkg_dir = File.expand_path("../pkg", __dir__)
FileUtils.mkdir_p(pkg_dir)

# Load and parse repository once
puts "Loading and parsing repository..."
repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(yaml_config)
repository.parse.resolve
puts "✓ Repository ready"
puts

# Define the four package types
package_types = [
  {
    name: "Type 1: Include All + Resolved",
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    file: File.join(pkg_dir, "type1_include_resolved.lxr"),
    description: "Self-contained, instant load (RECOMMENDED)"
  },
  {
    name: "Type 2: Include All + Bare",
    xsd_mode: :include_all,
    resolution_mode: :bare,
    file: File.join(pkg_dir, "type2_include_bare.lxr"),
    description: "Self-contained, parse on load"
  },
  {
    name: "Type 3: Allow External + Resolved",
    xsd_mode: :allow_external,
    resolution_mode: :resolved,
    file: File.join(pkg_dir, "type3_external_resolved.lxr"),
    description: "External deps, instant load"
  },
  {
    name: "Type 4: Allow External + Bare",
    xsd_mode: :allow_external,
    resolution_mode: :bare,
    file: File.join(pkg_dir, "type4_external_bare.lxr"),
    description: "External deps, parse on load"
  }
]

results = []

# Create each package type and measure
package_types.each_with_index do |config, _idx|
  puts "=" * 80
  puts "Creating #{config[:name]}"
  puts "  #{config[:description]}"
  puts "=" * 80

  # Measure creation time
  creation_time = Benchmark.realtime do
    repository.to_package(
      config[:file],
      xsd_mode: config[:xsd_mode],
      resolution_mode: config[:resolution_mode],
      metadata: {
        name: "Urban Function Repository - #{config[:name]}",
        description: config[:description]
      }
    )
  end

  file_size = File.size(config[:file])

  puts "✓ Created: #{File.basename(config[:file])}"
  puts "  Creation time: #{(creation_time * 1000).round(2)}ms"
  puts "  File size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"
  puts

  # Measure load time
  puts "Testing load performance..."
  load_time = Benchmark.realtime do
    test_repo = Lutaml::Xsd::SchemaRepository.from_package(config[:file])
    test_repo.parse if test_repo.needs_parsing?
    test_repo.resolve
  end

  puts "  Load time: #{(load_time * 1000).round(2)}ms"
  puts

  results << {
    name: config[:name],
    xsd_mode: config[:xsd_mode],
    resolution_mode: config[:resolution_mode],
    creation_time: creation_time,
    file_size: file_size,
    load_time: load_time,
    description: config[:description]
  }
end

# Summary comparison table
puts "=" * 80
puts "COMPARISON SUMMARY"
puts "=" * 80
puts
puts format("%-40s %12s %12s %12s", "Package Type", "Size (KB)", "Create (ms)", "Load (ms)")
puts "-" * 80

results.each do |r|
  puts format("%-40s %12.2f %12.2f %12.2f", r[:name].sub("Type ", ""), r[:file_size] / 1024.0,
              r[:creation_time] * 1000, r[:load_time] * 1000)
end

puts
puts "=" * 80
puts "RECOMMENDATIONS"
puts "=" * 80
puts
puts "Type 1 (Include All + Resolved) - RECOMMENDED for most use cases"
puts "  ✓ Self-contained (no external dependencies)"
puts "  ✓ Fast loading (pre-serialized schemas)"
puts "  ✓ Portable and shareable"
puts "  ✗ Larger file size"
puts
puts "Type 2 (Include All + Bare)"
puts "  ✓ Self-contained (no external dependencies)"
puts "  ✓ Smaller file size"
puts "  ✗ Slower loading (must parse XSD files)"
puts
puts "Type 3 (Allow External + Resolved)"
puts "  ✓ Fast loading (pre-serialized schemas)"
puts "  ✓ Smaller file size"
puts "  ✗ Requires external XSD dependencies"
puts
puts "Type 4 (Allow External + Bare)"
puts "  ✓ Smallest file size"
puts "  ✗ Requires external XSD dependencies"
puts "  ✗ Slowest loading (must parse XSD files)"
puts
puts "=" * 80
puts "All package types created in: #{pkg_dir}"
puts "=" * 80
