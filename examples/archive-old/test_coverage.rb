#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

puts "=" * 80
puts "Coverage Analysis Demo"
puts "=" * 80
puts ""

# Create a simple test repository with mock types
repo = Lutaml::Xsd::SchemaRepository.new

# For demonstration, we'll use the metaschema fixtures
fixtures_dir = File.expand_path("../spec/fixtures", __dir__)
schema_file = File.join(fixtures_dir, "metaschema-datatypes.xsd")

unless File.exist?(schema_file)
  puts "Error: Test schema not found at #{schema_file}"
  exit 1
end

# Load and parse the schema
puts "Loading schema: #{File.basename(schema_file)}"
repo.instance_variable_set(:@files, [schema_file])
repo.parse.resolve

puts "✓ Schema loaded and resolved"
puts ""

# Get some type names to use as entry points
all_types = repo.all_type_names
puts "Total types in repository: #{all_types.size}"
puts ""

if all_types.empty?
  puts "No types found in repository"
  exit 0
end

# Use first few types as entry points
entry_types = all_types.first([3, all_types.size].min)
puts "Entry types for analysis: #{entry_types.join(", ")}"
puts ""

# Perform coverage analysis
puts "Analyzing coverage..."
report = repo.analyze_coverage(entry_types: entry_types)

puts "=" * 80
puts "Coverage Analysis Results"
puts "=" * 80
puts ""
puts "Summary:"
puts "  Total Types: #{report.total_types}"
puts "  Used Types: #{report.used_count}"
puts "  Unused Types: #{report.unused_count}"
puts "  Coverage: #{report.coverage_percentage}%"
puts ""

puts "By Namespace:"
report.by_namespace.each do |ns, data|
  ns_display = ns.length > 60 ? "...#{ns[-57..]}" : ns
  puts "  #{ns_display}:"
  puts "    Total: #{data[:total]}, Used: #{data[:used]}, Coverage: #{data[:coverage_percentage]}%"
end
puts ""

puts "=" * 80
puts "✓ Coverage analysis completed successfully"
puts "=" * 80