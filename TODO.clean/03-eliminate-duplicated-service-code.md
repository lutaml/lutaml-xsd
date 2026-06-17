# Eliminate duplicated service code across SchemaRepository and PackageLoader

## Problem

The service-object extraction left duplicates on both sides of the boundary:

| Method | SchemaRepository | PackageLoader | Status |
|---|---|---|---|
| `supports_conflict_detection?` | schema_repository.rb:323 | package_loader.rb:69 | both implementations |
| `normalize_base_packages_to_configs` | schema_repository.rb:311 (forwarder) | package_loader.rb:51 | forwarder + real |
| `apply_namespace_remapping_to_schemas` | schema_repository.rb:330 (no-op) | package_loader.rb:179 (no-op) | two no-ops |

Both `apply_namespace_remapping*` are no-ops — the feature was scaffolded but
never implemented. The duplicates violate MECE: the same question has two
owners.

## Solution

For each pair, decide the single owner and delete the other.

### 1. `supports_conflict_detection?`

Owner: **`PackageLoader`** (the loader is what does conflict detection).

- Delete `SchemaRepository#supports_conflict_detection?`.
- Update callers to ask `repository.loader.supports_conflict_detection?` (or
  inline the check at the one call site that uses it).

### 2. `normalize_base_packages_to_configs`

Owner: **`PackageLoader`**.

- Delete `SchemaRepository#normalize_base_packages_to_configs` (the forwarder).
- Update callers to use `repository.loader.normalize_base_packages_to_configs`
  directly.

### 3. `apply_namespace_remapping*` (no-op scaffolding)

Two no-ops means the feature was planned but never built. Decide:

- **Option A (recommended):** Delete both no-ops. If/when namespace remapping
  is needed, build it fresh in `PackageLoader` with a real implementation and a
  real spec. Do not carry dead scaffolding.
- **Option B:** Implement it now (out of scope for this TODO; spawn a
  separate TODO if pursued).

Choose Option A unless there is a concrete near-term need.

## Files affected

- `lib/lutaml/xsd/schema_repository.rb` (delete 3 methods, ~20 lines)
- `lib/lutaml/xsd/package_loader.rb` (delete `apply_namespace_remapping` if
  Option A)
- `lib/lutaml/xsd/cli.rb`, `lib/lutaml/xsd/commands/*.rb` (update callers)
- Any spec that exercises these methods

## Acceptance criteria

- [ ] Each method exists in exactly one place
- [ ] Zero no-op stubs for `apply_namespace_remapping*`
- [ ] No forwarder methods on `SchemaRepository`
- [ ] All call sites updated
- [ ] `bundle exec rake` passes

## Specs required

- `spec/lutaml/xsd/package_loader_spec.rb` — assert
  `supports_conflict_detection?` and `normalize_base_packages_to_configs`
  behave correctly (real configs, real hashes, real strings)
- If `apply_namespace_remapping` is implemented: focused spec for it

## Risks

- None significant — pure deletion + caller update. The methods are public, so
  search the codebase for all callers before deleting.
