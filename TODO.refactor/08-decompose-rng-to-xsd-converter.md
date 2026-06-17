# Decompose RngToXsdConverter (1394-line monolith) into focused converter classes

## Problem
RngToXsdConverter is a single 1394-line class with ~40 private methods covering
every aspect of RNG→XSD conversion. It violates SRP and is hard to test in
isolation.

## Solution
Extract converter phases into focused classes, keeping RngToXsdConverter as
a coordinator that delegates to phase-specific converters.

### Extracted classes:

1. **DefineConverter** — converts a single `Rng::Define` to XSD artifacts
   - `convert(name)` → `{ simple_type:, complex_type:, group:, element: }`
   - Owns the classification logic (pure data, pure attributes, particles)
   - Owns element promotion and collision detection

2. **ParticleConverter** — converts RNG particle patterns to XSD particles
   - `convert_choice`, `convert_group`, `convert_interleave`
   - `convert_occurrence`, `convert_ref`
   - Extracted from the `convert_pattern` dispatch and its handlers

3. **SimpleTypeBuilder** — builds XSD SimpleType from RNG data patterns
   - `build_from_data`, `build_from_value`, `build_from_list`
   - `build_enum`, `build_union`, `build_from_patterns`

4. **ComplexTypeBuilder** — builds XSD ComplexType from particles + attributes
   - `build_complex_type`, `build_attribute_group`
   - `assign_content_model`, `classify_particles_and_attr_refs`

5. **FacetBuilder** — builds XSD facets from RNG params
   - Replaces `build_facet` with a registry-based pattern

### RngToXsdConverter becomes coordinator:
```ruby
class RngToXsdConverter
  def initialize(grammar, file_path: nil)
    @simple_type_builder = SimpleTypeBuilder.new(self)
    @complex_type_builder = ComplexTypeBuilder.new(self)
    @particle_converter = ParticleConverter.new(self)
    @define_converter = DefineConverter.new(self)
    @facet_builder = FacetBuilder.new(self)
    # ...
  end

  def convert
    # Phase 0: includes
    # Phase 1: @define_converter.convert_all
    # Phase 2: start/grammar elements
  end
end
```

## Files affected
- NEW: `lib/lutaml/xsd/converter/define_converter.rb`
- NEW: `lib/lutaml/xsd/converter/particle_converter.rb`
- NEW: `lib/lutaml/xsd/converter/simple_type_builder.rb`
- NEW: `lib/lutaml/xsd/converter/complex_type_builder.rb`
- NEW: `lib/lutaml/xsd/converter/facet_builder.rb`
- NEW: `lib/lutaml/xsd/converter.rb` (parent namespace for autoload)
- `lib/lutaml/xsd/rng_to_xsd_converter.rb` (slimmed to coordinator)
- All converter specs

## Acceptance criteria
- [ ] RngToXsdConverter under 200 lines (coordinator)
- [ ] Each converter class under 300 lines
- [ ] All converter specs pass
- [ ] `bundle exec rake` passes
