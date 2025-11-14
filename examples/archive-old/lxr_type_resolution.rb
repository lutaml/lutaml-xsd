#!/usr/bin/env ruby
# frozen_string_literal: true

# LXR Type Resolution Example
#
# This example demonstrates type resolution capabilities:
# - Find types using different formats (prefixed, Clark notation)
# - Navigate type hierarchies
# - Display type information
# - Show type dependencies
# - Analyze inheritance chains
#
# Usage:
#   ruby examples/lxr_type_resolution.rb

require "bundler/setup"
require "lutaml/xsd"

# Configuration
SCHEMAS_DIR = File.expand_path("validation/sample_schemas", __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, "person.xsd")
COMPANY_XSD = File.join(SCHEMAS_DIR, "company.xsd")
PACKAGE_PATH = File.join(SCHEMAS_DIR, "company_schemas.lxr")

puts "=" * 80
puts "LXR Type Resolution Example"
puts "=" * 80
puts

# Step 1: Setup - Load repository
# -------------------------------
puts "Step 1: Loading schema repository"
puts "-" * 80

unless File.exist?(PACKAGE_PATH)
  puts "Building LXR package..."
  repository = Lutaml::Xsd::SchemaRepository.new
  repository.instance_variable_set(:@files, [PERSON_XSD, COMPANY_XSD])
  repository.configure_namespaces({
    "p" => "http://example.com/person",
    "c" => "http://example.com/company"
  })
  repository.parse.resolve
  repository.to_package(
    PACKAGE_PATH,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: :marshal
  )
end

repository = Lutaml::Xsd::SchemaRepository.from_package(PACKAGE_PATH)
puts "✓ Repository loaded"

puts

# Step 2: Type resolution with different formats
# ----------------------------------------------
puts "Step 2: Type resolution with different name formats"
puts "-" * 80

type_formats = [
  {
    name: "p:PersonType",
    description: "Prefixed name (namespace:localName)"
  },
  {
    name: "{http://example.com/person}PersonType",
    description: "Clark notation ({namespace}localName)"
  },
  {
    name: "PersonType",
    description: "Local name only (searches all namespaces)"
  }
]

type_formats.each do |format|
  puts "Format: #{format[:description]}"
  puts "Query: #{format[:name]}"

  result = repository.find_type(format[:name])

  if result.resolved?
    puts "  ✓ Type found"
    puts "    Qualified name: #{result.qname}"
    puts "    Namespace: #{result.namespace}"
    puts "    Local name: #{result.local_name}"
    puts "    Schema file: #{File.basename(result.schema_file)}"
    puts "    Resolution path: #{result.resolution_path.join(' -> ')}"
  else
    puts "  ✗ Not found"
    puts "    Error: #{result.error_message}"
  end
  puts
end

# Step 3: Display type information
# --------------------------------
puts "Step 3: Detailed type information"
puts "-" * 80

types_to_inspect = [
  "p:PersonType",
  "p:AddressType",
  "c:EmployeeType"
]

types_to_inspect.each do |qname|
  puts "Type: #{qname}"
  result = repository.find_type(qname)

  if result.resolved?
    definition = result.definition

    puts "  Category: #{definition.class.name.split('::').last}"

    # Display attributes
    if definition.respond_to?(:attribute) && definition.attribute
      attrs = definition.attribute
      attrs = [attrs] unless attrs.is_a?(Array)

      unless attrs.empty?
        puts "  Attributes:"
        attrs.each do |attr|
          required = attr.use == "required" ? " (required)" : ""
          puts "    - #{attr.name}: #{attr.type}#{required}"
        end
      end
    end

    # Display elements (for complex types)
    if definition.respond_to?(:sequence) && definition.sequence
      sequence = definition.sequence
      elements = sequence.respond_to?(:element) ? sequence.element : []
      elements = [elements] unless elements.is_a?(Array)

      unless elements.compact.empty?
        puts "  Elements:"
        elements.compact.each do |elem|
          occurs = ""
          if elem.min_occurs || elem.max_occurs
            min = elem.min_occurs || "1"
            max = elem.max_occurs || "1"
            occurs = " [#{min}..#{max}]"
          end
          puts "    - #{elem.name}: #{elem.type}#{occurs}"
        end
      end
    end

    # Display base type (for extensions)
    if definition.respond_to?(:complex_content) && definition.complex_content
      extension = definition.complex_content.extension
      if extension && extension.base
        puts "  Extends: #{extension.base}"
      end
    end

    # Display documentation
    if definition.respond_to?(:annotation) && definition.annotation
      docs = definition.annotation.documentation
      docs = [docs] unless docs.is_a?(Array)

      docs.compact.each do |doc|
        content = doc.respond_to?(:content) ? doc.content : doc.to_s
        if content && !content.strip.empty?
          puts "  Documentation:"
          content.strip.split("\n").each do |line|
            puts "    #{line.strip}"
          end
        end
      end
    end
  else
    puts "  ✗ Not found: #{result.error_message}"
  end
  puts
