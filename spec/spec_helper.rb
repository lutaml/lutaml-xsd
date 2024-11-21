# frozen_string_literal: true

require "lutaml/xsd"
require "xml/c14n"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def schema_to_xml(xml, escape_content_tags: false)
  xml = Xml::C14n.format(xml)
  xml.gsub!(/&lt;([^&]+)&gt;/, '<\1>') if escape_content_tags
  xml
end
