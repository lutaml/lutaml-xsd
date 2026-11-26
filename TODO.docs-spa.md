# TODO.docs-spa — comprehension SOTA: interactive, live-validated documentation

Goal: leapfrog static commercial doc-generators (Oxygen/Altova) with an
interactive corpus browser where the documentation *executes*.

Status 2026-10-20: DEFERRED as a pillar. Reason: the SPA features below
need the frontend development loop (`rake build_frontend`, Vue dev server)
and a backend seam decision (CLI vs HTTP). The validation core these
features depend on is ready (EngineContext + `engine_validation` +
Conformance runner), so the UI work can start against a stable base. The
one prerequisite wiring — rule-registry gaps surfacing as findings — is
tracked in TODO.conformance.md.

## Live validation playground (the killer feature)

- [x] SPA page: paste/upload an XML instance → validate against the loaded
      package (engine + rule stack via a CLI/HTTP seam) → findings with
      line/column/path — DONE 2026-11-14: the seam decision is HTTP
      (`lutaml-xsd serve PACKAGE.lxr`, WEBrick lazily loaded,
      Gemfile-side only — never the gemspec). The playground view
      (frontend/src/views/PlaygroundView.vue) posts to /api/validate;
      the server validates through ValidationJob with the same
      repository recipe the W3C suite harness measures with.
- [x] Click-through: finding → schema component page — DONE 2026-11-14
      (PR #276): a finding whose location/message names a schema
      component routes to its page with the detail panel open
- [x] Instance tree view with per-node validity — DONE 2026-11-14
      (PR #276): client-side DOMParser tree with per-node invalid
      markers matched by finding references

## Navigation & comprehension

All items here are tracked in issue #289 (the comprehension package).

- [x] Global search ranking — DONE (2026-11-26, the graphs round):
      exact-name > prefix > substring, entrypoint schemas boosted,
      deprecated demoted, types edge elements as tiebreak
      (useSearch scoreResult; composable tests pin the ordering)
- [x] The a11y pass over the new views — DONE (2026-11-26): the axe
      gate (`rake axe`, script/axe_audit — sovereign axe-core copy,
      headless Chrome, skips on browser-less lanes like the
      lutaml-jsonschema precedent) audits the home AND /graphs views;
      both PASS the AA bar. The pass also fixed the app-wide findings:
      the main landmark + focusable content area, AA-grade muted and
      dark-theme primary/link tokens, the tab styling that never
      applied outside HomeView, and the sidebar footer links
- [x] Type hierarchy graph in the SPA — DONE (2026-11-26): the
      serializer ships per-type derivation chains (hierarchy map) AND
      the loading path is fixed (resolve on package load; the
      TypeHierarchyAnalyzer works end-to-end with the SOM derivation
      queries), and the /graphs view renders the chains with
      click-through (PR: the graphs round). Remaining polish: mermaid
      rendering (the SPA carries no mermaid dependency; chains render
      as link trees today)
- [x] Usage navigation matrix — the DATA layer is DONE (2026-11-26):
      the serializer derives the `usage` map from the serialized
      payloads (element/particle/attribute/derivation references,
      extension bodies included — which also fixed the payload
      completeness gap where complexContent particles never reached
      the SPA), and the /graphs usage tab ranks types by reference
      count with expandable used_by lists
- [~] Dependency graph page — FOLDED into the /graphs view (the
      usage/derivation tabs are the package-level graph page); the
      corpus-level include/import view remains (imports serialize per
      schema; a page-level render is a follow-up)

## Evolution

- [x] Schema diff between package versions — DONE (2026-11-26, the
      schema-diff rounds):
      docs/superpowers/specs/2026-11-26-schema-diff-design.md (identity
      key, taxonomy, rename heuristic), Lutaml::Xsd::SchemaDiff with
      the ChangeSet/Change/Modification models (lutaml-model
      serialization), and the golden-contract spec over the versioned
      fixture corpus; `lutaml-xsd spa --diff OLD.lxr` embeds the
      ChangeSet and the SPA renders the grouped change list with
      click-through (axe-audited at the AA bar)
- [ ] Coverage view wired to `coverage_analyzer` — DEFERRED (#289)

## Polish

- [ ] SPA generation performance on large corpora — DEFERRED until the
      post-recalibration corpus exists (TODO.performance.md)
- [x] Accessibility pass on the SPA — DONE 2026-11-26: the axe gate audits home + /graphs at the AA bar (`rake axe`); the app-wide fixes shipped with it (see the Navigation section)
- [ ] Nightly demo package regeneration in CI — DEFERRED: cimas-owned
      workflow; needs an owner decision on schedule
