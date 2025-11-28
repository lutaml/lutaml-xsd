# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

package_path = File.expand_path("../pkg/urban_function_repository.lxr", __dir__)
repository = Lutaml::Xsd::SchemaRepository.from_package(package_path)
repository.parse if repository.needs_parsing?
repository.resolve

result = repository.find_type("gml:CodeType")
puts "Resolved: #{result.resolved?}"
puts "Definition: #{result.definition.inspect}"
puts "Definition class: #{result.definition.class}"
puts "Definition class.name: #{result.definition.class.name}"
puts "Definition name: #{result.definition.name}" if result.definition.respond_to?(:name)
