# TODO.cleanup — hygiene, debts, and flagged items

Goal: zero known debt; every flagged item resolved or explicitly archived.

Status 2026-10-20: in-repo hygiene is clean; remaining items are
release-gated or need owner confirmation.

## In-repo (lutaml-xsd)

- [x] Lockfile divergence guard: committed Gemfile.lock with all CI
      platforms + `deps:lockfile_check` in the default rake task (PR #109)
- [x] `Lutaml::Xsd.parse` restored as the documented public entry point
      (delegates to `Lutaml::Xml::Schema::Xsd.parse`); docs/*.adoc
      references are true again (this PR)
- [x] `XmlElement#namespace_uri` uses the Moxml namespace API (PR #108)
- [ ] rng 0.3.8 baseline recalibration — DEFERRED, release-gated: the
      converter expectations are precomputed against the fixed rng
      (complex types 170, simple types 13, elements 203, groups 237,
      attribute_groups 44; sections sequence: 7 choices / 1 group /
      1 element) and the spec + `rng ~> <released>` pin land together
      once the rng release with the include fixes exists (version is the
      owner's to state)
- [ ] `lib/lutaml/xsd/schema_query_service.rb.bak` (untracked) — DEFERRED,
      owner confirmation required: archive under `docs/archive/` or delete
- [ ] Prunable stale worktrees (`/private/tmp/fix/xsd`, `/private/tmp/xsd-main`)
      — DEFERRED, owner to run `git worktree prune` after confirming the
      branches hold nothing needed
- [ ] Dead-code sweep — DEFERRED, owner confirmation per file (nothing is
      auto-deleted); the first candidate found in this run is
      `RncToRngConverter#add_annotations` in rng (uncalled since 0.3.x)
- [ ] `Gemfile.lock` divergence guard for other lutaml gems — not needed
      yet; adopt the same pattern when those repos start hitting the
      fresh-resolve class of failure

## Cross-repo (each in its own repo, own PR, house rules)

- [x] rng gem → Moxml migration (rng PR #35): converter, validator,
      test-suite parser ported; nokogiri out of the runtime deps
- [x] moxml#410 follow-through: fixed in moxml PR #411, released as
      moxml 0.5.149; lutaml-xsd locks 0.5.149 and the engine content-seam
      specs now run live (verified 2026-10-21)
- [ ] lutaml-model `Schema.reset_processed_schemas` global mutable state —
      DEFERRED: file on lutaml-model only if the owner agrees it is worth
      a public API change (per-parse context option)
