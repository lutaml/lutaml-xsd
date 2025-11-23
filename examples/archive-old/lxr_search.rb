#!/usr/bin/env ruby
# frozen_string_literal: true

# LXR Package Searching Example
#
# This example demonstrates searching capabilities within LXR packages:
# - Search types by name
# - Search by namespace
# - Filter by category
# - Display search results with relevance ranking
# - Documentation search
#
# Usage:
#   ruby examples/lxr_search.rb

require 'bundler/setup'
require 'lutaml/xsd'

# Configuration
SCHEMAS_DIR = File.expand_path('validation/sample_schemas', __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, 'person.xsd')
COMPANY_XSD = File.join(SCHEMAS_DIR, 'company.xsd')
PACKAGE_PATH = File.join(SCHEMAS_DIR, 'company_schemas.lxr')

puts '=' * 80
puts 'LXR Package Searching Example'
puts '=' * 80
puts

# Step 1: Setup - Build package if needed
# ---------------------------------------
puts 'Step 1: Loading schema repository'
puts '-' * 80

if File.exist?(PACKAGE_PATH)
  puts '✓ Using existing package'
else
  puts 'Building LXR package...'
  repository = Lutaml::Xsd::SchemaRepository.new
  repository.instance_variable_set(:@files, [PERSON_XSD, COMPANY_XSD])
  repository.configure_namespaces({
                                    'p' => 'http://example.com/person',
                                    'c' => 'http://example.com/company'
                                  })
  repository.parse.resolve
  repository.to_package(
    PACKAGE_PATH,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: :marshal
  )
  puts '✓ Package created'
end

repository = Lutaml::Xsd::SchemaRepository.from_package(PACKAGE_PATH)

stats = repository.statistics
puts 'Repository statistics:'
puts "  - Total schemas: #{stats[:total_schemas]}"
puts "  - Total types: #{stats[:total_types]}"
puts "  - Namespaces: #{stats[:total_namespaces]}"

puts

# Step 2: Search types by name
# ----------------------------
puts 'Step 2: Searching types by name'
puts '-' * 80

searcher = Lutaml::Xsd::TypeSearcher.new(repository)

search_queries = [
  { query: 'Person', field: 'name', description: 'Exact match' },
  { query: 'Type', field: 'name', description: 'Partial match' },
  { query: 'Emp', field: 'name', description: 'Prefix match' }
]

search_queries.each do |search|
  puts "Query: '#{search[:query]}' in #{search[:field]} (#{search[:description]})"

  results = searcher.search(search[:query], in_field: search[:field], limit: 10)

  if results.empty?
    puts '  No results found'
  else
    puts "  Found #{results.size} result(s):"
    results.take(5).each do |result|
      puts "    • #{result.qualified_name} (#{result.category})"
      puts "      Match type: #{result.match_type}"
      puts "      Relevance: #{result.relevance_score}"
      puts "      Schema: #{File.basename(result.schema_file)}"
    end
    puts "    ... and #{results.size - 5} more" if results.size > 5
  end
  puts
end

# Step 3: Search by namespace
# ---------------------------
puts 'Step 3: Filtering by namespace'
puts '-' * 80

repository.all_namespaces.each do |ns|
  prefix = repository.namespace_to_prefix(ns)
  types = repository.all_type_names(namespace: ns)

  puts "Namespace: #{ns}"
  puts "Prefix: #{prefix || '(none)'}"
  puts "Types (#{types.size}):"

  types.each do |type_name|
    puts "  - #{type_name}"
  end
  puts
end

# Step 4: Filter by category
# --------------------------
puts 'Step 4: Filtering by category'
puts '-' * 80

categories = %i[complex_type simple_type element attribute]

categories.each do |category|
  types = repository.all_type_names(category: category)

  next if types.empty?

  puts "Category: #{category}"
  puts "Count: #{types.size}"
  puts 'Types:'
  types.each do |type_name|
    puts "  - #{type_name}"
  end
  puts
