# Add focused unit specs for new service objects

## Problem

TODO.refactor/07 extracted four service objects from `SchemaRepository`:

- `SchemaParser` (122 lines)
- `PackageLoader` (185 lines)
- `SchemaQueryService` (171 lines)
- `SchemaExporter` (121 lines)

Each has *integration* coverage through `schema_repository_spec.rb`, but
none has its own focused unit spec. As TODO.clean/02 and TODO.clean/10
decompose them further, the integration tests won't be enough to catch
regressions inside the collaborators.

Good specs throughout — the rule from the global CLAUDE.md — means each
public method on each service has direct coverage with real models (not
doubles, per TODO.clean/08).

## Solution

Create one focused unit spec per service. Each spec file:

- Uses real model instances (no `double()`)
- Calls the service directly (not through `SchemaRepository`)
- Covers each public method with happy-path and edge-case examples

### `spec/lutaml/xsd/schema_parser_spec.rb`

Targets (one `describe` per public method):

- `#parse(files, glob_mappings, verbose:)` — multiple files, mixed XSD/RNG
- `#parse_file(file_path, glob_mappings)` — XSD entry, RNG entry,
  nonexistent file, already-parsed file (idempotency)
- Private methods like `parse_xsd`, `parse_rng`, `write_generated_xsd`,
  `update_rng_references` — test through the public surface, not via
  `send`

Fixtures: small XSDs and RNGs in `spec/fixtures/schema_parser/`.

### `spec/lutaml/xsd/package_loader_spec.rb`

Targets:

- `#load(glob_mappings)` — happy path, conflict-detection path
- `#normalize_base_packages_to_configs` — strings, hashes,
  `BasePackageConfig` instances
- `#load_package_with_filtering` — single package, multiple packages,
  filtering behaviour (or removal per TODO.clean/07)
- Conflict-detection branch — uses real
  `PackageConflictDetector` (no doubles)

Fixtures: synthetic `.lxr` packages or real ones from
`spec/fixtures/packages/`.

### `spec/lutaml/xsd/schema_query_service_spec.rb`

Targets (each method):

- `#find_type(qname)` — found, not found, ambiguous (multiple namespaces)
- `#find_attribute(qname)`, `#find_element(qname)`,
  `#find_group(qname)`, `#find_attribute_group(qname)` — same matrix
- `#type_exists?(qname)` — boolean matrix
- `#all_type_names(namespace:)` — filtered by namespace

Fixtures: build a small in-memory repository with
`Factories.schema_with_types(...)` (per TODO.clean/08).

### `spec/lutaml/xsd/schema_exporter_spec.rb`

Targets:

- `#statistics` — hash structure and counts
- `#export_statistics(format:)` — text, json, yaml (after TODO.clean/10,
  this moves to `Stats::Formatter.format`)
- `#namespace_summary` — grouping correctness
- `#elements_by_namespace(namespace_uri:)` — filtering correctness

Use a real repository with a known fixture; assert exact structures.

## Files affected

- NEW: `spec/lutaml/xsd/schema_parser_spec.rb`
- NEW: `spec/lutaml/xsd/package_loader_spec.rb`
- NEW: `spec/lutaml/xsd/schema_query_service_spec.rb`
- NEW: `spec/lutaml/xsd/schema_exporter_spec.rb`
- NEW: `spec/support/factories.rb` (if not created in TODO.clean/08)
- NEW: `spec/fixtures/schema_parser/*.xsd`, `*.rng`
- NEW: `spec/fixtures/packages/*.lxr` (small synthetic packages)

## Acceptance criteria

- [ ] Each service has its own spec file with focused unit coverage
- [ ] Each public method has at least one happy-path spec and one
  edge-case spec
- [ ] No `double()` in any of the new specs
- [ ] No `instance_variable_set/get` in any of the new specs
- [ ] No `send(:private_method)` in any of the new specs
- [ ] All new specs pass under `bundle exec rspec`
- [ ] All new specs are discoverable by `bundle exec rake spec` (per
  TODO.clean/09 fix)

## Specs required

This TODO *is* specs.

## Risks

- Building real test fixtures is more upfront work than doubles, but
  the resulting specs are far more durable.
- The integration coverage in `schema_repository_spec.rb` may overlap
  with the new unit specs — that's fine, integration specs verify the
  wiring; unit specs verify the units.
