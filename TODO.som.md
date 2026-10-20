# TODO.som — schema object model completeness (XSOM parity)

Goal: the Ruby SOM must answer every structural question XSOM can, with
XSD 1.1 constructs layered on.

## Parse-side completeness

- [ ] `xs:redefine` semantics (redefinition chains, component shadowing)
- [ ] Chameleon includes (no targetNamespace schema included into a
      namespaced one — namespace adoption rules)
- [ ] Substitution group closure and membership enumeration on the model
- [ ] `xs:group` / `xs:attributeGroup` reference resolution including
      redefined groups
- [ ] Complex type derivation graph: extension/restriction chains,
      `{base type definition}` reachable from any type model object
- [ ] Simple type facets carried fully into the model (they exist —
      verify lossless round-trip via `to_xml`)

## Query surfaces

- [ ] Structural queries over the model using moxml XPath where trees are
      involved (type lookup, usage search) instead of Ruby tree walks
- [ ] `SchemaRepository#types_in_namespace` and friends: deterministic
      ordering + stable public docs (they are the API surface)
- [ ] Type hierarchy export (DOT/mermaid) from `type_hierarchy_analyzer`
      into the SPA (one source of truth)

## 1.1 constructs (behind `version: "1.1"`)

- [ ] `xs:assert` / `xs:assertion` model + evaluation hooks (XPath 2-ish
      subset via leptris expression engine where available)
- [ ] `xs:alternative` conditional types; `openContent` modes
- [ ] `xs:override` and `xs:defaultOpenContent`
