#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

# Load and parse repository
repo = Lutaml::Xsd::SchemaRepository.from_yaml_file(
  "examples/urban_function_repository.yml",
)
repo.parse
repo.resolve

# Build package data
config = Lutaml::Xsd::PackageConfiguration.new(
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal,
)
builder = Lutaml::Xsd::PackageBuilder.new(config)
package_data = builder.build(repo, {})

xsd_files = package_data[:xsd_files]
serialized_schemas = package_data[:serialized_schemas]

puts "XSD Files keys (basicTypes):"
xsd_files.keys.select { |k| k.include?("basicTypes") }.each do |k|
  puts "  #{k}"
end
puts

puts "Serialized Schemas keys (basicTypes):"
serialized_schemas.keys.select { |k| k.include?("basicTypes") }.each do |k|
  puts "  #{k}"
end
puts

# Check if they match
puts "Checking matches:"
serialized_schemas.keys.select do |k|
  k.include?("basicTypes")
end.each do |file_path|
  package_info = xsd_files[file_path]
  puts "  #{file_path}"
  puts "    Found in xsd_files: #{!package_info.nil?}"
  if package_info
    renamed = package_info.is_a?(Hash) ? package_info[:package_path] : package_info
    puts "    Renamed to: #{renamed}"
  end
  puts
end
