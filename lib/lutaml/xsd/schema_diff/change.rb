# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Xsd
    # One component-level change between two schema versions.
    class SchemaDiff
      class Change < Lutaml::Model::Serializable
        autoload :Modification, "lutaml/xsd/schema_diff/modification"

        attribute :category, :string
        attribute :kind, :string
        attribute :namespace, :string
        attribute :local_name, :string
        attribute :renamed_from, :string
        attribute :modifications, SchemaDiff::Modification,
                  collection: true

        # The identity key the engine keyed this component under
        # ("{ns}LocalName" Clark form; local-only when unnamespaced).
        def identity
          namespace.to_s.match?(/\S/) ? "{#{namespace}}#{local_name}" : local_name.to_s
        end
      end
    end
  end
end
