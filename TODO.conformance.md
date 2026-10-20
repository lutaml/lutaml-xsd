# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
test-suite categories, build the harness, publish the pass-rate, grow it.

## Baseline (2026-10-20)

Corpus: 12 case classes under `spec/conformance/cases/` (25 checks),
modelled on the W3C XML Schema Test Suite category taxonomy — self-authored
because the canonical 2007 suite distribution is no longer served from
w3.org (owner can vendor a tarball later; provenance README goes with it).

| mode | pass-rate |
|---|---|
| engine (Moxml::XSD tier-1 on leptris) | 20/25 (80.0%) |
| pipeline (ValidationJob, default registry) | 20/25 (80.0%) |

Gap register (each failure is a tracked gap, not a test bug):

- `identity-keykeyref` — dangling keyref not detected (engine tier-1 gap;
  rule-engine identity rules unwired)
- `wildcards-any` — `xs:any processContents="strict"` is not enforced:
  an undeclared element is accepted (tier-1 engine gap)
- `xsi-nil` — `xsi:nil` on a non-nillable element accepted
- `xsi-type` — derived `xsi:type` rejected AND unknown `xsi:type`
  accepted
- Pipeline == engine because the rule engine's registries are still
  unwired in production (`RuleRegistry` is registered empty and rule
  `validate` signatures don't share the engine's calling convention) —
  wiring it is the headline gap; every rule-engine gap below is
  subsumed by it.

## Harness

- [x] Conformance corpus under `spec/conformance/cases/` (directory
      convention: schema.xsd + valid-*.xml + invalid-*.xml)
- [x] `Lutaml::Xsd::Conformance::Runner`: discovery, per-mode
      classification, pass-rate report (engine + production pipeline)
- [x] `rake conformance` → prints report and writes
      `tmp/conformance_report.md`
- [x] Deliverable doc: `docs/CONFORMANCE.adoc` (methodology, baseline,
      gap register pointer, how to add cases)
- [ ] Vendor a real W3C XSD TS subset — DEFERRED: upstream distribution
      URLs are dead as of 2026-10-20; the owner supplies the corpus
      tarball and a provenance/license README is added with it
- [ ] Harness run against the rule engine with registries explicitly
      populated — DEFERRED: subsumed by the rule-registry wiring design
      below

## Rule-engine wiring (the headline gap)

- [ ] Design note: rule dispatch contract (which rule validates which
      node/schema pair), rule `validate` signature unification, and the
      registry population path — DEFERRED: needs an owner-reviewed design
      note; today `RuleRegistry` is constructed empty in production and
      the rule classes use per-rule signatures that the `RuleEngine`
      calling convention does not match
- [ ] Wire `validation/base_types/*` and `validation/facets/*` into the
      rule paths where the engine cannot answer — DEFERRED (same design)

## Rule-engine depth (after wiring)

- [ ] Particle checking: full sequence/choice/all/mixed content with
      occurrence semantics; UPA detection — DEFERRED (after wiring);
      engine covers the tier-1 subset measured above
- [ ] Substitution groups: head/expansion/closure, `xsi:type` derivation
      checks — DEFERRED (after wiring; engine gaps are in the register)
- [ ] `xsi:nil`, `xsi:schemaLocation`, defaults and fixed values —
      DEFERRED (after wiring; engine gaps in the register)
- [ ] Identity constraints: `key`, `keyref`, `unique` selector/field
      evaluation — DEFERRED (after wiring; engine gap in the register)
- [ ] Wildcards: `any`/`anyAttribute` namespace + processContents modes —
      DEFERRED (after wiring; the strict-mode gap is in the register)
- [ ] Type unification checks; abstract elements/types enforcement —
      DEFERRED (after wiring)
- [ ] XSD 1.1 constructs behind a version flag — DEFERRED: 1.1 strategy
      decision needed (see TODO.som.md)
