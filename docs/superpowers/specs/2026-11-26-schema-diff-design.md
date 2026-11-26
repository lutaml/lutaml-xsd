# Design: schema diff between package versions

- Date: 2026-11-26
- Status: implemented with this PR (engine + specs; SPA view follows)
- Scope: lutaml-xsd (issue #288, the design-first campaign)

## 1. Problem

When an `.lxr` package is rebuilt from a changed schema corpus,
consumers need to know WHAT changed at the component level: which
types gained/lost elements, which facets moved, which declarations
appeared/vanished/were renamed. Commercial tooling does not do this at
all. The registered deferral was "component identity across versions".

## 2. Component identity

A component is the same component across versions iff its identity key
matches:

    (target namespace, local name, kind)

with kind one of `element`, `attribute`, `complex_type`, `simple_type`,
`group`, `attribute_group`. The identity key uses the RESOLVED target
namespace (Clark form), never raw prefixes or raw namespace strings:
package composition remaps namespace URIs, and a remapped corpus must
diff by identity, not by remapped literals.

### The rename problem

Pure name matching misclassifies renames as removal+addition pairs.
The engine runs a rename-reconciliation pass over unmatched pairs:

- candidates: a removed and an added component of the SAME kind in the
  SAME namespace;
- similarity: Jaccard over the normalized content fingerprints
  (attribute names, child element names, facet constraints, base);
- a pair matches as a rename when similarity >= 0.6, OR when the
  fingerprints are exactly equal (a pure rename);
- pairing is deterministic: highest similarity first, ties broken by
  name ascending, each component pairs at most once.

Cross-namespace moves (`moved_namespace`) pair the same way across
namespaces with equal local names — reported as a move, not a
rename, when only the namespace differs.

## 3. Change taxonomy

    added            — only in the new corpus
    removed          — only in the old corpus
    renamed          — renamed_from recorded on the change
    moved_namespace  — same component, new target namespace
    modified         — present both sides, content differs

Modified changes carry a `modifications` list, per kind:

- element/attribute: type change, occurrence change, default/fixed/
  nillable/abstract change, substitution-group change, use change
- complex_type: attribute-set diff (added/removed/modified members),
  child-particle name-set diff, derivation base change, mixed/abstract
  flag changes
- simple_type: facet-set diff per facet kind (added/removed/
  value-changed), base change, variety change (restriction/list/union)
- group/attribute_group: member name-set diff

Each modification is a triple `(aspect, old, new)` — machine-readable,
rendered by the SPA as a human sentence.

## 4. Engine contract

    diff = Lutaml::Xsd::SchemaDiff.new(old_repository, new_repository,
                                       namespace_map: { "old-uri" => "new-uri" })
    changeset = diff.diff
    changeset.changes   # Array<Change>
    changeset.summary   # { added: n, removed: n, ... }
    changeset.to_json   # lutaml-model serialization

- Inputs are RESOLVED repositories (the loading path fixed in the
  analyzer round); the engine is read-only over the SOM — zero impact
  on validation.
- `namespace_map` normalizes old-side namespaces before identity
  comparison (the package-composition remap face).
- `Change` and `ChangeSet` are `Lutaml::Model::Serializable` models —
  all serialization through the framework (no hand-rolled to_h/from_h).

## 5. SPA delivery (follow-up)

`lutaml-xsd spa --diff OLD.lxr` runs the engine over the two packages
and embeds the ChangeSet JSON in the SPA payload; the SPA renders a
change list grouped by category with per-component click-through.
Design sketch only in this PR.

## 6. Spec strategy

A versioned fixture corpus (v1/v2 schema files exercising every
taxonomy branch: add, remove, rename, namespace move, and each
modification aspect) with golden ChangeSet JSON files — a diff against
the golden is a contract break.
