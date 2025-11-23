#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'lutaml/xsd'

# Build package with marshal format using YAML config
yaml_config = File.expand_path('urban_function_repository.yml', __dir__)
repository = Lutaml::Xsd::SchemaRepository.from_yaml_file(yaml_config)

# Parse the repository
repository.parse
repository.resolve

# Create package configuration
config = Lutaml::Xsd::PackageConfiguration.new(
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal
)

# Create builder
builder = Lutaml::Xsd::PackageBuilder.new(config)

# Build package data
puts '=== ALL PROCESSED SCHEMAS BEFORE BUILD ==='
puts "Count: #{Lutaml::Xsd::Schema.processed_schemas.size}"
Lutaml::Xsd::Schema.processed_schemas.keys.first(5).each do |loc|
  puts "  #{loc}"
end

puts "\n=== GLOB MAPPINGS ==="
glob_mappings = repository.schema_location_mappings.map(&:to_glob_format)
puts "Count: #{glob_mappings.size}"
glob_mappings.each do |mapping|
  puts "  From: #{mapping[:from].inspect}"
  puts "  To: #{mapping[:to]}"
end

package_data = builder.build(repository, {})

puts "\n=== XSD FILES (from bundler) ==="
puts "Count: #{package_data[:xsd_files].size}"
package_data[:xsd_files].each do |source_path, package_info|
  puts "  Source: #{source_path}"
  if package_info.is_a?(Hash)
    puts "    Package path: #{package_info[:package_path]}"
    puts "    Basename: #{File.basename(package_info[:package_path], '.*')}"
  else
    puts "    Package path: #{package_info}"
    puts "    Basename: #{File.basename(package_info, '.*')}"
  end
end

puts "\n=== SERIALIZED SCHEMAS (from Schema.processed_schemas) ==="
puts "Count: #{package_data[:serialized_schemas].size}"
package_data[:serialized_schemas].each_key do |schema_location|
  # Find corresponding schema object
  schema = Lutaml::Xsd::Schema.processed_schemas[schema_location]

  puts "  Schema location: #{schema_location}"
  puts "    Is absolute?: #{schema_location.start_with?('/')}"
  puts "    Target namespace: #{schema.target_namespace if schema}"

  # Try to match with xsd_files
  matched = false
  package_data[:xsd_files].each do |source_path, package_info|
    # Try absolute path comparison
    schema_abs = if schema_location.start_with?('/')
                   File.absolute_path(schema_location)
                 else
                   begin
                     File.absolute_path(schema_location)
                   rescue StandardError
                     nil
                   end
                 end

    source_abs = File.absolute_path(source_path)

    next unless schema_abs == source_abs

    renamed_path = package_info.is_a?(Hash) ? package_info[:package_path] : package_info
    puts "    MATCHED source: #{source_path}"
    puts "    MATCHED renamed: #{renamed_path}"
    puts "    MATCHED basename: #{File.basename(renamed_path, '.*')}"
    matched = true
    break
  end

  puts '    NO MATCH FOUND' unless matched
end

# Check for basicTypes.xsd specifically
puts "\n=== FOCUS ON basicTypes.xsd ==="
basicTypes_schemas = package_data[:serialized_schemas].select do |location, _|
  location.include?('basicTypes.xsd')
end

puts "Found #{basicTypes_schemas.size} basicTypes.xsd schemas:"
basicTypes_schemas.each_key do |location|
  schema = Lutaml::Xsd::Schema.processed_schemas[location]
  puts "  Location: #{location}"
  puts "    Namespace: #{schema.target_namespace if schema}"
end

basicTypes_xsd_files = package_data[:xsd_files].select do |source, _|
  source.include?('basicTypes.xsd')
end

puts "\nFound #{basicTypes_xsd_files.size} basicTypes.xsd in xsd_files:"
basicTypes_xsd_files.each do |source, package_info|
  puts "  Source: #{source}"
  if package_info.is_a?(Hash)
    puts "    Renamed to: #{package_info[:package_path]}"
  else
    puts "    Package path: #{package_info}"
  end
end
