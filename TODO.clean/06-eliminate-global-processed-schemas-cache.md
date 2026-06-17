# Eliminate global `Lutaml::Xml::Schema::Xsd::Schema.processed_schemas` cache

## Problem

`Lutaml::Xml::Schema::Xsd::Schema.processed_schemas` is a **class-level global
hash** shared across all `SchemaRepository` instances in the process. Today
it is read and mutated in 14 places across `lib/`:

```
lib/lutaml/xsd/schema_repository.rb:442
lib/lutaml/xsd/schema_repository.rb:500
lib/lutaml/xsd/schema_parser.rb:56
lib/lutaml/xsd/schema_parser.rb:115
lib/lutaml/xsd/entrypoint_identifier.rb:50
lib/lutaml/xsd/entrypoint_identifier.rb:81
lib/lutaml/xsd/definition_extractor.rb:104
lib/lutaml/xsd/definition_extractor.rb:126
lib/lutaml/xsd/definition_extractor.rb:143
lib/lutaml/xsd/schema_dependency_analyzer.rb:96
lib/lutaml/xsd/schema_dependency_analyzer.rb:116
lib/lutaml/xsd/schema_dependency_analyzer.rb:124
lib/lutaml/xsd/schema_classifier.rb:121
lib/lutaml/xsd/schema_repository_package.rb:583
lib/lutaml/xsd/commands/package_command.rb:890
lib/lutaml/xsd/commands/pkg_command.rb:631
lib/lutaml/xsd/commands/pkg_command.rb:658
```

Concrete failure modes:

1. **Cross-repository contamination.** Two `SchemaRepository` instances
   constructed in the same process will see each other's parsed schemas.
2. **Test pollution.** A test that loads schema X bleeds into a later test
   that loads schema Y. This is a common source of flaky CI.
3. **Reentrant imports break.** Loading package A that imports B's XSD
   corrupts B's state.

`@parsed_schemas` (a per-instance `BasicStore`) already exists. The global
is a redundant second source of truth.

TODO.refactor/03 was opened for this; it was partially addressed but the
global is still read/written from 14 sites.

## Solution

The per-instance `@parsed_schemas` is the single source of truth. The global
is removed (or, if it must remain for compatibility with the upstream
`lutaml-xml` gem, treated as a read-only view into the active repository's
local store).

### Strategy: per-repository `Schemas::Registry`

Replace the global with a value object owned by each `SchemaRepository`:

```ruby
class SchemaRepository
  def initialize(...)
    @parsed_schemas = BasicStore.new
    # ...
  end

  def all_schemas
    @parsed_schemas.all
  end
end
```

Update every read site in `lib/` to call the repository method instead of
the global. There are 17 such sites; many are in 2-line loops that
trivially become `repository.all_schemas.each { |k, v| ... }`.

For the **mutation** sites (`Schema.processed_schemas[k] = v` in
`schema_parser.rb` and `schema_repository_package.rb`), the parse result
is already being added to `@parsed_schemas`; the global write is the
redundant one. Delete those writes.

For **upstream interaction** (the upstream `lutaml-xml` parser may write to
its own global during `import`/`include` resolution): hook the active
repository into that interaction by, e.g., wrapping the call in a context
where a known per-repository sink is fed. If the upstream API does not allow
that, **copy the upstream's writes into `@parsed_schemas` after the call**,
do not re-expose the global.

### Spec strategy: write a regression test FIRST

```ruby
it "isolates SchemaRepository instances" do
  repo1 = described_class.new
  repo2 = described_class.new
  # load schema A into repo1
  # load schema B into repo2
  expect(repo1.all_schemas.keys).not_to include("path/to/B.xsd")
  expect(repo2.all_schemas.keys).not_to include("path/to/A.xsd")
end
```

This spec is currently red (the global leaks across instances). It must be
green before this TODO is considered done.

## Files affected

- `lib/lutaml/xsd/schema_repository.rb` (define `all_schemas`, remove the
  global read in `import_resolved_schemas` and `update_rng_file_references`)
- `lib/lutaml/xsd/schema_parser.rb` (remove the global reads/writes)
- `lib/lutaml/xsd/entrypoint_identifier.rb` (use repository)
- `lib/lutaml/xsd/definition_extractor.rb` (use repository)
- `lib/lutaml/xsd/schema_dependency_analyzer.rb` (use repository)
- `lib/lutaml/xsd/schema_classifier.rb` (use repository)
- `lib/lutaml/xsd/schema_repository_package.rb` (use repository)
- `lib/lutaml/xsd/commands/package_command.rb` (use repository)
- `lib/lutaml/xsd/commands/pkg_command.rb` (use repository)
- A new `Lutaml::Xsd::Schemas::Registry` value object (optional, but a
  cleaner home than `BasicStore` if we want richer semantics)

## Acceptance criteria

- [ ] Zero `Lutaml::Xml::Schema::Xsd::Schema.processed_schemas` reads in
  `lib/`
- [ ] Zero `Lutaml::Xml::Schema::Xsd::Schema.processed_schemas` writes in
  `lib/` (or, if writes remain, they are limited to the upstream
  interop shim and documented)
- [ ] The "isolates SchemaRepository instances" spec passes
- [ ] The full test suite passes (no cross-test pollution)
- [ ] `bundle exec rake` passes

## Specs required

- `spec/lutaml/xsd/schema_repository_spec.rb` — instance-isolation spec
  (above)
- `spec/lutaml/xsd/definition_extractor_spec.rb` — verify it uses
  repository input, not global
- `spec/lutaml/xsd/schema_dependency_analyzer_spec.rb` — same
- `spec/lutaml/xsd/schema_classifier_spec.rb` — same
- `spec/lutaml/xsd/commands/pkg_command_spec.rb` — same

## Risks

- **Upstream coupling.** The upstream `lutaml-xml` gem may mutate the
  global internally. Removing our own writes is safe, but if the global is
  ever read by the upstream parser, that read will see stale data. The
  spec above covers this case; if it fails, the interop shim is required.
- **Multi-package workflows.** Some code paths merge schemas from
  multiple packages. Verify they still work end-to-end after the change.
