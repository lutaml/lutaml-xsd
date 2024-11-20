# frozen_string_literal: true

require "zeitwerk"
require "lutaml/model"
require_relative "xsd/xsd"

Lutaml::Model::Config.xml_adapter_type = :nokogiri

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: true)
loader.push_dir("#{__dir__}/xsd", namespace: Lutaml::Xsd)
loader.ignore("#{__dir__}/lib/lutaml/xsd.rb")
loader.setup