end

# Step 5: Documentation search
# ----------------------------
puts 'Step 5: Searching in documentation'
puts '-' * 80

doc_queries = %w[
  employee
  address
  email
]

doc_queries.each do |query|
  puts "Searching for '#{query}' in documentation..."

  results = searcher.search(query, in_field: 'documentation', limit: 5)

  if results.empty?
    puts '  No results found'
  else
    puts "  Found #{results.size} result(s):"
    results.each do |result|
      puts "    • #{result.qualified_name}"
      puts "      #{result.documentation[0..100]}..." if result.documentation && !result.documentation.empty?
    end
  end
  puts
end

# Step 6: Combined search (name and documentation)
# ------------------------------------------------
puts 'Step 6: Combined search (name and documentation)'
puts '-' * 80

combined_query = 'person'
puts "Searching for '#{combined_query}' in both name and documentation..."

results = searcher.search(combined_query, in_field: 'both', limit: 10)

if results.empty?
  puts '  No results found'
else
  puts "  Found #{results.size} result(s) (sorted by relevance):"
  puts

  results.each_with_index do |result, idx|
    puts "  #{idx + 1}. #{result.qualified_name} (#{result.category})"
    puts "     Match type: #{result.match_type}"
    puts "     Relevance: #{result.relevance_score}"
    puts "     Namespace: #{result.namespace}"
    puts "     Schema: #{File.basename(result.schema_file)}"

    if result.documentation && !result.documentation.empty?
      doc_preview = result.documentation[0..80]
      doc_preview += '...' if result.documentation.length > 80
      puts "     Documentation: #{doc_preview}"
    end
    puts
  end
end

# Step 7: Batch type query
# ------------------------
puts 'Step 7: Batch type query'
puts '-' * 80

puts 'Querying multiple types at once...'

batch_query = Lutaml::Xsd::BatchTypeQuery.new(repository)
type_queries = [
  'p:PersonType',
  'p:EmailType',
  'c:CompanyType',
  'c:EmployeeType'
]

puts 'Types to query:'
type_queries.each { |q| puts "  - #{q}" }
puts

results = batch_query.execute(type_queries)

puts 'Results:'
results.each do |qname, result|
  if result.nil?
    puts "  ✗ #{qname} => Query failed (nil result)"
  elsif result.resolved?
    puts "  ✓ #{qname} => Found"
    puts "    Namespace: #{result.namespace}"
    puts "    Schema: #{File.basename(result.schema_file)}"
  else
    puts "  ✗ #{qname} => Not found"
    puts "    Error: #{result.error_message}"
  end
  puts
end

# Step 8: Namespace summary
# -------------------------
puts 'Step 8: Namespace summary'
puts '-' * 80

summary = repository.namespace_summary

puts 'Namespace summary:'
puts
summary.each do |ns_info|
  puts "Namespace: #{ns_info[:uri]}"
  puts "  Prefix: #{ns_info[:prefix] || '(none)'}"
  puts "  Types: #{ns_info[:types]}"
  puts
end

# Summary
puts '=' * 80
puts 'Example completed successfully!'
puts
puts 'This example demonstrated:'
puts '  ✓ Searching types by name with fuzzy matching'
puts '  ✓ Filtering types by namespace'
puts '  ✓ Filtering types by category (complex, simple, element, etc.)'
puts '  ✓ Searching in type documentation'
puts '  ✓ Combined search across name and documentation'
puts '  ✓ Batch type queries for efficiency'
puts '  ✓ Namespace summaries'
puts
puts 'Search features:'
puts '  • Relevance ranking (exact > starts with > contains)'
puts '  • Namespace-aware filtering'
puts '  • Category-based filtering'
puts '  • Documentation search'
puts '  • Configurable result limits'
puts
puts 'Next steps:'
puts '  - Try examples/lxr_type_resolution.rb for type hierarchy analysis'
puts '  - Explore the CLI: lutaml-xsd search --help'
puts '=' * 80
