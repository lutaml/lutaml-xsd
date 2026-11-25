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

- [ ] Global search across types/elements/attributes/groups — DEFERRED:
      the search index exists (`build_index`); ranking design + UI work
      (#289)
- [ ] Usage navigation matrix for attributes and groups — DEFERRED:
      liquid methods pattern exists; extend `used_by` coverage first
      (#289)
- [~] Type hierarchy graph in the SPA — the DATA layer is DONE
      (2026-11-25): the serializer ships per-type derivation chains as
      the `hierarchy` map and type cards render chain-to-root; the
      graph VIEW and the analyzer-index loading-path design remain
      (#289 — the drift discovery is recorded there)
- [ ] Dependency graph page — DEFERRED (#289; the DependencyGrapher
      data layer exists, the same loading-path design pass applies)

## Evolution

- [ ] Schema diff between package versions — DEFERRED: structural diff
      design needed (component identity across versions). FILED as
      issue #288 (the design-first campaign)
- [ ] Coverage view wired to `coverage_analyzer` — DEFERRED (#289)

## Polish

- [ ] SPA generation performance on large corpora — DEFERRED until the
      post-recalibration corpus exists (TODO.performance.md)
- [ ] Accessibility pass on the SPA — DEFERRED (rides the next UI change)
- [ ] Nightly demo package regeneration in CI — DEFERRED: cimas-owned
      workflow; needs an owner decision on schedule
