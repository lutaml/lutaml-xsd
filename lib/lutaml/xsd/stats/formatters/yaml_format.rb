# frozen_string_literal: true

require "yaml"

module Lutaml
  module Xsd
    module Stats
      module Formatters
        # YAML rendering of repository stats.
        class YamlFormat < Base
          # @param stats [Hash] Output of Stats::Collector#call
          # @return [String]
          def self.render(stats)
            stats.to_yaml
          end
        end

        register(:yaml, YamlFormat)
      end
    end
  end
end
