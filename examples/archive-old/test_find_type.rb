# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

package_path = File.expand_path("../pkg/urban_function_repository.lxr", __dir__)
repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
repository.parse if repository.needs_parsing?
repository.resolve

# Test the find_type method
result = repository.find_type("gml:CodeType")

puts "Result resolved?: #{result.resolved?}"
puts "Result qname: #{result.qname}"
puts "Result namespace: #{result.namespace}"
puts "Result local_name: #{result.local_name}"
puts "Result schema_file: #{result.schema_file}"
puts "Result definition: #{result.definition.inspect}"
puts "Result definition class: #{result.definition&.class&.name}"

# Check type_info from index
type_index = repository.instance_variable_get(:@type_index)
type_info = type_index.find_by_namespace_and_name(
  "http://www.opengis.net/gml/3.2", "CodeType"
)
puts "\nDirect type_info from index:"
puts "  definition: #{type_info[:definition].inspect}"
puts "  definition class: #{type_info[:definition].class.name}"
