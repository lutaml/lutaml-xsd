# frozen_string_literal: true

require "lutaml/model"

adapter = RUBY_ENGINE == "opal" ? :oga : :nokogiri
Lutaml::Model::Config.xml_adapter_type = adapter

module Lutaml
  module Xsd
    class Error < StandardError; end

    module_function

    def register
      @register ||= Lutaml::Model::GlobalRegister.register(
        Lutaml::Model::Register.new(:xsd)
      )
    end

    def register_model(klass, id)
      register.register_model(klass, id: id)
    end

    def parse(xsd, location: nil, nested_schema: false, register: nil, schema_mappings: nil)
      register ||= self.register
      Schema.reset_processed_schemas unless nested_schema

      Glob.schema_mappings = schema_mappings
      Glob.path_or_url(location)
      Schema.from_xml(xsd, register: register)
    end
  end
end

require_relative "xsd/version"
require_relative "xsd/base"
require_relative "xsd/schema_location_mapping"
require_relative "xsd/namespace_mapping"
require_relative "xsd/type_resolution_result"
require_relative "xsd/type_index_entry"
require_relative "xsd/serialized_schema"
require_relative "xsd/package_configuration"
require_relative "xsd/schema_resolver"
require_relative "xsd/xsd_bundler"
require_relative "xsd/package_builder"
require_relative "xsd/schema_name_resolver"
require_relative "xsd/schema_repository_metadata"
require_relative "xsd/schema_repository_package"
require_relative "xsd/schema_repository"
require_relative "xsd/all"
require_relative "xsd/annotation"
require_relative "xsd/any"
require_relative "xsd/any_attribute"
require_relative "xsd/appinfo"
require_relative "xsd/attribute"
require_relative "xsd/attribute_group"
require_relative "xsd/choice"
require_relative "xsd/complex_content"
require_relative "xsd/complex_type"
require_relative "xsd/documentation"
require_relative "xsd/element"
require_relative "xsd/enumeration"
require_relative "xsd/extension_complex_content"
require_relative "xsd/extension_simple_content"
require_relative "xsd/field"
require_relative "xsd/fraction_digits"
require_relative "xsd/glob"
require_relative "xsd/group"
require_relative "xsd/import"
require_relative "xsd/include"
require_relative "xsd/key"
require_relative "xsd/keyref"
require_relative "xsd/length"
require_relative "xsd/list"
require_relative "xsd/max_exclusive"
require_relative "xsd/max_inclusive"
require_relative "xsd/max_length"
require_relative "xsd/min_exclusive"
require_relative "xsd/min_inclusive"
require_relative "xsd/min_length"
require_relative "xsd/notation"
require_relative "xsd/pattern"
require_relative "xsd/redefine"
require_relative "xsd/restriction_complex_content"
require_relative "xsd/restriction_simple_content"
require_relative "xsd/restriction_simple_type"
require_relative "xsd/schema"
require_relative "xsd/selector"
require_relative "xsd/sequence"
require_relative "xsd/simple_content"
require_relative "xsd/simple_type"
require_relative "xsd/total_digits"
require_relative "xsd/union"
require_relative "xsd/unique"
require_relative "xsd/white_space"
