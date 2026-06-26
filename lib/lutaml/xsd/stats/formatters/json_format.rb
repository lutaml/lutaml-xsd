# frozen_string_literal: true

require "json"

module Lutaml
  module Xsd
    module Stats
      module Formatters
        # Pretty-printed JSON rendering of repository stats.
        class JsonFormat < Base
          # @param stats [Hash] Output of Stats::Collector#call
          # @return [String]
          def self.render(stats)
            JSON.pretty_generate(stats)
          end
        end

        register(:json, JsonFormat)
      end
    end
  end
end
