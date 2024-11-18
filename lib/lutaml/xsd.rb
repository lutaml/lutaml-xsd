# frozen_string_literal: true

require "zeitwerk"
require "lutaml/model"
require_relative "xsd/xsd"

Zeitwerk::Loader.default_logger = method(:puts)
loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: true)
loader.push_dir("lib/lutaml/xsd", namespace: Lutaml::Xsd)
loader.ignore("#{__dir__}/lib/lutaml/xsd.rb")
loader.setup
