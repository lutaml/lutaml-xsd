# frozen_string_literal: true

require "zeitwerk"
require "lutaml/model"
require "lutaml/model/xml_adapter/nokogiri_adapter"
Lutaml::Model::Config.xml_adapter_type = :nokogiri

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: true)
module Lutaml
  module Xsd
  end
end

loader.push_dir(__dir__, namespace: Lutaml)
loader.push_dir("#{__dir__}/xsd", namespace: Lutaml::Xsd)
loader.setup

module Lutaml
  module Xsd
    class Error < StandardError; end

    module_function

    def parse(xsd, location: nil, nested_schema: false)
      Schema.reset_processed_schemas unless nested_schema

      Glob.path_or_url(location)
      Schema.from_xml(xsd)
    end
  end
end

begin
  loader.eager_load(force: true)
rescue Zeitwerk::NameError => e
  flunk e.message
end
