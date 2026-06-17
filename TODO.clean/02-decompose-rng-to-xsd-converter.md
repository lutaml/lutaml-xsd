# Decompose RngToXsdConverter (1411-line monolith) into focused collaborators

## Problem

`lib/lutaml/xsd/rng_to_xsd_converter.rb` is **1411 lines** in a single class
with ~40 private methods covering every phase of RNG→XSD conversion:
includes/grammar walking, define classification, particle conversion
(element/choice/sequence/interleave/optional/zeroOrMore/oneOrMore), complex
type assembly, simple type and facet building, attribute and attribute-group
production, name promotion, collision detection, and schema assembly.

It violates SRP, is impossible to test in isolation, and every bug fix risks
collateral damage. TODO.refactor/08 was marked complete but only fixed a
single bug — no decomposition was performed.

## Solution

Collapse `RngToXsdConverter` into a thin orchestrator (~150 lines) that wires
collaborators together. Each collaborator owns one phase of the conversion.

### Extracted collaborators

1. **`RngToXsd::DefineConverter`** — converts a single `Rng::Define` into a
   `{ simple_type:, complex_type:, group:, element: }` result. Owns the
   classification dispatch (pure data → SimpleType, pure attributes →
   AttributeGroup, particles → ComplexType, single-element → promotion).

2. **`RngToXsd::ParticleConverter`** — converts RNG particle patterns into XSD
   particles. Owns `convert_pattern`, `convert_choice`, `convert_interleave`,
   `convert_occurrence`, `convert_ref`, and the `Rng::Element` handler. Does
   not touch types.

3. **`RngToXsd::SimpleTypeBuilder`** — builds `SimpleType` from RNG data
   patterns: `build_from_data`, `build_from_value`, `build_from_list`,
   `build_enum`, `build_union`, `build_from_patterns`.

4. **`RngToXsd::ComplexTypeBuilder`** — builds `ComplexType` from particles +
   attributes: `build_complex_type`, `assign_content_model`,
   `classify_particles_and_attr_refs`, mixed-content detection.

5. **`RngToXsd::FacetBuilder`** — registry-based facet construction from RNG
   params. Replaces the `case` dispatch in `build_facet` with a hash of
   `facet_name => builder` pairs (open/closed: new facets are added by
   registering a builder, not editing the case).

6. **`RngToXsd::AttributeBuilder`** — converts `Rng::Attribute` and
   `Rng::AttributeGroup` patterns into XSD attribute artifacts.

7. **`RngToXsd::NamingService`** — owns name promotion, collision detection,
   unique-name resolution. Pure functions: given a desired name and the set of
   already-promoted names, return the final name (or nil if collision blocks
   promotion).

### Orchestrator shape

```ruby
class RngToXsdConverter
  def initialize(grammar, file_path: nil)
    @grammar = grammar
    @file_path = file_path
    @schema = Lutaml::Xml::Schema::Xsd::Schema.new(element_form_default: "qualified")

    @naming         = RngToXsd::NamingService.new
    @facets         = RngToXsd::FacetBuilder.new
    @simple_types   = RngToXsd::SimpleTypeBuilder.new(@facets)
    @particles      = RngToXsd::ParticleConverter.new(self)
    @attributes     = RngToXsd::AttributeBuilder.new
    @complex_types  = RngToXsd::ComplexTypeBuilder.new(@particles, @attributes)
    @defines        = RngToXsd::DefineConverter.new(self, @simple_types,
                                                     @complex_types, @attributes,
                                                     @naming)
  end

  def convert
    process_includes
    @defines.convert_all(@grammar.defines)
    process_grammar_elements
    @schema
  end
end
```

The orchestrator exposes a narrow delegation surface (e.g., `convert_define`,
`ref_resolves_to_element?`) that collaborators need. No collaborator reaches
into another collaborator's internals.

## Files affected

- NEW: `lib/lutaml/xsd/rng_to_xsd.rb` (parent namespace file with autoloads)
- NEW: `lib/lutaml/xsd/rng_to_xsd/define_converter.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/particle_converter.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/simple_type_builder.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/complex_type_builder.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/facet_builder.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/attribute_builder.rb`
- NEW: `lib/lutaml/xsd/rng_to_xsd/naming_service.rb`
- `lib/lutaml/xsd/rng_to_xsd_converter.rb` (kept as a thin alias /
  backwards-compat shim that constructs the orchestrator — DELETE after one
  release if no external consumers)
- `lib/lutaml/xsd.rb` (autoload entries)

## Acceptance criteria

- [ ] Orchestrator under 200 lines
- [ ] Each collaborator under 300 lines
- [ ] All existing RNG→XSD conversion specs pass unchanged
- [ ] New collaborators have their own focused unit specs
- [ ] No `rescue NoMethodError` anywhere in `lib/lutaml/xsd/rng_to_xsd/`
- [ ] No `respond_to?` anywhere in `lib/lutaml/xsd/rng_to_xsd/`
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- `spec/lutaml/xsd/rng_to_xsd/naming_service_spec.rb` — collision detection,
  promotion, unique-name resolution as pure-function tests
- `spec/lutaml/xsd/rng_to_xsd/facet_builder_spec.rb` — registry-based facet
  dispatch (one example per registered facet, plus unknown-facet error)
- `spec/lutaml/xsd/rng_to_xsd/simple_type_builder_spec.rb` — each `build_*`
  entry point with minimal RNG input
- `spec/lutaml/xsd/rng_to_xsd/particle_converter_spec.rb` — each particle kind
  (choice, interleave, optional, zeroOrMore, oneOrMore, ref)
- `spec/lutaml/xsd/rng_to_xsd/complex_type_builder_spec.rb` — content-model
  assignment, mixed-content detection, attribute attachment
- `spec/lutaml/xsd/rng_to_xsd/define_converter_spec.rb` — each classification
  branch (pure data, pure attributes, particles, single-element promotion)
- Existing `spec/lutaml/xsd/rng_to_xsd_converter_spec.rb` continues to pass as
  an integration spec

## Risks

- The current monolith has subtle inter-method dependencies via instance
  state. As each collaborator is extracted, pass state explicitly (constructor
  args or method args), never via shared ivars.
- Test fixtures (`spec/fixtures/converter_test.rnc`) may need expanding to
  exercise edge cases uncovered by focused unit specs.
- The existing `convert_define` memoization cache is on the orchestrator;
  decide whether it moves into `DefineConverter` or stays on the orchestrator
  (recommend: stays on orchestrator, collaborators stay stateless).
