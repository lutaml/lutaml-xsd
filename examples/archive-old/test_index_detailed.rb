# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

package_path = File.expand_path("../pkg/urban_function_repository.lxr", __dir__)
repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
repository.parse if repository.needs_parsing?

# Now resolve
repository.resolve

# Access the type index directly
type_index = repository.instance_variable_get(:@type_index)
all_types = type_index.all

puts "Total types in index: #{all_types.size}"
puts "\nLooking for CodeType:"

# Find CodeType entries
code_types = all_types.select { |k, _v| k.include?("CodeType") }
puts "Found #{code_types.size} CodeType entries:"
code_types.each do |key, info|
  puts "\n  Key: #{key}"
  puts "  Namespace: #{info[:namespace]}"
  puts "  Type: #{info[:type]}"
  puts "  Definition: #{info[:definition].inspect}"
  puts "  Definition.name: #{info[:definition]&.name}"
end

# Try find_by_namespace_and_name
puts "\nDirect lookup:"
result = type_index.find_by_namespace_and_name("http://www.opengis.net/gml/3.2", "CodeType")
puts "Result: #{result.inspect}"
