# frozen_string_literal: true

require "lutaml/xsd"
require "equivalent-xml"
require "equivalent-xml/rspec_matchers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def to_xml(parsed_schema, escape_content_tags: false)
  xml = parsed_schema.to_xml
  xml.gsub!(/\&lt;([^\&]+)\&\gt;/, '<\1>') if escape_content_tags
  xml
end
