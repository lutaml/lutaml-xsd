# Eliminate dual state: global Schema.processed_schemas vs @parsed_schemas store

## Problem
SchemaRepository maintains two sources of truth:
1. `@parsed_schemas` (instance-local `BasicStore`) — set via `set`, `exists?`, `all`
2. `Lutaml::Xml::Schema::Xsd::Schema.processed_schemas` (global class-level hash)

`all_schemas` returns the GLOBAL cache, not the instance store. Multiple
repository instances corrupt each other's state. The `BasicStore` is redundant.

## Solution

### 1. Make @parsed_schemas the single source of truth
Change `all_schemas` to return `@parsed_schemas.all` instead of
`Schema.processed_schemas`.

### 2. Stop writing to global cache
Remove `Schema.schema_processed(file_path, parsed_schema)` from
`parse_schema_file`. The schema is already stored in `@parsed_schemas`.

### 3. Update consumers of global cache
- `SchemaResolver` — inject the store or use the repository
- `DefinitionExtractor` — use `all_schemas` method (which now returns from store)
- `EntrypointIdentifier` — use `all_schemas`
- `update_rng_file_references` — only update `@parsed_schemas`, not global

### 4. Keep global cache as read-only fallback
For schemas parsed by `Lutaml::Xml::Schema::Xsd.parse()` internally
(import/include resolution), they still register in the global cache.
The repository should merge these into its local store during resolution.

## Files affected
- `lib/lutaml/xsd/schema_repository.rb`
- `lib/lutaml/xsd/schema_resolver.rb`
- `lib/lutaml/xsd/definition_extractor.rb`
- `lib/lutaml/xsd/entrypoint_identifier.rb`

## Acceptance criteria
- [ ] `all_schemas` returns data from `@parsed_schemas`, not global cache
- [ ] Multiple SchemaRepository instances don't share state
- [ ] Import/include resolution still works
- [ ] `bundle exec rake` passes
