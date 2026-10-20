# TODO.interop — bridges: RNG, JSON Schema, LutaML cross-model

Goal: no schema format is an island; every bridge lands in the LutaML
model-driven documentation pipeline.

## RelaxNG bridge (rng gem, ~/src/lutaml/rng — its own repo + PR flow)

- [ ] Migrate rng gem to Moxml: five files use Nokogiri directly
      (rnc_to_rng_converter, rnc_parser, test_suite_parser,
      schema_validator, external_ref_resolver); port to
      `Moxml::Context`, drop the direct `nokogiri` dependency,
      dev-Gemfile leptris (same pattern as lutaml-xsd PR #107)
- [ ] rng 0.3.8 baseline recalibration (also tracked in TODO.cleanup):
      re-baseline `rng_to_xsd_converter_spec` expectations against the
      fixed include processor; justify the `sections` element's
      disappearance from flattened top-level output before blessing it
- [ ] Round-trip tests: RNC → RNG → XSD → (parse) → `to_xml` stability
      on the metanorma-model-iso-grammars corpus
- [ ] Re-pin `rng ~> 0.3.8` in lutaml-xsd once the baseline is blessed

## JSON Schema bridge

- [ ] XSD → JSON Schema (draft 2020-12) exporter for the common core:
      element/complexType → object/properties, simple types + facets →
      type/format/pattern/enum constraints, substitution groups →
      `oneOf`
- [ ] Round-trip fidelity notes (what cannot map; documented loss table)
- [ ] SPA: "export JSON Schema" action per package

## LutaML cross-model (the differentiator)

- [ ] XSD → LutaML model export so the same corpus can render through the
      Express/UML documentation pipeline (classes from complexTypes,
      associations from element composition)
- [ ] Metanorma integration: schema package → documentation section
      generation with the SPA data (close the loop with the ecosystem)

## Adjacent (evaluate, don't commit)

- [ ] ISO Schematron support as a rule-engine plugin (rule_registry
      pattern fits; assess demand before building)
