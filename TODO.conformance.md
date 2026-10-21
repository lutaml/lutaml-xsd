# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
test-suite categories, build the harness, publish the pass-rate, grow it.

## Baseline (2026-10-21, 19 cases / 39 checks, after gap rules)

Corpus: 19 case classes under `spec/conformance/cases/`, modelled on the
W3C XML Schema Test Suite category taxonomy — self-authored because the
canonical 2007 suite distribution is no longer served from w3.org (owner
can vendor a tarball later; provenance README goes with it).

| mode | pass-rate |
|---|---|
| engine (Moxml::XSD tier-1, moxml 0.5.149) | 33/39 (84.6%) |
| pipeline (ValidationJob + wired rule engine) | 37/39 (94.9%) |

The pipeline outperforms the engine by four checks: the root-declaration
check catches a wrong-namespace root that engine root-matching silently
skips; the identity-constraints rule catches duplicate keys the engine
lacks; xsi:nil handling rejects non-nillable nils; strict wildcards reject
undeclared elements. Zero false positives retained.

Gap register (each failure is a tracked gap, not a test bug):

- `identity-keykeyref` — dangling keyref not detected: implemented in
  `IdentityConstraintsRule`, but activation needs lutaml-model to map the
  `refer` attribute on `xs:keyref` (upstream fix in flight)
- `xsi-type` — a VALID instance derived via `xsi:type` is rejected by the
  tier-1 engine (false positive, structural: engine scope is stricter than
  derivation); the unknown-type half passes in pipeline mode
- engine-only: `namespaces-qualified` wrong-namespace root accepted
  (EngineContext root-matching skips it; pipeline's root check catches it)

History: 2026-10-20 baseline 20/25 (80.0%) with pipeline == engine
(empty `RuleRegistry`, mismatched rule signatures); 2026-10-21 wiring
baseline 34/39 (87.2%); gap rules lifted the pipeline to 37/39 (94.9%).

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

- [x] Identity constraints: `key`, `keyref`, `unique` —
      `IdentityConstraintsRule` (selector/field XPath evaluation,
      duplicate detection, keyref resolution); dangling-keyref activation
      waits on lutaml-model `refer` mapping
- [x] Wildcards: `any` namespace constraints (##any/##other/##local/
      ##targetNamespace/lists) + `processContents` strict declaration
      checking in the content-model walk; `anyAttribute` still open
- [x] `xsi:nil` (nillable + empty-content checks) and `xsi:type`
      resolution (unknown-type rejection; content walk follows the
      override); valid-derived acceptance needs engine-scope rework
- [ ] Particle checking: UPA detection — DEFERRED (engine covers the
      tier-1 subset; UPA is schema-side checking)
- [ ] XSD 1.1 constructs behind a version flag — DEFERRED: 1.1 strategy
      decision needed (see TODO.som.md)
