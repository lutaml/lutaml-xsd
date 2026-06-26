# frozen_string_literal: true

require "yaml"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # StyleConfiguration depends on the Config value objects below.
        # Declare the autoloads at the Svg module level so StyleConfiguration
        # is self-contained — callers that load this file directly (without
        # first loading spa.rb) still resolve Config::ColorScheme etc.
        module Config
          autoload :ColorScheme, "lutaml/xsd/spa/svg/config/color_scheme"
          autoload :Dimensions, "lutaml/xsd/spa/svg/config/dimensions"
          autoload :Effects, "lutaml/xsd/spa/svg/config/effects"
          autoload :ConnectorStyles, "lutaml/xsd/spa/svg/config/connector_styles"
          autoload :LayoutConfig, "lutaml/xsd/spa/svg/config/layout_config"
          autoload :ComponentRules, "lutaml/xsd/spa/svg/config/component_rules"
          autoload :IndicatorRules, "lutaml/xsd/spa/svg/config/indicator_rules"
        end

        # Loads and provides access to SVG styling configuration
        class StyleConfiguration
          attr_reader :colors, :dimensions, :effects, :connectors,
                      :layout_config

          def self.load(styles_path = nil, rules_path = nil)
            styles_path ||= default_styles_path
            rules_path ||= default_rules_path

            styles = YAML.load_file(styles_path)
            rules = File.exist?(rules_path) ? YAML.load_file(rules_path) : {}

            new(styles, rules)
          end

          def initialize(styles_hash, rules_hash = {})
            @colors = Config::ColorScheme.new(styles_hash["colors"] || {})
            @dimensions = Config::Dimensions.new(styles_hash["dimensions"] || {})
            @effects = Config::Effects.new(styles_hash["effects"] || {})
            @connectors = Config::ConnectorStyles.new(styles_hash["connectors"] || {})
            @layout_config = Config::LayoutConfig.new(styles_hash["layout"] || {})
            @component_rules = Config::ComponentRules.new(rules_hash["components"] || {})
            @indicator_rules = Config::IndicatorRules.new(rules_hash["indicators"] || {})
          end

          def layout_type
            @layout_config.default
          end

          def component_rule(component_type)
            @component_rules.rule_for(component_type)
          end

          def indicator_rule(indicator_type)
            @indicator_rules.rule_for(indicator_type)
          end

          def self.default_styles_path
            File.join(__dir__, "../../../../../config/spa/svg_styles.yml")
          end

          def self.default_rules_path
            File.join(__dir__,
                      "../../../../../config/spa/svg_component_rules.yml")
          end
        end
      end
    end
  end
end
