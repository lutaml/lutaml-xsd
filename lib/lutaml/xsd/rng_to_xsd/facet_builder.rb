# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Builds XSD facets from RNG params via a registry. New facets are added
      # by registering a builder, not by editing a case statement (OCP).
      class FacetBuilder
        Xsd = Lutaml::Xml::Schema::Xsd

        # Each entry maps an RNG param name to a lambda that takes
        # (restriction, value, file_path) and updates the restriction.
        REGISTRY = {
          "minInclusive" => lambda do |restriction, value, _|
            restriction.min_inclusive = Xsd::MinInclusive.new(value: value)
          end,
          "maxInclusive" => lambda do |restriction, value, _|
            restriction.max_inclusive = Xsd::MaxInclusive.new(value: value)
          end,
          "minExclusive" => lambda do |restriction, value, _|
            restriction.min_exclusive = Xsd::MinExclusive.new(value: value.to_i)
          end,
          "maxExclusive" => lambda do |restriction, value, _|
            restriction.max_exclusive = Xsd::MaxExclusive.new(value: value.to_i)
          end,
          "pattern" => lambda do |restriction, value, _|
            restriction.pattern = Xsd::Pattern.new(value: value)
          end,
          "totalDigits" => lambda do |restriction, value, _|
            restriction.total_digits = Xsd::TotalDigits.new(value: value)
          end,
          "fractionDigits" => lambda do |restriction, value, _|
            restriction.fraction_digits = Xsd::FractionDigits.new(value: value)
          end,
          "minLength" => lambda do |restriction, value, _|
            restriction.min_length = Xsd::MinLength.new(value: value.to_i)
          end,
          "maxLength" => lambda do |restriction, value, _|
            restriction.max_length = Xsd::MaxLength.new(value: value.to_i)
          end,
          "length" => lambda do |restriction, value, _|
            restriction.length = Xsd::Length.new(value: value.to_i)
          end,
          "whiteSpace" => lambda do |restriction, value, _|
            restriction.white_space = Xsd::WhiteSpace.new(value: value)
          end,
        }.freeze

        def apply(restriction, param, file_path: nil)
          builder = REGISTRY[param.name]
          return if builder&.call(restriction, param.value, file_path)

          warn "Warning: Unknown RNG param '#{param.name}' in #{file_path}"
        end
      end
    end
  end
end
