#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for search functionality
# Usage: ruby examples/search_demo.rb

require_relative "../lib/lutaml/xsd"

puts "=" * 80
puts "Type Search Feature Demo"
puts "=" * 80
puts ""

# Check if UnitsML package exists
package_path = File.expand_path("../tmp/unitsml-auto.lxr", __dir__)

unless File.exist?(package_path)
  puts "⚠️  UnitsML package not found at: #{package_path}"
  puts ""
  puts "Please create the package first using:"
  puts "  bundle exec ruby examples/build_unitsml_package.rb"
  exit 1
end

puts "📦 Loading UnitsML package..."
repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
puts "✓ Package loaded"
puts ""

# Create searcher
searcher = Lutaml::Xsd::TypeSearcher.new(repository)

# Demo 1: Search for "unit" in both name and documentation
puts "Demo 1: Searching for 'unit' (default: search both name and documentation)"
puts "-" * 80
results = searcher.search("unit")
puts "Found #{results.size} results"
results.take(5).each do |result|
  puts ""
  puts "  #{result.qualified_name}"
  puts "  Category: #{result.category}"
  puts "  Relevance: #{result.relevance_score} (#{result.match_type})"
  puts "  Documentation: #{result.documentation[0..100]}..." if result.documentation && !result.documentation.empty?
end
puts ""

# Demo 2: Search only in names
puts "Demo 2: Searching for 'system' in names only"
puts "-" * 80
results = searcher.search("system", in_field: "name")
puts "Found #{results.size} results"
results.take(5).each do |result|
  puts "  #{result.qualified_name} (#{result.category}) - Score: #{result.relevance_score}"
end
puts ""

# Demo 3: Search only in documentation
puts "Demo 3: Searching for 'container' in documentation only"
puts "-" * 80
results = searcher.search("container", in_field: "documentation")
puts "Found #{results.size} results"
results.take(5).each do |result|
  puts "  #{result.qualified_name} - #{result.match_type}"
  puts "    Doc: #{result.documentation[0..80]}..." if result.documentation
end
puts ""

# Demo 4: Filter by namespace
puts "Demo 4: Searching for 'Type' filtered by UnitsML namespace"
puts "-" * 80
unitsml_ns = "http://www.unitsml.org/unitsml/1.0"
results = searcher.search("Type", namespace: unitsml_ns, limit: 10)
puts "Found #{results.size} results in namespace #{unitsml_ns}"
results.each do |result|
  puts "  #{result.qualified_name} (#{result.category})"
end
puts ""

# Demo 5: Filter by category
puts "Demo 5: Searching for 'Type' in complex_type category only"
puts "-" * 80
results = searcher.search("Type", category: "complex_type", limit: 10)
puts "Found #{results.size} complex types"
results.each do |result|
  puts "  #{result.qualified_name} - Score: #{result.relevance_score}"
end
puts ""

# Demo 6: Demonstrate relevance ranking
puts "Demo 6: Relevance ranking demonstration"
puts "-" * 80
puts "Searching for 'unit' to show different match types ranked by relevance:"
results = searcher.search("unit", limit: 15)
current_score = nil
results.each do |result|
  if result.relevance_score != current_score
    puts ""
    puts "  Score #{result.relevance_score} (#{result.match_type}):"
    current_score = result.relevance_score
  end
  puts "    - #{result.qualified_name}"
end
puts ""

puts "=" * 80
puts "Demo complete! 🎉"
puts ""
puts "CLI Usage Examples:"
puts "  lutaml-xsd search 'unit' tmp/unitsml-auto.lxr"
puts "  lutaml-xsd search 'system' tmp/unitsml-auto.lxr --in name"
puts "  lutaml-xsd search 'container' tmp/unitsml-auto.lxr --in documentation"
puts "  lutaml-xsd search 'Type' tmp/unitsml-auto.lxr --category complex_type"
puts "  lutaml-xsd search 'unit' tmp/unitsml-auto.lxr --format json"
puts "  lutaml-xsd s 'unit' tmp/unitsml-auto.lxr  # 's' is an alias"
puts "  lutaml-xsd ? 'unit' tmp/unitsml-auto.lxr  # '?' is also an alias"
puts "=" * 80
