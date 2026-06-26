# frozen_string_literal: true

# Canonical home for SchemaRepository package metadata snapshot.
# The class itself still lives in lutaml/xsd/schema_repository_metadata.rb
# pending removal of the legacy top-level alias; new code should reference
# Lutaml::Xsd::SchemaRepository::Metadata.

require "lutaml/xsd/schema_repository_metadata"

module Lutaml
  module Xsd
    class SchemaRepository
      Metadata = ::Lutaml::Xsd::SchemaRepositoryMetadata
    end
  end
end
