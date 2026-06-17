# Fix broken RNG-to-XSD converter specs

## Problem
10 of 21 tests in `rng_to_xsd_converter_spec.rb` fail with `Parslet::ParseFailed`.
The `bsi.rnc` fixture uses `include` with override blocks that the `rng` gem
(v0.3.5) cannot parse.

The test expectations were changed (complex_type count from 20→5, etc.) but
never verified to pass.

## Solution

### 1. Create a self-contained RNC fixture
Create `spec/fixtures/converter_test.rnc` that exercises all converter features
without relying on `include` directives:
- Named patterns (defines) with elements, attributes, data
- Complex types with mixed content
- Simple types with enumerations
- Groups with choices and interleave
- Attribute groups
- Element references
- Collision detection

### 2. Rewrite the main describe block
Replace the `bsi.rnc` fixture with the new self-contained one.
Update test expectations to match the new fixture's output.

### 3. Improve spec quality
- Replace count-based assertions with structural assertions
- Test specific named types/elements/groups rather than just counts
- Test XSD validity of output

## Files affected
- NEW: `spec/fixtures/converter_test.rnc`
- `spec/lutaml/xsd/rng_to_xsd_converter_spec.rb`

## Acceptance criteria
- [ ] All 21 tests pass (or more if new tests added)
- [ ] No `Parslet::ParseFailed` errors
- [ ] Tests verify structural properties, not just counts
- [ ] `bundle exec rspec spec/lutaml/xsd/rng_to_xsd_converter_spec.rb` passes
