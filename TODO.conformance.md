# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
Test Suite subset, build the harness, publish the pass-rate, grow it.

## Harness

- [ ] Vendor a W3C XSD 1.0 test-suite subset under `spec/conformance/`
      (xsdts 2007+ Microsoft/IBM/Sun collections; keep it lean —
      representative classes, not the whole corpus; respect upstream
      licenses, record provenance in a README)
- [ ] `Lutaml::Xsd::Conformance::Runner`: iterate suite cases →
      `Validator#validate` (engine + rule stack) → classify
      valid/invalid/unsupported; emit a pass-rate report
      (`conformance_report.md` + JSON)
- [ ] Wire `rake conformance` to run it; record baseline pass-rate in this
      file once measured
- [ ] Same harness against the moxml/leptris engine alone (isolate engine
      tier-1 gaps from Ruby rule gaps in the report)

## Rule-engine depth (in dependency order)

- [ ] Particle checking: full sequence/choice/all/mixed content with
      occurrence semantics; UPA (Unique Particle Attribution) detection
- [ ] Substitution groups: head/expansion/closure, `xsi:type` derivation
      checks (valid extensions/restrictions per complex type derivation)
- [ ] `xsi:nil`, `xsi:schemaLocation`, element defaults and fixed values
      (default-value injection semantics)
- [ ] Identity constraints: `key`, `keyref`, `unique` — selector/field
      XPath evaluation (moxml XPath engine is available and fast)
- [ ] Wildcards: `any`/`anyAttribute` namespace + processContents modes,
      intersection/union semantics
- [ ] Type unification checks; abstract elements/types enforcement
- [ ] Wire the currently-unwired `validation/base_types/*` and
      `validation/facets/*` registries into the rule engine paths where
      the engine cannot answer (they exist but nothing calls them)
- [ ] XSD 1.1 constructs behind a version flag: assertions
      (`xs:assert`/`xs:assertion`), conditional types (`xs:alternative`),
      `openContent`, wildcard inherit

## Deliverable

- [ ] `docs/CONFORMANCE.adoc`: methodology, current pass-rate, known-gap
      register, comparison table vs engine-only mode
