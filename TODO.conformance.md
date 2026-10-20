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
| pipeline (ValidationJob + wired rule engine) | 20/25 (80.0%) |

Gap register (each failure is a tracked gap, not a test bug):

- `identity-keykeyref` — dangling keyref not detected (engine tier-1 gap;
  no identity-constraint rule exists yet)
- `wildcards-any` — `xs:any processContents="strict"` is not enforced:
  an undeclared element is accepted (engine tier-1 gap; no wildcard rule)
- `xsi-nil` — `xsi:nil` on a non-nillable element accepted (no rule)
- `xsi-type` — derived `xsi:type` rejected AND unknown `xsi:type`
  accepted (engine tier-1 gap + no dynamic-type resolution)
- Substitution groups now PASS in pipeline mode (the rule engine's
  content-model and occurrence checks are substitution-aware); the engine
  handles them too.

History: before the rule-engine wiring (below), pipeline mode was
identical to engine mode because `RuleRegistry` was empty and rule
signatures did not match the engine's calling convention.

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

## Rule-engine wiring (done 2026-10-21)

- [x] Design note: `docs/superpowers/specs/2026-10-21-rule-engine-wiring-design.md`
- [x] Element-scoped dispatch contract: `ValidationRule#schema_argument`
      (defaults to the resolved declaration; occurrence rule returns the
      content-model particle) and `runs_without_schema?`
- [x] `SchemaDefinitionResolver`: top-level + inline element index with
      namespace matching and named-type resolution
- [x] `RuleRegistry.default(config)`: production rule set, feature-gated;
      shared by `Validator` and the conformance harness
- [x] Rules resolve `type="prefix:Name"` references via the repository
- [x] Substitution groups: content-model and occurrence matching are
      substitution-aware (substitution case now passes in pipeline mode)
- [x] Facet-collection handling fixed (empty arrays were treated as
      present facets; `XmlAttribute` namespace ported to `.uri`)
- [x] Integration specs prove rule findings fire with the engine phase
      disabled (ordering, missing content) and valid instances stay clean

## Rule-engine depth (remaining)

- [ ] Identity constraints: `key`, `keyref`, `unique` — DEFERRED: needs a
      new rule (selector/field XPath evaluation); engine lacks them
- [ ] Wildcards: `any`/`anyAttribute` namespace + processContents modes —
      DEFERRED: needs a wildcard rule; strict-mode gap in the register
- [ ] `xsi:nil` and dynamic `xsi:type` resolution — DEFERRED: needs
      attribute-aware rules plus derivation closure in the resolver
- [ ] Particle checking: UPA detection — DEFERRED (engine covers the
      tier-1 subset; UPA is schema-side checking)
- [ ] XSD 1.1 constructs behind a version flag — DEFERRED: 1.1 strategy
      decision needed (see TODO.som.md)
