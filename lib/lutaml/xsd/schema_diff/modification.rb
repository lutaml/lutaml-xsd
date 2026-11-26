# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Xsd
    # One machine-readable modification inside a modified-component
    # change: what aspect of the component moved from what to what.
    class SchemaDiff
      class Modification < Lutaml::Model::Serializable
        attribute :aspect, :string
        attribute :old, :string
        attribute :new, :string
      end
    end
  end
end