end

# Step 4: Type hierarchy analysis
# -------------------------------
puts "Step 4: Type hierarchy analysis"
puts "-" * 80

hierarchical_type = "c:EmployeeType"
puts "Analyzing hierarchy for: #{hierarchical_type}"

hierarchy_result = repository.analyze_type_hierarchy(hierarchical_type, depth: 10)

if hierarchy_result
  puts "  Base type: #{hierarchy_result[:base_type] || '(none)'}"
  puts "  Depth: #{hierarchy_result[:depth]}"

  if hierarchy_result[:hierarchy] && !hierarchy_result[:hierarchy].empty?
    puts "  Hierarchy chain:"
    hierarchy_result[:hierarchy].each_with_index do |type_name, idx|
      indent = "    " + ("  " * idx)
      puts "#{indent}└─ #{type_name}"
    end
  end

  if hierarchy_result[:derived_types] && !hierarchy_result[:derived_types].empty?
    puts "  Derived types:"
    hierarchy_result[:derived_types].each do |derived|
      puts "    - #{derived}"
    end
  end
else
  puts "  (No hierarchy information available)"
end

puts

# Step 5: Type dependencies
# -------------------------
puts "Step 5: Type dependencies"
puts "-" * 80

type_to_analyze = "c:CompanyType"
puts "Finding dependencies for: #{type_to_analyze}"

result = repository.find_type(type_to_analyze)

if result.resolved?
  definition = result.definition
  dependencies = Set.new

  # Collect element types
  if definition.respond_to?(:sequence) && definition.sequence
    sequence = definition.sequence
    elements = sequence.respond_to?(:element) ? sequence.element : []
    elements = [elements] unless elements.is_a?(Array)

    elements.compact.each do |elem|
      dependencies << elem.type if elem.type
    end
  end

  # Collect attribute types
  if definition.respond_to?(:attribute) && definition.attribute
    attrs = definition.attribute
    attrs = [attrs] unless attrs.is_a?(Array)

    attrs.each do |attr|
      dependencies << attr.type if attr.type
    end
  end

  puts "  Direct dependencies: #{dependencies.size}"
  dependencies.each do |dep|
    puts "    - #{dep}"
  end
else
  puts "  ✗ Type not found"
end

puts

# Step 6: Type existence check
# ----------------------------
puts "Step 6: Quick type existence check"
puts "-" * 80

types_to_check = [
  "p:PersonType",
  "p:InvalidType",
  "c:CompanyType",
  "x:NonExistentType"
]

puts "Checking type existence (fast operation):"
types_to_check.each do |qname|
  exists = repository.type_exists?(qname)
  status = exists ? "✓ EXISTS" : "✗ NOT FOUND"
  puts "  #{qname.ljust(25)} #{status}"
end

puts

# Step 7: Parse qualified names
# -----------------------------
puts "Step 7: Qualified name parsing"
puts "-" * 80

names_to_parse = [
  "p:PersonType",
  "{http://example.com/person}EmailType",
  "CompanyType"
]

puts "Parsing qualified names:"
names_to_parse.each do |name|
  puts "Input: #{name}"

  parsed = repository.parse_qualified_name(name)

  if parsed
    puts "  Prefix: #{parsed[:prefix] || '(none)'}"
    puts "  Namespace: #{parsed[:namespace] || '(none)'}"
    puts "  Local name: #{parsed[:local_name]}"
  else
    puts "  ✗ Failed to parse"
  end
  puts
end

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "This example demonstrated:"
puts "  ✓ Type resolution with different name formats"
puts "  ✓ Prefixed names (prefix:localName)"
puts "  ✓ Clark notation ({namespace}localName)"
puts "  ✓ Local names (searches all namespaces)"
puts "  ✓ Detailed type information display"
puts "  ✓ Type hierarchy analysis"
puts "  ✓ Dependency tracking"
puts "  ✓ Quick type existence checks"
puts "  ✓ Qualified name parsing"
puts
puts "Type resolution features:"
puts "  • Multiple name format support"
puts "  • Namespace-aware resolution"
puts "  • Resolution path tracking"
puts "  • Inheritance chain analysis"
puts "  • Dependency graph building"
puts "  • Fast existence checking"
puts
puts "Related examples:"
puts "  - examples/lxr_search.rb for searching capabilities"
puts "  - examples/lxr_build.rb for package creation"
puts "  - examples/validation/ for validation examples"
puts "=" * 80