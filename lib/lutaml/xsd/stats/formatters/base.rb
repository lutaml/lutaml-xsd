# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      module Formatters
        # Abstract formatter. Subclasses implement `.render`.
        class Base
          # @param stats [Hash] Output of Stats::Collector#call
          # @return [String]
          def self.render(_stats)
            raise NotImplementedError,
                  "#{name} must implement .render(stats)"
          end
        end
      end
    end
  end
end
