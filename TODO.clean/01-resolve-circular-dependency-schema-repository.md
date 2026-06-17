# Resolve circular dependency: SchemaRepository ↔ PackageLoader ↔ SchemaParser

## Problem

The service-object extraction started in TODO.refactor/07 was incomplete. Today:

- `SchemaRepository#parse_schema_file` (lib/lutaml/xsd/schema_repository.rb:336)
  is public, so `PackageLoader` can reach into it.
- `PackageLoader` calls back into the repository via
  `@repository.add_schema_file` (lib/lutaml/xsd/package_loader.rb:147) and
  `@repository.parse_schema_file` (lib/lutaml/xsd/package_loader.rb:148).
- `SchemaParser` *also* owns parse logic — its own `import_resolved_schemas`
  (lib/lutaml/xsd/schema_parser.rb:55) duplicates
  `SchemaRepository#import_resolved_schemas` (schema_repository.rb:441).
- Both classes define `parse_xsd_schema`, `parse_rng_schema`,
  `write_generated_xsd`, `update_rng_file_references`.

Net effect: parse logic exists in **two places** and the loader depends on the
repository's private surface via a public façade. Data flow is bidirectional
(repository ↔ loader) when it should be one-directional
(loader → parser → repository).

## Solution

Make the data flow strictly one-directional. The repository is a state holder;
the parser is the only thing that mutates parsed-schemas state; the loader
orchestrates parser calls and feeds results to the repository via a narrow
public API (`add_schema_file`).

### Step 1 — Move parse logic into `SchemaParser`

Move these methods from `SchemaRepository` into `SchemaParser`:

- `parse_schema_file(file_path, glob_mappings)`
- `parse_xsd_schema(file_path, glob_mappings)` (private)
- `parse_rng_schema(file_path)` (private)
- `write_generated_xsd(file_path, schema)` (private)
- `update_rng_file_references(old_path, new_path)` (private)
- `import_resolved_schemas` (private)

`SchemaParser` already has the global-cache plumbing; consolidate it there.

### Step 2 — Drop `SchemaRepository#parse_schema_file` entirely

Consumers (`PackageLoader`, CLI commands, specs) call
`repository.parser.parse_file(...)` instead. `SchemaRepository` exposes
`attr_reader :parser`.

### Step 3 — `PackageLoader` depends on `SchemaParser`, not `SchemaRepository`

```ruby
class PackageLoader
  def initialize(parser:, repository:)
    @parser = parser
    @repository = repository
  end

  def load(glob_mappings)
    # ...
    @parser.parse_file(file_path, glob_mappings)
    # ...
  end
end
```

The repository's only role is to hold the `@parsed_schemas` store; the loader
calls `repository.add_schema_file(path, schema)` to populate it.

### Step 4 — Remove `SchemaRepository#normalize_base_packages_to_configs` indirection

`SchemaRepository#normalize_base_packages_to_configs` (schema_repository.rb:311)
just calls `PackageLoader.new(self).normalize_base_packages_to_configs` — a
useless forwarder. Drop it; consumers call the loader directly.

## Files affected

- `lib/lutaml/xsd/schema_repository.rb` (drop ~120 lines of parse logic)
- `lib/lutaml/xsd/schema_parser.rb` (absorb the moved methods, dedup)
- `lib/lutaml/xsd/package_loader.rb` (depend on parser, not repository)
- `lib/lutaml/xsd/cli.rb`, `lib/lutaml/xsd/commands/*.rb` (update callers)
- All specs that call `repository.parse_schema_file`

## Acceptance criteria

- [ ] Zero `@repository.parse_schema_file` calls outside `SchemaRepository`
- [ ] Zero `@repository.add_schema_file` calls inside `SchemaRepository`
- [ ] `SchemaParser` is the single owner of parse logic (no duplicates)
- [ ] Data flow is one-directional: `loader → parser → repository`
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- `spec/lutaml/xsd/schema_parser_spec.rb` — focused unit specs for each parse
  entry point (XSD, RNG, write-back, reference rewriting, import resolution)
- `spec/lutaml/xsd/package_loader_spec.rb` — real-package fixtures, asserts
  loader→parser→repository wiring without doubles
- Integration spec: load an LXR, assert all entry schemas appear in
  `repository.parsed_schemas`

## Risks

- Many call sites currently use `repository.parse_schema_file`. A deprecation
  shim is acceptable for one release; remove afterwards.
- The CLI's interactive builder uses some of these paths — verify it still
  works after the move.
