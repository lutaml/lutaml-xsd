# Replace `send()` and `respond_to?` patterns in lib/

## Problem
RngToXsdConverter uses `send()` for dynamic dispatch and `respond_to?` for
duck-typing. Per global rules: never use `send` to call methods, never use
`respond_to?` for type checking.

`spa/schema_serializer.rb` has 20+ `respond_to?` calls.
`validation/` has `respond_to?` calls.

## Solution

### 1. RngToXsdConverter: container.send(attr) → pattern_children(container)
Lines 68-71 and 921-924 iterate `pattern_types` and call `container.send(attr)`.
Replace with a single method that collects all pattern children.

Option A: Add a method to RNG models that returns all pattern children.
Option B: Use a lookup hash mapping attr names to getter methods.

Since RNG models are from an external gem, use Option B — a hash that maps
attribute names to explicit method calls via a case statement.

### 2. RngToXsdConverter: restriction.send(facet) → apply_facet(restriction, name, object)
Lines 523: `restriction.send(facet.first, facet.last)`. The `build_facet` method
returns `[setter_name, facet_object]`. Replace with a direct `apply_facet` method
that uses a case/when to call the correct setter.

### 3. RngToXsdConverter: respond_to?(:documentation)
Lines 1025, 1123: Check if RNG node has documentation. Since RNG element and
attribute models always have the `documentation` attribute (it may be nil),
just call it directly: `rng_elem.documentation` without the respond_to? guard.

### 4. RngToXsdConverter: respond_to?(:attr_name), respond_to?(:name), respond_to?(:value)
Line 1149-1152: `element_name` method uses respond_to? for duck-typing.
Replace with `is_a?` checks against known RNG types.

### 5. RngToXsdConverter: respond_to?(:min_occurs=)
Lines 1215, 1268: Check if result supports min/max occurrence. All XSD Element
and Sequence objects support these. Replace with `is_a?` checks.

### 6. RngToXsdConverter: respond_to?(:name) on element result
Line 1318: Replace with `is_a?(Lutaml::Xml::Schema::Xsd::Element)` check.

### 7. spa/schema_serializer.rb: 20+ respond_to? calls
Replace with `is_a?` checks against known XSD model types.

### 8. type_index.rb: respond_to? calls
Replace with `is_a?` checks.

### 9. validation/: respond_to? calls
Replace with `is_a?` checks.

## Files affected
- `lib/lutaml/xsd/rng_to_xsd_converter.rb` (4 send, 9 respond_to?)
- `lib/lutaml/xsd/spa/schema_serializer.rb` (20+ respond_to?)
- `lib/lutaml/xsd/schema_repository/type_index.rb` (2 respond_to?)
- `lib/lutaml/xsd/validation/validation_rule.rb` (1 respond_to?)

## Acceptance criteria
- [ ] Zero `send(` calls in `lib/` (except `public_send` which is acceptable)
- [ ] Zero `respond_to?` calls in `lib/`
- [ ] All type checks use `is_a?`
- [ ] `bundle exec rake` passes
