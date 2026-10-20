# TODO.performance — measured speed on the fastest Ruby XML engine

Goal: stay the fastest, prove it continuously, and adopt every new engine
surface as moxml/leptris ship it.

## Engine integration maturation

- [ ] Track https://github.com/lutaml/moxml/issues/410 (leptris
      `Schema#content_valid?` c_ptr NoMethodError). When fixed: bundle
      update moxml/leptris, remove the `engine_content_capable` spec gate
      (content seam tests run live), delegate content checks for real
- [ ] Adopt moxml `Plan`/`StructPlan` materialization for the hot
      parse path if lutaml-model exposes seams for it (profile first)
- [ ] Engine error payload richness: once line/column/path are stable
      across adapters, surface them in CLI output and the SPA findings UI

## Benchmarks

- [ ] In-repo benchmark suite (`benchmark/`): parse, validate, serialize,
      SPA generation on a large real corpus (e.g. the metanorma
      metanorma-model-iso-grammars fixture set and a big BSI/ISO corpus)
- [ ] Baseline table: leptris vs nokogiri adapter on the same suite;
      record numbers here once measured
- [ ] CI-optional benchmark run (manual dispatch) with trend notes —
      no PR-blocking perf gates yet

## Profiling targets

- [ ] SPA generation memory profile on 100+ schema corpora
      (`package_builder` marshal cleanups already exist — verify they hold)
- [ ] `EngineContext.compile` cost on multi-schema repositories
      (schema `to_xml` + compile per package load; consider caching
      compiled handles per repository instance)
- [ ] XmlNavigator walk cost on deep instance trees
