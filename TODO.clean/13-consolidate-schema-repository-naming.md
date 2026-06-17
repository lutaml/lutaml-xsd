# Consolidate SchemaRepository-prefixed classes into SchemaRepository namespace

## Problem

Several related classes share a long redundant prefix:

- `SchemaRepository` (lib/lutaml/xsd/schema_repository.rb)
- `SchemaRepositoryMetadata` (lib/lutaml/xsd/schema_repository_metadata.rb)
- `SchemaRepositoryPackage` (lib/lutaml/xsd/schema_repository_package.rb)
- `SchemaRepositoryStatistics` (lib/lutaml/xsd/schema_repository_statistics.rb)
- `SchemaRepository::TypeIndex` (already namespaced — good)
- `SchemaRepository::NamespaceRegistry` (already namespaced — good)
- `SchemaRepository::QualifiedNameParser` (already namespaced — good)

The naming inconsistency (some inner classes namespaced, some as flat
peers with redundant prefix) makes the type hierarchy unclear. A reader
can't tell at a glance which classes are collaborators of
`SchemaRepository`.

## Solution

Move the flat peers into the `SchemaRepository` namespace:

| Old | New |
|---|---|
| `Lutaml::Xsd::SchemaRepositoryMetadata` | `Lutaml::Xsd::SchemaRepository::Metadata` |
| `Lutaml::Xsd::SchemaRepositoryPackage` | `Lutaml::Xsd::SchemaRepository::Package` |
| `Lutaml::Xsd::SchemaRepositoryStatistics` | `Lutaml::Xsd::SchemaRepository::Statistics` |

### File layout

The current `lib/lutaml/xsd/schema_repository.rb` already defines the
class and has inner classes in `lib/lutaml/xsd/schema_repository/`. Move
the peer files into that directory:

- `lib/lutaml/xsd/schema_repository/metadata.rb`
- `lib/lutaml/xsd/schema_repository/package.rb`
- `lib/lutaml/xsd/schema_repository/statistics.rb`

Each defines `class SchemaRepository::Metadata`, etc.

### Autoloads

Update `lib/lutaml/xsd/schema_repository.rb` to autoload the inner
classes:

```ruby
class SchemaRepository
  autoload :Metadata, "lutaml/xsd/schema_repository/metadata"
  autoload :Package, "lutaml/xsd/schema_repository/package"
  autoload :Statistics, "lutaml/xsd/schema_repository/statistics"
  autoload :TypeIndex, "lutaml/xsd/schema_repository/type_index"
  autoload :NamespaceRegistry, "lutaml/xsd/schema_repository/namespace_registry"
  autoload :QualifiedNameParser, "lutaml/xsd/schema_repository/qualified_name_parser"
  # ...
end
```

### Backward compat

Provide deprecation aliases for one release:

```ruby
module Lutaml
  module Xsd
    SchemaRepositoryMetadata = SchemaRepository::Metadata
    SchemaRepositoryPackage = SchemaRepository::Package
    SchemaRepositoryStatistics = SchemaRepository::Statistics
  end
end
```

Mark with `# DEPRECATED: use SchemaRepository::Metadata` and remove after
one release.

## Files affected

- `lib/lutaml/xsd/schema_repository_metadata.rb` →
  `lib/lutaml/xsd/schema_repository/metadata.rb`
- `lib/lutaml/xsd/schema_repository_package.rb` →
  `lib/lutaml/xsd/schema_repository/package.rb`
- `lib/lutaml/xsd/schema_repository_statistics.rb` →
  `lib/lutaml/xsd/schema_repository/statistics.rb`
- `lib/lutaml/xsd/schema_repository.rb` (autoloads)
- `lib/lutaml/xsd.rb` (autoload entries — old constants removed)
- All callers (CLI commands, specs, etc.)

## Acceptance criteria

- [ ] All four classes live under `Lutaml::Xsd::SchemaRepository::*`
- [ ] Deprecation aliases exist for one release
- [ ] No `Lutaml::Xsd::SchemaRepository*` (long prefix) references in
  `lib/` except the aliases
- [ ] All specs pass
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- Existing specs for these classes continue to pass (just under the new
  constant names).
- One spec verifying the deprecation aliases still resolve.

## Risks

- External consumers referencing the old constants will break. The
  deprecation aliases mitigate this; document the rename in the
  changelog.
- `SchemaRepositoryPackage` is the LXR ZIP reader/writer — it's a big
  file. The move is purely a rename, no logic changes, but verify by
  running the full integration test suite.
