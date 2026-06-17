# Memoize SchemaQueryService and SchemaExporter on SchemaRepository

## Problem

`SchemaRepository` instantiates a fresh `SchemaQueryService` and
`SchemaExporter` on **every** call. The current `find_*`/`statistics`/etc.
delegators:

```ruby
def find_type(qname)
  SchemaQueryService.new(self).find_type(qname)         # lib/lutaml/xsd/schema_repository.rb:154
end

def statistics
  SchemaExporter.new(self).statistics                    # lib/lutaml/xsd/schema_repository.rb:189
end
# ... 10 more sites
```

Every query allocates a new service object and discards it. The services are
stateless with respect to the repository (they read from it, never write), so
a single long-lived instance is safe.

This is both a performance issue (allocation pressure) and a code-smell
(repeated `X.new(self).y` is a memoization bug).

## Solution

Memoize the services on the repository. Use `||=` lazy init.

```ruby
class SchemaRepository
  def query
    @query ||= SchemaQueryService.new(self)
  end

  def exporter
    @exporter ||= SchemaExporter.new(self)
  end

  def find_type(qname)
    query.find_type(qname)
  end
  # ... etc
end
```

The services are exposed as `attr_reader :query, :exporter` (or private
`query`/`exporter` accessors — the choice depends on whether external
callers should bypass the delegator; recommend public read access for test
support and external tool building).

### Bonus: remove the delegators if nothing internal needs them

`find_type` etc. on `SchemaRepository` exist solely to forward to
`SchemaQueryService`. If the only callers are the CLI commands, replace the
delegator with a direct call: `repository.query.find_type(qname)`. This
makes the indirection explicit at the call site and removes ~10 lines from
the repository.

This is the better design because it surfaces that the query service is a
separate concern, but it is a larger change. Apply the memoization first
(smallest correct change), then consider the delegator removal as a
follow-up.

## Files affected

- `lib/lutaml/xsd/schema_repository.rb` (add `query`/`exporter` accessors,
  update delegators to use them)
- All callers that currently use `repository.find_*` — no change needed
  unless the delegators are removed

## Acceptance criteria

- [ ] `SchemaQueryService.new` called exactly once per repository instance
  (verified by a spec)
- [ ] `SchemaExporter.new` called exactly once per repository instance
- [ ] All existing functionality preserved (regression suite passes)
- [ ] `bundle exec rake` passes

## Specs required

- `spec/lutaml/xsd/schema_repository_spec.rb` — add examples asserting
  memoization:
  ```ruby
  it "memoizes SchemaQueryService" do
    repo1 = repo.query
    repo2 = repo.query
    expect(repo1).to equal(repo2)
  end
  ```
- A spec that calls `find_type` 100 times and asserts the underlying service
  was constructed only once (use `SchemaQueryService`'s constructor side
  effect — or add a `@@instance_count` class variable for testability, or
  spy with a real `BasicStore`).

## Risks

- None significant. The services are stateless relative to the repository.
  If a future service is added that has mutable state, memoization must be
  revisited.
