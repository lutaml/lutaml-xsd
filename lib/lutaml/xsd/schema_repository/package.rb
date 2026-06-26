# frozen_string_literal: true

# Canonical home for the LXR ZIP package reader/writer.
# The class itself still lives in lutaml/xsd/schema_repository_package.rb
# pending removal of the legacy top-level alias; new code should reference
# Lutaml::Xsd::SchemaRepository::Package.

require "lutaml/xsd/schema_repository_package"

module Lutaml
  module Xsd
    class SchemaRepository
      Package = ::Lutaml::Xsd::SchemaRepositoryPackage
    end
  end
end
