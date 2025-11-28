#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

puts "=" * 80
puts "Debug Marshal Loading"
puts "=" * 80
puts

# Load the repository from packaged .lxr file
package_path = File.expand_path("../pkg/urban_function_repository.lxr", __dir__)
puts "Loading repository from package: #{File.basename(package_path)}"

repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
puts "✓ Repository loaded from package"
puts "  Files: #{repository.files.size}"
puts

# Check global processed_schemas cache
all_schemas = Lutaml::Xsd::Schema.instance_variable_get(:@processed_schemas) || {}
puts "Total schemas in global cache: #{all_schemas.size}"
puts

# Group by namespace
by_namespace = Hash.new(0)
all_schemas.each_value do |schema|
  ns = schema.target_namespace || "(no namespace)"
  by_namespace[ns] += 1
end

puts "Schemas by namespace:"
by_namespace.sort_by { |_ns, count| -count }.each do |ns, count|
  puts "  #{ns}: #{count}"
end
puts

# Resolve and build type index
puts "Building type index..."
repository.resolve
puts

# Check type index
stats = repository.statistics
puts "Repository Statistics:"
puts "  Total schemas parsed: #{stats[:total_schemas]}"
puts "  Total types indexed: #{stats[:total_types]}"
puts "  Types by category:"
stats[:types_by_category].each do |category, count|
  puts "    #{category}: #{count}"
end
puts "  Total namespaces: #{stats[:total_namespaces]}"
puts

# Check specific namespace
gml_ns = "http://www.opengis.net/gml/3.2"
type_index = repository.instance_variable_get(:@type_index)
if type_index
  gml_types = type_index.select do |qname, _entry|
    qname.start_with?("{#{gml_ns}}")
  end
  puts "GML namespace (#{gml_ns}):"
  puts "  Types found: #{gml_types.size}"

  if gml_types.empty?
    puts "  WARNING: No types found in GML namespace!"
    puts
    puts "Available namespaces in type index:"
    namespaces = type_index.keys.map do |qname|
      qname[/\{([^}]+)\}/, 1]
    end.compact.uniq
    namespaces.each do |ns|
      ns_types = type_index.select do |qname, _entry|
        qname.start_with?("{#{ns}}")
      end
      puts "    #{ns}: #{ns_types.size} types"
    end
  else
    # List first 20 GML types
    puts "  First 20 types:"
    gml_types.first(20).each do |qname, entry|
      local_name = qname[/\}(.+)$/, 1]
      puts "    - #{local_name} (#{entry.category})"
    end

    # Check for CodeType specifically
    code_type_qname = "{#{gml_ns}}CodeType"
    puts
    if gml_types.key?(code_type_qname)
      puts "  ✓ CodeType found in type index!"
    else
      puts "  ✗ CodeType NOT found in type index"
      puts "    Searching for 'Code' in type names:"
      code_types = gml_types.select { |qname, _entry| qname.include?("Code") }
      code_types.each do |qname, entry|
        local_name = qname[/\}(.+)$/, 1]
        puts "      - #{local_name} (#{entry.category})"
      end
    end
  end
end
