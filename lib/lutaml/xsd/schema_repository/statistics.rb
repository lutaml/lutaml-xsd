# frozen_string_literal: true

# Canonical home for SchemaRepository statistics snapshot.
# The class itself still lives in lutaml/xsd/schema_repository_metadata.rb
# pending removal of the legacy top-level alias; new code should reference
# Lutaml::Xsd::SchemaRepository::Statistics.

require "lutaml/xsd/schema_repository_metadata"

module Lutaml
  module Xsd
    class SchemaRepository
      Statistics = ::Lutaml::Xsd::SchemaRepositoryStatistics
    end
  end
end
