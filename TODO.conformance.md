# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
test-suite categories, build the harness, publish the pass-rate, grow it.

## Baseline (2026-10-23, 22 cases / 47 checks, full pass)

Corpus: 22 case classes under `spec/conformance/cases/`, modelled on the
W3C XML Schema Test Suite category taxonomy — self-authored because the
canonical 2007 suite distribution is no longer served from w3.org (owner
can vendor a tarball later; provenance README goes with it).

Current (2026-10-25): 23 cases / 49 checks —

| mode | pass-rate |
|---|---|
| engine (Moxml::XSD tier-1, leptris 1.9.380.2) | 39/44 (88.6%, 2 cases unsupported) |
| pipeline (ValidationJob + wired rule engine) | 49/49 (100.0%) |

The pipeline now passes every check in the corpus (locked in by a
runner spec). The engine trails on the four documented below. The
engine's former xsi:type derivation FALSE POSITIVE is fixed in
leptris 1.9.380.2 (moxml#433 closed).

History: 2026-10-20 baseline 20/25 (80.0%) with pipeline == engine
(empty `RuleRegistry`, mismatched rule signatures); 2026-10-21 wiring
baseline 34/39 (87.2%); gap rules 37/39 (94.9%); anyAttribute 40/42
(95.2%); keyref activation via lutaml-model 0.8.121 → 41/42 (97.6%);
lutaml-model 0.8.123 (complexType/extension anyAttribute mappings) +
leptris 1.9.380.2 → 42/42 (100.0%); xs:group expansion in the content
and occurrence walks grew the corpus to 45 checks → 45/45 (100.0%);
abstract-element usage checking → 47/47 (100.0%); wildcard-alternative
choice counting + builtin-memberType union answers via engine-context
wiring (union-simple had regressed to a false positive on main) →
49/49 (100.0%).

Remaining engine-mode gaps (tracked, moxml/leptris-side):

- strict `xs:any` and `xs:anyAttribute` under-detection
  (`invalid-undeclared` instances validate) — documented lax posture
- `xsi:nil` on non-nillable elements accepted
- `namespaces-qualified`: wrong-namespace root accepted (engine
  root-matching skips it; the pipeline's root check catches it)

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
      duplicate detection, keyref resolution); dangling-keyref detection
      active since lutaml-model 0.8.121 (lutaml-model#990)
- [x] Wildcards: `any` namespace constraints (##any/##other/##local/
      ##targetNamespace/lists) + `processContents` strict declaration
      checking in the content-model walk; `anyAttribute` honors namespace
      constraints and strict checking on every shape — attributeGroup and
      restriction always, complexType-level and extension shapes since
      lutaml-model 0.8.123 maps them (lutaml-model#995); the capability
      probe keeps older models on pre-wildcard behavior
- [x] `xsi:nil` (nillable + empty-content checks) and `xsi:type`
      resolution (unknown-type rejection; content walk follows the
      override); the engine's valid-derived false positive is fixed in
      leptris 1.9.380.2 (moxml#433)
- [x] Particle checking: UPA detection (2026-10-22) —
      `UniqueParticleAttribution` schema-side checker: first-set
      computation over sequence/choice/all with wildcard/element
      overlap, choice-alternative and sequence-junction conflict rules,
      container occurrence folding. Standalone API
      (`findings` → upa_violation findings); zero findings on the
      conformance corpus schemas (no false positives). Depth (2026-10-22):
      xs:group references expand to the referenced declaration
      (cycle-guarded), and element first-sets include substitution-group
      members — head/member junctions report per XSD 1.0 while required
      head/member sequences stay deterministic. Wired into
      `ValidationJob` as an opt-out `validate_upa` phase: schema
      findings surface as warnings and never flip instance validity.
      Also fixed the occurrence rule's choice counting: one instance
      element matching duplicate alternatives counts once, not once
      per alternative
- [ ] XSD 1.1 constructs behind a version flag — DEFERRED: 1.1 strategy
      decision needed (see TODO.som.md)

## Official W3C suite (2026-10-23)

The official suite (w3c/xsdtests, W3C Document License, fetched at a
pinned commit) is measured via `rake conformance:w3c`:

| mode | pass-rate |
|---|---|
| pipeline | 3626/4646 (78.1%) |

One batch (cases 3000-3049) crashed and is unmeasured (same batch as
the 71.8% baseline, so counts stay comparable). Small per-category
jitter (±4) between runs is batching noise. Failure concentration
(the work queue, largest first):

- `Particles_w3c` (72, was 261 at the 76.4% cut) — ref particles now
  match through the referenced global declaration (name AND namespace;
  the empty-string name and owner-schema namespace bugs false-positived
  the whole Je family) and the resolver indexes nested xs:import/
  xs:include targets (lutaml-model parses them as child Schema
  objects; the index never descended). Remaining: composition depth
- `ComplexType_w3c` (80), `Element_w3c` (75) — same depth class
- `IdentityConstraint_w3c` (72) — selector/field depth, cross-element
  scopes
- `DataTypes_w3c` (82, was 135) + `SimpleType_w3c` (33, was 36) —
  list/union/range facets IMPLEMENTED (2026-10-24); temporal facet
  comparisons IMPLEMENTED (2026-10-25, PR #139): duration orders by
  (months, seconds) per Appendix E, date/time family via DateTime —
  temporal cases 231/270 (85.6%). Remaining corners: typed enumeration
  comparison, gYearMonth edge parsing, duration+pattern combinations
- `Regex_w3c` (354) — decomposed by error source (2026-10-25): 330
  failures carry the ENGINE's rejection (leptris XSD-regex dialect
  lacks `\p{Is...}` block escapes and friends, so valid documents are
  false-positived engine-only 312 + both 18) — moxml/leptris-side,
  registered upstream (moxml#464); 36 are pipeline-side corners
  (rules-only 18 + both 18): unescaped `-` runs inside classes, exotic
  `\p` category sets, surrogate-pair ranges. `XsdRegex` itself now
  translates top-level block escapes and normalizes block names
  (hyphen/digit boundaries, upper-run splits, Unicode-renamed blocks)
- remaining: Attribute (56), ModelGroups (50), Additional (48),
  Group (32), AttributeGroup (26), Schema (20), Wildcards (17),
  Errata10 (3)
