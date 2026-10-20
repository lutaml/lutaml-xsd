# TODO.docs-spa — comprehension SOTA: interactive, live-validated documentation

Goal: leapfrog static commercial doc-generators (Oxygen/Altova) with an
interactive corpus browser where the documentation *executes*.

## Live validation playground (the killer feature)

- [ ] SPA page: paste/upload an XML instance → validate against the
      loaded package (engine + rule stack via a CLI/HTTP seam) → findings
      list with line/column/path
- [ ] Click-through: finding → schema component page (element/type/
      attribute source with `extract_source_by_type_key_value` excerpts)
- [ ] Instance tree view with per-node validity (valid subtree √ /
      invalid node ×) driven by the engine's element-path findings

## Navigation & comprehension

- [ ] Global search: types, elements, attributes, groups, namespaces —
      ranked, with source excerpts
- [ ] Usage navigation both ways for attributes and groups (element/
      complex_type have `used_by`; finish the matrix)
- [ ] Type hierarchy graph in the SPA (from type_hierarchy_analyzer,
      rendered interactively, not just SVG)
- [ ] Dependency graph page (imports/includes across the package)

## Evolution

- [ ] Schema diff: two package versions → structural diff view (added/
      removed/changed components) — schema evolution as documentation
- [ ] Coverage view: which parts of the corpus are exercised by an
      instance set (coverage_analyzer wired to the UI)

## Polish

- [ ] SPA generation performance on large corpora (see TODO.performance)
- [ ] Accessibility pass on the SPA (keyboard nav, ARIA on diagrams)
- [ ] Deployed demo package regeneration in CI (nightly) to catch UI
      regressions without a frontend test rig
