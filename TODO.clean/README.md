# TODO.clean — second-wave refactor after `apply-lutaml-store`

These TODOs capture the work surfaced by an audit of the
`apply-lutaml-store` branch after rebasing onto `origin/main` (post
`TODO.refactor/01..09`). TODO.refactor tackled the first wave (autoloads,
encapsulation, decomposition scaffolding); TODO.clean finishes what that
wave started and removes the smells introduced along the way.

## Index

| # | Title | Priority | Effort | Depends on |
|---|---|---|---|---|
| 01 | [Resolve circular dependency: SchemaRepository ↔ PackageLoader ↔ SchemaParser](01-resolve-circular-dependency-schema-repository.md) | Critical | M | — |
| 02 | [Decompose RngToXsdConverter (1411-line monolith)](02-decompose-rng-to-xsd-converter.md) | Critical | L | — |
| 03 | [Eliminate duplicated service code](03-eliminate-duplicated-service-code.md) | High | S | 01 |
| 04 | [Replace `rescue NoMethodError` with type dispatch](04-replace-rescue-nomethoderror.md) | High | S | — |
| 05 | [Memoize SchemaQueryService and SchemaExporter](05-memoize-service-objects.md) | Medium | S | — |
| 06 | [Eliminate global `processed_schemas` cache](06-eliminate-global-processed-schemas-cache.md) | High | M | 01 |
| 07 | [Remove dead and misleading parameters](07-remove-dead-parameters.md) | Low | S | — |
| 08 | [Eliminate spec anti-patterns (doubles, ivar, send)](08-eliminate-spec-anti-patterns.md) | High | L | — |
| 09 | [Investigate spec discovery regression (88/1375)](09-investigate-spec-discovery-regression.md) | High | S | — |
| 10 | [Split SchemaExporter into focused collaborators](10-split-schema-exporter-responsibilities.md) | Medium | M | — |
| 11 | [Shrink SchemaRepository to under 300 lines](11-shrink-schema-repository-under-300.md) | Medium | M | 01, 03 |
| 12 | [Add focused unit specs for new services](12-add-focused-service-specs.md) | High | M | 01, 02, 10 |
| 13 | [Consolidate SchemaRepository-prefixed classes into namespace](13-consolidate-schema-repository-naming.md) | Low | M | — |

## Suggested execution order

The audit identified **two critical paths**. Run them in parallel:

**Path A (schema repository cleanup):**
1. TODO.clean/01 — break the circular dependency
2. TODO.clean/03 — delete duplicates (becomes trivial after 01)
3. TODO.clean/06 — kill the global cache
4. TODO.clean/11 — final shrink of `SchemaRepository`

**Path B (RNG converter decomposition):**
1. TODO.clean/02 — extract collaborators
2. TODO.clean/04 — fix the rescue hack (moves into a collaborator)

**Path C (spec quality):**
1. TODO.clean/09 — fix discovery first (otherwise spec work is invisible)
2. TODO.clean/08 — replace anti-patterns across the suite
3. TODO.clean/12 — add focused unit specs for services

Standalone quick wins:
- TODO.clean/05 (memoize services — 1-line fix per service)
- TODO.clean/07 (drop dead parameter)

Optional / nice-to-have:
- TODO.clean/10 (split `SchemaExporter`)
- TODO.clean/13 (namespace consolidation — breaking change, defer)

## Audit context

Findings grounded in measured state (post-rebase):

- `lib/lutaml/xsd/schema_repository.rb` — 643 lines
- `lib/lutaml/xsd/rng_to_xsd_converter.rb` — 1411 lines
- `lib/lutaml/xsd/package_loader.rb` — 185 lines (back-calls into repository)
- `lib/lutaml/xsd/schema_parser.rb` — 122 lines (duplicates repository's parse logic)
- Global cache (`processed_schemas`) — 17 read/write sites in `lib/`
- Service-object re-instantiation — 12 sites in `schema_repository.rb`
- `rescue NoMethodError` — 1 site (rng_to_xsd_converter.rb:1158)
- Dead parameters — 1 known (`_glob_mappings`)
- Spec anti-patterns — 34 spec files with doubles/ivars/send
- Spec discovery — 88 of 1375 examples run by `rake spec`
