# Replace all `double()` in specs with real model instances

## Problem
Specs use `double()` to create mock objects, which bypass real type checking.
Per global rules: never use `double()` in specs. Use real model instances or
Struct for plain data.

## Affected specs
- `spec/lutaml/xsd/xsd_spec_validator_spec.rb` — 20+ double() calls
- `spec/lutaml/xsd/type_searcher_spec.rb` — 1 double()
- `spec/lutaml/xsd/package_conflict_detector_spec.rb` — stubs instance_variable_get

## Solution

### 1. xsd_spec_validator_spec.rb
Replace `double(target_namespace: ...)` with real Schema objects or Structs.
Replace `double(name: "MyType")` with real ComplexType/SimpleType objects.
Replace `instance_double(SchemaRepository)` with real SchemaRepository.

### 2. type_searcher_spec.rb
Replace `double("definition")` with a real type definition object.

### 3. package_conflict_detector_spec.rb
Replace `allow(mock_repo).to receive(:instance_variable_get)` with a real
SchemaRepository that has the expected state.

## Files affected
- `spec/lutaml/xsd/xsd_spec_validator_spec.rb`
- `spec/lutaml/xsd/type_searcher_spec.rb`
- `spec/lutaml/xsd/package_conflict_detector_spec.rb`

## Acceptance criteria
- [ ] Zero `double(` calls in spec/
- [ ] Zero `instance_double(` calls in spec/
- [ ] All specs use real model instances or Struct
- [ ] `bundle exec rake` passes
