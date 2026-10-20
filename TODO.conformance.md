# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
Test Suite subset, build the harness, publish the pass-rate, grow it.

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
- `wildcards-any` — FALSE POSITIVE: engine rejects a valid `xs:any
  namespace="##other"` document (upstream tier-1 strictness bug; write up
  for moxml/leptris owners)
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
- [ ] Vendor a real W3C XSD TS subset when the owner supplies the corpus
      (upstream distribution URLs are dead as of 2026-10-20; record
      provenance and license in spec/conformance/README.md)
- [ ] Same harness against the rule engine with registries explicitly
      populated (isolate rule gaps from the empty-registry default)

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
