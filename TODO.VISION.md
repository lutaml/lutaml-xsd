# TODO.VISION — lutaml-xsd: purpose audit and the SOTA thesis

Last audited: 2026-10-20.

## The purpose (audit answer)

lutaml-xsd exists to make XML Schema corpora **legible, governable, and
documentable**. Everything in this repository serves one thesis in three
movements:

1. **Ingest** — any real-world schema corpus becomes a first-class Ruby
   object graph: XSD 1.0/1.1 and RNG/RNC, with imports/includes/redefines,
   chameleon schemas, network-resolved schemaLocation, broken documents —
   normalized into a namespace-managed, packageable (`​.lxr`) repository.
2. **Understand** — a complete Schema Object Model plus the tools of
   comprehension: type search, dependency graphs, cross-references,
   coverage analysis, SPA documentation, SVG diagrams. A corpus you can
   *read*, not merely parse.
3. **Govern** — instance validation (Ruby rule engine + native engine via
   Moxml::XSD), package conflict detection/resolution, and bridges to other
   model worlds (Liquid/LutaML, JSON Schema). A schema becomes a living
   contract, and its documentation becomes executable.

The differentiating claim (no SOTA tool does all three): **schema
comprehension at corpus scale, wired into a model-driven documentation
pipeline** (LutaML/Metanorma), on the fastest XML engine available to Ruby
(moxml → leptris).

## What SOTA means here (the benchmarks we accept)

- **Validator conformance**: the W3C XML Schema Test Suite (and the legacy
  Sun/MSV collections) are the canonical benchmark; Xerces-J (1.0) and
  Xerces2/Scala.xml (1.1) are reference implementations. Conformance is a
  NUMBER — pass-rate against that suite. See TODO.conformance.md.
- **Schema comprehension**: commercial SOTA is Oxygen XML / Altova doc-gen
  (static). Academic SOTA is schema summarization/visualization research.
  We leapfrog both with an *interactive* SPA: live validation playground,
  usage navigation, schema evolution diffs. See TODO.docs-spa.md.
- **Performance**: leptris (C99 FFI) + moxml Plan/StructPlan materialization
  is already the fastest Ruby XML stack; we must keep it measured
  (benchmarks in-repo) and adopt new engine surfaces as they land.
  See TODO.performance.md.
- **Object model**: XSOM (Sun) remains the semantic gold standard for a
  schema object model — closure, substitution groups, type unification.
  See TODO.som.md.
- **Interoperation**: bridges to JSON Schema, LutaML cross-paradigm models
  (EXPRESS/UML), and the RelaxNG bridge (rng gem) round us out.
  See TODO.interop.md.

## Pillar index

| Pillar | File | One-line goal |
|---|---|---|
| Conformance | TODO.conformance.md | Measured, growing pass-rate on W3C XSD TS |
| Performance | TODO.performance.md | Fastest, measured, engine-complete |
| Object model | TODO.som.md | XSOM-parity SOM incl. XSD 1.1 constructs |
| Comprehension | TODO.docs-spa.md | Interactive, live-validated documentation |
| Interop | TODO.interop.md | RNG bridge, JSON Schema, LutaML cross-model |
| Cleanup | TODO.cleanup.md | rng 0.3.8 baseline, rng→moxml, hygiene |

Guidance for agents: work pillar by pillar, checkbox by checkbox; every
item lands through a PR with real-object specs; keep this file's audit
current as pillars complete.
