# frozen_string_literal: true

module Lutaml
  module Xsd
    class Error < StandardError; end

    module_function

    def set_nokogiri_adapter
      require "lutaml/model/xml_adapter/nokogiri_adapter"
      Lutaml::Model::Config.xml_adapter = Lutaml::Model::XmlAdapter::NokogiriAdapter
    end

    def parse(xsd)
      set_nokogiri_adapter
      Schema.from_xml(xsd)
    end
  end
end
