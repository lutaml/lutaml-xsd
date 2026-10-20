# TODO.performance — measured speed on the fastest Ruby XML engine

Goal: stay the fastest, prove it continuously, and adopt every new engine
surface as moxml/leptris ship it.

## Engine integration maturation

- [x] Track https://github.com/lutaml/moxml/issues/410 — FIXED upstream
      (moxml PR #411, merged 2026-10-20; bridges content_valid? children
      through to_binding). NOTE: the fix is merged but NOT yet in a
      published moxml release (0.5.148 predates it) — the un-gating item
      below is release-blocked, waiting on a moxml release version.
- [ ] When the fixed moxml releases (user states version): bundle update
      moxml/leptris, remove the `engine_content_capable` gates in
      content_model_validation_rule_spec, verify content delegation runs
      live
- [ ] Adopt moxml `Plan`/`StructPlan` materialization for the hot
      parse path if lutaml-model exposes seams for it (profile first)
- [ ] Engine error payload richness: once line/column/path are stable
      across adapters, surface them in CLI output and the SPA findings UI

## Benchmarks

- [x] In-repo benchmark suite (`benchmark/engines.rb` + `rake
      benchmark:engines`): engine parse/xpath/serialize, pipeline parse,
      schema to_xml, compiled-schema validation
- [x] Baseline table: leptris vs nokogiri adapter (2026-10-20, Ruby 3.4.8,
      arm64-darwin, 10.8 KB corpus converted from
      metanorma-model-iso-grammars/bsi.rnc under rng 0.3.7 — corpus is
      SMALL because rng 0.3.7 partially resolves the include tree;
      re-run after the rng 0.3.9 recalibration for the full corpus):

| measurement | leptris | nokogiri |
|---|---|---|
| engine_parse | 0.3 ms | 0.4 ms |
| engine_xpath_elements | 0.9 ms | 0.4 ms |
| engine_serialize | 0.7 ms | 0.1 ms |
| pipeline_schema_parse | 274 ms | 377 ms |
| pipeline_schema_to_xml | 224 ms | 223 ms |
| engine_xsd_compile | 0.1 ms | n/a (SyntaxError on rng-0.3.7 corpus) |
| engine_xsd_validate | 0.0 ms | n/a |

  Caveat: per-op values are noisy run-to-run (0.1–12 ms spread observed)
  on a small corpus; the harness is the deliverable, numbers firm up on
  the post-recalibration corpus.
- [ ] CI-optional benchmark run (manual dispatch) with trend notes —
      no PR-blocking perf gates yet

## Profiling targets

- [ ] SPA generation memory profile on 100+ schema corpora
      (`package_builder` marshal cleanups already exist — verify they hold)
- [ ] `EngineContext.compile` cost on multi-schema repositories
      (schema `to_xml` + compile per package load; consider caching
      compiled handles per repository instance)
- [ ] XmlNavigator walk cost on deep instance trees
