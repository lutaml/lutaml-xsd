# TODO.cleanup — hygiene, debts, and flagged items

Goal: zero known debt; every flagged item resolved or explicitly archived.

## In-repo (lutaml-xsd)

- [ ] rng 0.3.8 baseline recalibration (cross-listed in TODO.interop):
      full review of RngToXsdConverter output under rng 0.3.8 on
      bsi.rnc (complex types 20→134, elements 23→164, groups 13→110,
      attribute_groups 1→31); then update gemspec pin to `~> 0.3.8` and
      the spec expectations in one reviewed commit
- [ ] `Lutaml::Xsd.parse` references: sweep docs (CLAUDE.md fixed
      2026-10-20; check docs/*.adoc) for the outdated entry point —
      real entry is `Lutaml::Xml::Schema::Xsd.parse`
- [ ] `lib/lutaml/xsd/schema_query_service.rb.bak` (untracked): owner to
      confirm — archive under `docs/archive/` or delete (agent must NOT
      delete without explicit confirmation)
- [ ] Prunable stale worktrees (`/private/tmp/fix/xsd` on
      `fix/rubyzip-3-align-lutaml-model`, `/private/tmp/xsd-main`): owner
      to run `git worktree prune` after confirming the branches hold
      nothing needed
- [ ] Dead-code sweep: unused modules surfaced by coverage (careful —
      owner confirmation per file; nothing auto-deleted)
- [ ] `Gemfile.lock` divergence guard: CI job step (or rake task) that
      fails loudly when a fresh resolution differs from the documented
      lock state in a way that changes spec outcomes (lesson from the
      rng 0.3.8 incident, 2026-10-20)

## Cross-repo (each in its own repo, own PR, house rules)

- [ ] rng gem → Moxml migration (detailed in TODO.interop)
- [ ] moxml#410 follow-through (detailed in TODO.performance)
- [ ] lutaml-model: `Schema.reset_processed_schemas` global mutable state
      — evaluate a per-parse-context option for consumers like the
      EngineContext root-matching (file on lutaml-model if the owner
      agrees it's a real footgun)
