# frozen_string_literal: true

# SPA module autoload entries are defined in lib/lutaml/xsd.rb
# This file exists only for backward compatibility with any code
# that requires "lutaml/xsd/spa" directly.

# SVG diagram generation sub-modules
module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          autoload :ColorScheme, "lutaml/xsd/spa/svg/config/color_scheme"
          autoload :Dimensions, "lutaml/xsd/spa/svg/config/dimensions"
          autoload :Effects, "lutaml/xsd/spa/svg/config/effects"
          autoload :ConnectorStyles, "lutaml/xsd/spa/svg/config/connector_styles"
          autoload :LayoutConfig, "lutaml/xsd/spa/svg/config/layout_config"
          autoload :ComponentRules, "lutaml/xsd/spa/svg/config/component_rules"
          autoload :IndicatorRules, "lutaml/xsd/spa/svg/config/indicator_rules"
        end

        module Geometry
          autoload :Point, "lutaml/xsd/spa/svg/geometry/point"
          autoload :Box, "lutaml/xsd/spa/svg/geometry/box"
        end

        module Utils
          autoload :SvgBuilder, "lutaml/xsd/spa/svg/utils/svg_builder"
        end

        module Connectors
          autoload :InheritanceConnector, "lutaml/xsd/spa/svg/connectors/inheritance_connector"
          autoload :ContainmentConnector, "lutaml/xsd/spa/svg/connectors/containment_connector"
          autoload :ReferenceConnector, "lutaml/xsd/spa/svg/connectors/reference_connector"
        end

        module Layouts
          autoload :VerticalLayout, "lutaml/xsd/spa/svg/layouts/vertical_layout"
          autoload :TreeLayout, "lutaml/xsd/spa/svg/layouts/tree_layout"
        end

        module Renderers
          autoload :TypeRenderer, "lutaml/xsd/spa/svg/renderers/type_renderer"
          autoload :AttributeRenderer, "lutaml/xsd/spa/svg/renderers/attribute_renderer"
          autoload :GroupRenderer, "lutaml/xsd/spa/svg/renderers/group_renderer"
          autoload :ElementRenderer, "lutaml/xsd/spa/svg/renderers/element_renderer"
        end

        autoload :StyleConfiguration, "lutaml/xsd/spa/svg/style_configuration"
        autoload :ComponentRenderer, "lutaml/xsd/spa/svg/component_renderer"
        autoload :ConnectorRenderer, "lutaml/xsd/spa/svg/connector_renderer"
        autoload :LayoutEngine, "lutaml/xsd/spa/svg/layout_engine"
        autoload :DefsBuilder, "lutaml/xsd/spa/svg/defs_builder"
        autoload :DocumentBuilder, "lutaml/xsd/spa/svg/document_builder"
        autoload :DiagramGenerator, "lutaml/xsd/spa/svg/diagram_generator"
      end
    end
  end
end
