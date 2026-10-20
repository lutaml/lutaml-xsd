# TODO.interop — bridges: RNG, JSON Schema, LutaML cross-model

Goal: no schema format is an island; every bridge lands in the LutaML
model-driven documentation pipeline.

Status 2026-10-20: RNG bridge migrated to Moxml; JSON Schema exporter
delivered; remaining items deferred with reasons below.

## RelaxNG bridge (rng gem, ~/src/lutaml/rng — its own repo + PR flow)

- [x] Migrate rng gem to Moxml (rng PR #35): five Nokogiri files ported
      (rnc_to_rng_converter, rnc_parser, test_suite_parser,
      schema_validator, external_ref_resolver); `nokogiri` removed from
      the runtime dependencies, `moxml` added; dev Gemfile runs leptris
- [x] Round-trip coverage: the rng suite's RNC ↔ RNG round-trip and
      spec-test suites pass on the Moxml converter (1056 examples; two
      environmental timing guards were widened to pathological-regression
      budgets — they also failed on pre-migration main on loaded machines)
- [ ] rng 0.3.8+ baseline recalibration — DEFERRED, release-gated on the
      rng release containing the include fixes + Moxml migration (version
      is the owner's to state); numbers precomputed (complex types 170,
      simple types 13, elements 203, groups 237, attribute_groups 44;
      sections: 7 choices / 1 group / 1 element)
- [ ] Re-pin `rng` in lutaml-xsd once that release exists — DEFERRED with
      the same gate (lands with the recalibration commit)

## JSON Schema bridge

- [x] XSD → JSON Schema (draft 2020-12) exporter:
      `Lutaml::Xsd::JsonSchemaExporter` — objects from complexTypes,
      properties/required from sequences and attributes, arrays from
      repeated particles, enum/pattern/length/range facets, builtin type
      mapping, `const` for fixed values, nillable → null union
- [x] Loss table documented in docs/JSON_SCHEMA.adoc (XSD regex dialect,
      identity constraints, substitution groups, derivation flattening,
      wildcards, defaults, mixed content, XSD 1.1)
- [ ] SPA "export JSON Schema" action per package — DEFERRED: needs the
      SPA work in TODO.docs-spa.md

## LutaML cross-model (the differentiator)

- [ ] XSD → LutaML model export — DEFERRED: there is no cross-model
      contract in this repo yet (LutaML class/association export needs a
      design note agreed with the lutaml-model owners); the exporter
      here is the template for that work
- [ ] Metanorma integration for schema-package documentation — DEFERRED:
      depends on the SPA data contract being frozen

## Adjacent (evaluate, don't commit)

- [ ] ISO Schematron rule-engine plugin — DEFERRED: evaluate demand;
      the rule_registry pattern fits, and the conformance harness gives
      the measurement hook when it is taken up
