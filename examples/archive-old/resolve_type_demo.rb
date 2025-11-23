#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/lutaml/xsd'

puts '=' * 80
puts 'Schema Repository Type Resolution Demo'
puts '=' * 80
puts

# Load the repository from packaged .lxr file
package_path = File.expand_path('../pkg/urban_function_repository.lxr', __dir__)
puts "Loading repository from package: #{File.basename(package_path)}"

repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
puts '✓ Repository loaded from package'
puts "  Files: #{repository.files.size}"
puts "  Schema Location Mappings: #{repository.schema_location_mappings.size}"
puts "  Namespace Mappings: #{repository.namespace_mappings.size}"
puts

# Parse and resolve (only parse if needed)
if repository.needs_parsing?
  puts 'Parsing schemas from XSD files...'
  puts '  (Namespace mappings will be auto-registered during parse)'
  repository.parse
  puts '✓ Schemas parsed from XSD files'
else
  puts '✓ Schemas already loaded from package (instant load)'
end

puts 'Building type index and resolving cross-references...'
repository.resolve
puts '✓ Repository resolved and ready for queries'
puts

# Display repository statistics
stats = repository.statistics
puts 'Repository Statistics:'
puts "  Total schemas parsed: #{stats[:total_schemas]}"
puts "  Total types indexed: #{stats[:total_types]}"
puts '  Types by category:'
stats[:types_by_category].each do |category, count|
  puts "    #{category}: #{count}"
end
puts "  Total namespaces: #{stats[:total_namespaces]}"
puts

# Resolve gml:CodeType
puts '=' * 80
puts 'Resolving type: gml:CodeType'
puts '=' * 80
puts

result = repository.find_type('gml:CodeType')

puts 'Resolution Result:'
puts "  Resolved: #{result.resolved?}"

if result.resolved?
  puts "  Qualified Name: #{result.qname}"
  puts "  Namespace: #{result.namespace}"
  puts "  Local Name: #{result.local_name}"
  puts "  Schema File: #{File.basename(result.schema_file)}"
  puts '  Resolution Path:'
  result.resolution_path.each_with_index do |step, idx|
    puts "    #{idx + 1}. #{step}"
  end
  puts
  puts '  Type Definition:'
  puts "    Class: #{result.definition.class.name}"
  puts "    Name: #{result.definition.name}" if result.definition.respond_to?(:name)

  # Display annotation/documentation
  if result.definition.respond_to?(:annotation) && result.definition.annotation
    annotation = result.definition.annotation
    if annotation.respond_to?(:documentation) && annotation.documentation
      docs = annotation.documentation.is_a?(Array) ? annotation.documentation : [annotation.documentation]
      docs.compact.each do |doc|
        content = doc.respond_to?(:content) ? doc.content : doc.to_s
        next unless content && !content.strip.empty?

        puts '    Documentation:'
        content.strip.split("\n").each do |line|
          puts "      #{line.strip}"
        end
      end
    end
  end

  # Display simple content structure
  if result.definition.respond_to?(:simple_content) && result.definition.simple_content
    simple_content = result.definition.simple_content
    puts '    Simple Content:'

    if simple_content.respond_to?(:extension) && simple_content.extension
      extension = simple_content.extension
      puts '      Extension:'
      puts "        Base: #{extension.base}" if extension.respond_to?(:base)

      # Display attributes from extension
      if extension.respond_to?(:attribute) && extension.attribute && !extension.attribute.empty?
        puts '        Attributes:'
        attrs = extension.attribute.is_a?(Array) ? extension.attribute : [extension.attribute]
        attrs.compact.each do |attr|
          attr_name = attr.respond_to?(:name) ? attr.name : 'unknown'
          attr_type = attr.respond_to?(:type) ? attr.type : 'unknown'
          attr_use = attr.respond_to?(:use) ? attr.use : nil
          use_str = attr_use ? " (#{attr_use})" : ''
          puts "          - #{attr_name}: #{attr_type}#{use_str}"
        end
      end
    end
  end

  # Display complex content structure
  if result.definition.respond_to?(:complex_content) && result.definition.complex_content
    complex_content = result.definition.complex_content
    puts '    Complex Content:'

    if complex_content.respond_to?(:extension) && complex_content.extension
      extension = complex_content.extension
      puts '      Extension:'
      puts "        Base: #{extension.base}" if extension.respond_to?(:base)
    end
  end

  # Display direct attributes (not from simple_content/complex_content)
  if result.definition.respond_to?(:attribute) && result.definition.attribute && !result.definition.attribute.empty?
    attrs = result.definition.attribute.is_a?(Array) ? result.definition.attribute : [result.definition.attribute]
    if attrs.any?
      puts '    Direct Attributes:'
      attrs.compact.each do |attr|
        attr_name = attr.respond_to?(:name) ? attr.name : 'unknown'
        attr_type = attr.respond_to?(:type) ? attr.type : 'unknown'
        attr_use = attr.respond_to?(:use) ? attr.use : nil
        use_str = attr_use ? " (#{attr_use})" : ''
        puts "      - #{attr_name}: #{attr_type}#{use_str}"
      end
    end
  end
else
  puts "  Error: #{result.error_message}"
  if result.resolution_path && !result.resolution_path.empty?
    puts '  Resolution Path:'
    result.resolution_path.each_with_index do |step, idx|
      puts "    #{idx + 1}. #{step}"
    end
  end
end

puts
puts '=' * 80
puts 'Demo Complete'
puts '=' * 80
