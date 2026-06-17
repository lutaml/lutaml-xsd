# Remove dead and misleading parameters

## Problem

`PackageLoader#load_package_with_filtering` accepts a `glob_mappings`
parameter that is never used:

```ruby
# lib/lutaml/xsd/package_loader.rb:27
def load_package_with_filtering(package_source, _glob_mappings)
  # ... never references _glob_mappings
end
```

The leading underscore signals "I know this is unused" — but the parameter
is in the public signature, so callers must still pass it (silently
wasting stack and reader attention). The class docstring even lists it
as a real parameter:

```
# @param _glob_mappings [Array<Hash>] Schema location mappings
```

This is dishonest. Either implement the filtering or drop the parameter.

## Solution

### Decide intent first

- **Was glob-mapping filtering intended but never wired up?** If so,
  implement it: the package source's schema paths get filtered by the
  glob mappings before being added to the repository.
- **Was it a vestigial signature?** If so, drop it.

Read git history (`git log -p -- lib/lutaml/xsd/package_loader.rb`) and
check the only caller (`SchemaRepository#load_package_with_filtering`) to
decide.

### Recommended path: drop it

Glob-mapping filtering is a property of *which files to keep*, not of
package loading. If a caller wants to filter, they should do so on the
result. The cleanest signature is:

```ruby
def load_package_with_filtering(package_source)
  # ... only loads package_source's schemas, no glob filter
end
```

The caller side (e.g., the `build` command) can apply the filter at its
own level:

```ruby
schemas = package_loader.load_package_with_filtering(pkg)
filtered = schema_location_filter.apply(schemas, glob_mappings)
```

### Audit for other dead parameters

While here, sweep the rest of the package-loading code path for similar
issues:

- `apply_namespace_remapping(schemas, _remappings)` (already flagged in
  TODO.clean/03) — drop the unused `_remappings` parameter along with the
  no-op.
- `Schema#from_yaml` parameter tuples — check for trailing-nil-arg
  signatures that pad a method.

## Files affected

- `lib/lutaml/xsd/package_loader.rb` (signature change)
- `lib/lutaml/xsd/schema_repository.rb` (caller of the renamed method)
- Any CLI command that calls it
- All specs

## Acceptance criteria

- [ ] `load_package_with_filtering` has no unused parameters
- [ ] All callers updated
- [ ] All specs pass
- [ ] `bundle exec rake` passes

## Specs required

- If filtering is implemented: a spec for the filter behaviour using
  real package-source fixtures.
- If filtering is dropped: the existing specs pass without change.

## Risks

- External consumers calling `PackageLoader#load_package_with_filtering`
  with two args will get `ArgumentError`. If the public API matters,
  keep a thin wrapper that accepts the old signature and ignores the
  extra arg, marked deprecated.
