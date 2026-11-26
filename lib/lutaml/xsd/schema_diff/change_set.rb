# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Xsd
    # The complete component-level change set between two schema
    # versions.
    class SchemaDiff
      class ChangeSet < Lutaml::Model::Serializable
        autoload :Change, "lutaml/xsd/schema_diff/change"

        attribute :changes, SchemaDiff::Change, collection: true

        # Counts per category (added/removed/renamed/moved_namespace/
        # modified).
        def summary
          changes.each_with_object(Hash.new(0)) do |change, h|
            h[change.category] += 1
          end
        end
      end
    end
  end
end
