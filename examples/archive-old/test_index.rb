# frozen_string_literal: true

require_relative '../lib/lutaml/xsd'

package_path = File.expand_path('../pkg/urban_function_repository.lxr', __dir__)
repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
repository.parse if repository.needs_parsing?

# Check processed schemas before resolve
all_schemas = repository.send(:get_all_processed_schemas)
puts "Processed schemas: #{all_schemas.size}"
all_schemas.first(3).each do |path, schema|
  puts "\nSchema: #{File.basename(path)}"
  puts "  Namespace: #{schema.target_namespace}"
  puts "  Simple types: #{schema.simple_type.size}"
  puts "  Complex types: #{schema.complex_type.size}"
  next unless schema.complex_type.any?

  first_type = schema.complex_type.first
  puts "  First complex type: #{first_type.inspect}"
  puts "  First complex type name: #{first_type.name}"
end

# Now resolve
repository.resolve

# Check if type can be found
result = repository.find_type('gml:CodeType')
puts "\nType resolution:"
puts "  Resolved: #{result.resolved?}"
puts "  Definition: #{result.definition.inspect}"
