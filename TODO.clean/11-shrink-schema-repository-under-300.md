# Shrink SchemaRepository to under 300 lines (post-clean-01 + post-clean-03)

## Problem

After TODO.refactor/07, `SchemaRepository` is **643 lines** — well above
the 300-line target set in that TODO. Most of the bulk is parse logic
(should move to `SchemaParser` per TODO.clean/01) and duplicated
forwarder methods (should be deleted per TODO.clean/03).

This TODO is **sequenced after** TODO.clean/01 and TODO.clean/03. Do not
attempt it first — it's the cleanup that confirms the prior two were done
correctly.

## Solution

After TODO.clean/01 and TODO.clean/03 are merged, re-measure
`SchemaRepository`:

```bash
wc -l lib/lutaml/xsd/schema_repository.rb
```

Expected: under 300 lines. If not, identify what remains and decide:

### Possible remaining bulk

1. **Class methods** (`from_package`, `from_yaml_file`, `from_file`,
   `from_file_cached`, `validate_package`, `resolve_relative_paths`,
   `check_circular_imports`, `build_dependency_graph`,
   `has_circular_dependency?`).
   - `from_*` factory methods → move to `SchemaRepository::Loader` or
     a freestanding `SchemaRepositoryLoader` module.
   - Dependency-graph methods → move to `DependencyGrapher` (already
     exists, just consolidate).
   - `validate_package` → move to `PackageValidator`.

2. **State plumbing** (`copy_state_from`, accessors).
   - These belong on the repository; keep them.

3. **Package loading entry points** (`load_base_packages*`,
   `load_package_with_filtering`).
   - These should already be gone after TODO.clean/01.

### Final shape of SchemaRepository

```ruby
class SchemaRepository
  FULL_KNOWN_PREFIXES.freeze  # constants

  attr_reader :parsed_schemas, :type_index, :namespace_registry,
              :resolved, :validated, :lazy_load, :verbose,
              :parser, :loader, :query, :exporter

  def initialize(**attrs)
    # state setup
    # service instantiation (memoized)
  end

  def add_schema_file(path, schema)
    @parsed_schemas.set(path, schema)
  end

  def all_schemas = @parsed_schemas.all
  def schemas_count = @parsed_schemas.size

  def copy_state_from(source)
    # ...
  end

  # Delegators to services (or remove per TODO.clean/05)
  def find_type(...) = query.find_type(...)
  # ...
end
```

Target: under 200 lines of pure coordination, no parsing, no formatting,
no statistics.

## Files affected

- `lib/lutaml/xsd/schema_repository.rb` (final shrink)
- NEW (maybe): `lib/lutaml/xsd/schema_repository/loader.rb` (factory
  methods as a module)
- `lib/lutaml/xsd/dependency_grapher.rb` (absorb graph logic)
- `lib/lutaml/xsd.rb` (autoload entries)

## Acceptance criteria

- [ ] `wc -l lib/lutaml/xsd/schema_repository.rb` shows ≤ 300 lines
- [ ] No parsing logic in `SchemaRepository`
- [ ] No statistics logic in `SchemaRepository`
- [ ] No formatting logic in `SchemaRepository`
- [ ] All public API preserved (backward compatible)
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- Existing `spec/lutaml/xsd/schema_repository_spec.rb` continues to pass
  unchanged (this is the proof that the public API is preserved).
- Add focused specs for any new classes/modules that absorb the moved
  logic (e.g., `DependencyGrapher` gets its own spec file).

## Risks

- Moving class methods (`from_package`, etc.) is breaking if external
  consumers call `SchemaRepository.from_package` directly. Provide
  deprecation aliases for one release.
- The dependency-graph methods may have subtle interactions with the
  repository's state — verify by running the full integration spec
  after the move.
