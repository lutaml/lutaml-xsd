# Add public accessors to SchemaRepository, eliminate all instance_variable_get/set

## Problem
49 occurrences of `instance_variable_get`/`instance_variable_set` across `lib/`.
External classes (NamespaceRemapper, CoverageAnalyzer, TypeHierarchyAnalyzer,
TypeSearcher, DependencyGrapher, PackageBuilder, PackageValidator,
SchemaRepositoryPackage, CLI commands) reach into SchemaRepository's private
state instead of using a public API.

This violates encapsulation and makes the codebase fragile — any rename or
restructure of internal state breaks consumers silently.

## Solution

### 1. Add public read accessors to SchemaRepository
```ruby
attr_reader :parsed_schemas, :type_index, :namespace_registry
attr_reader :resolved, :validated, :lazy_load, :verbose
```

### 2. Add a `copy_state_to` method for NamespaceRemapper
Replace the ivar-surgery pattern with a proper method:
```ruby
def copy_state_to(target)
  target.parsed_schemas = @parsed_schemas.dup
  # etc.
end
```

### 3. Update all consumers
- `NamespaceRemapper` — use `repository.parsed_schemas` etc.
- `CoverageAnalyzer` — use `repository.type_index`
- `TypeHierarchyAnalyzer` — use `repository.type_index`
- `TypeSearcher` — use `repository.type_index`
- `DependencyGrapher` — use `repository.type_index`
- `PackageBuilder` — use `repository.parsed_schemas`
- `PackageValidator` — use `repository.parsed_schemas`
- `SchemaRepositoryPackage` — use public API
- `PackageConflictDetector` — use public API
- CLI commands — use public API
- `SchemaRepository.from_yaml_file` — use setter methods instead of ivar_set
- `SchemaRepository.from_file` — use public API

### 4. Also fix SchemaRepositoryMetadata
It uses `instance_variable_get`/`instance_variable_set` on itself — use proper accessors.

### 5. Also fix SerializedSchema
Uses `instance_variable_set` on Schema objects — use proper setters.

## Files affected
- `lib/lutaml/xsd/schema_repository.rb`
- `lib/lutaml/xsd/namespace_remapper.rb`
- `lib/lutaml/xsd/coverage_analyzer.rb`
- `lib/lutaml/xsd/type_hierarchy_analyzer.rb`
- `lib/lutaml/xsd/type_searcher.rb`
- `lib/lutaml/xsd/dependency_grapher.rb`
- `lib/lutaml/xsd/package_builder.rb`
- `lib/lutaml/xsd/package_validator.rb`
- `lib/lutaml/xsd/schema_repository_package.rb`
- `lib/lutaml/xsd/package_conflict_detector.rb`
- `lib/lutaml/xsd/schema_repository_metadata.rb`
- `lib/lutaml/xsd/serialized_schema.rb`
- `lib/lutaml/xsd/commands/element_command.rb`
- `lib/lutaml/xsd/commands/type_command.rb`
- `lib/lutaml/xsd/commands/search_command.rb`

## Acceptance criteria
- [ ] Zero `instance_variable_get`/`instance_variable_set` in `lib/`
- [ ] All consumers use public accessor methods
- [ ] `bundle exec rake` passes
