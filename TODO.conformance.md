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
| pipeline | 4138/4676 (88.5%) |

(2026-10-27, NFA content-model matcher branch, suite @ 7bc3365.)
Measured 4676 of 4696 cases: batch offsets 3000-3019 were skipped
because batch workers died natively (no Ruby error, low RSS). ROOT
CAUSE (2026-10-27): the engine's compiled automaton for occurrence
products like `element unbounded inside sequence{100}`
(particlesZ034_b) grows until jetsam kills the process — each case
runs in under 2s alone, the kill needs prior compiles to accumulate.
Guarded by `OccurrenceProductGuard` (engine-inert above a 1e6
particle-path product cap; engine-side explosion registered upstream
moxml#473); the next full-suite measurement picks the 20 cases up.
Suite history: 71.8% baseline → 83.5% (pre-NFA)
→ 88.5%; +261 cases net over the pre-NFA pipeline. Composition
families: Particles 42→24 fails, ModelGroups 21→18, in-scope A/B
(old vs new code over the same 750 cases): 75→60. The remaining
ModelGroups gap: xs:redefine schemas cannot PARSE (lutaml-model#1025,
upstream) and several mgQ/mgA valid cases carry engine-side false
rejections (moxml#466, upstream).
Failure concentration (the work queue, largest first):

- `Regex_w3c` (131) — decomposed by error source (2026-10-25): the
  bulk carry the ENGINE's rejection (leptris XSD-regex dialect lacks
  `\p{Is...}` block escapes and friends, so valid documents are
  false-positived engine-only) — moxml/leptris-side, tracked via the
  moxml issue queue; a pipeline-side minority remains: unescaped `-`
  runs inside classes, exotic `\p` category sets, surrogate-pair
  ranges. `XsdRegex` itself now translates top-level block escapes and
  normalizes block names (hyphen/digit boundaries, upper-run splits,
  Unicode-renamed blocks)
- `DataTypes_w3c` (84) + `SimpleType_w3c` (30) —
  list/union/range facets IMPLEMENTED (2026-10-24); temporal facet
  comparisons IMPLEMENTED (2026-10-25, PR #139): duration orders by
  (months, seconds) per Appendix E, date/time family via DateTime —
  temporal cases 231/270 (85.6%). Remaining corners: typed enumeration
  comparison, gYearMonth edge parsing, duration+pattern combinations
- `IdentityConstraint_w3c` (38) — selector/field depth; multi-field
tuple keys, node-set field violations and absent-field rows handled, cross-element
  scopes
- `Particles_w3c` (24, was 261 at the 76.4% cut) + `Element_w3c` (31)
  + `ComplexType_w3c` (26) — element form defaults, ref particles,
  nested imports, choice occurrence bounds, block= enforcement
  (element- AND type-level block against direct-derivation overrides),
  choice alternatives of any particle kind (choice(sequence(a)) no
  longer counts zero alternatives), global-declaration namespace
  governance (a global element governs qualified use only — an
  unqualified instance child is wildcard territory, not a mismatch),
  ref's minOccurs/maxOccurs governs the expanded container, and a bounded group SEQUENCE
  repeats as a unit), xsi:type
  derivation VALIDITY (an override must be validly derived from the
  declared type — lists/unions derive from anySimpleType, not their
  item types) and schema-level blockDefault (the schema-wide default
  block applies to declarations without an explicit block) are in;
  remaining is composition depth. Rule crashes on xs:all containers
  fixed (typed collect_particles, empty-all semantics, particle_name
  dispatch) — these had been poisoning run-to-run measurements
- `ModelGroups_w3c` (18, was 47) — base-type attributes flow into
  derived types through extension AND restriction (a restriction
  narrows but cannot drop attributes, XSD 1.0 §3.4.2); the mgB/mgF
  rule_execution crashes (xs:annotation leaking into particle lists
  via resolved_element_order) are fixed
- remaining (2026-10-27): Additional (46), Attribute (30), Element (31),
  Schema (25), AttributeGroup (18), ComplexType (19), Group (9),
  Errata10 (4), Notations (1)
