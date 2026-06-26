#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/lutaml_xsd"

# Create a schema repository from the test schema
repo = Lutaml::Xsd::SchemaRepository.new
repo.add_schema_file(File.expand_path("test_schema.xsd", __dir__))
repo.parse.resolve

# Create the LXR package
output_path = File.expand_path("test_schema.lxr", __dir__)
repo.to_package(
  output_path,
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal,
)

puts "✓ Created #{output_path}"
