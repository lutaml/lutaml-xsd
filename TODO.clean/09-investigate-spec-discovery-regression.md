# Investigate and fix spec discovery regression (88 of 1375 examples run)

## Problem

`bundle exec rake spec` runs **only 88 examples**, but a dry run shows
**1375 examples** exist:

```
$ bundle exec rake spec
...
88 examples, 0 failures

$ bundle exec rspec --dry-run
...
1375 examples, 0 failures
```

The default `--pattern` passed to RSpec is
`spec/\*\*\{,/\*/\*\*\}/\*_spec.rb` — this should find all spec files, but
1287 examples are silently dropped.

Pre-existing issue (existed before the current refactor branch). But it
hides test regressions and gives false confidence: passing 88 examples
does not mean 1287 others still pass.

## Hypotheses

1. **Rake task overrides the pattern.** The Rakefile may invoke
   `RSpec::Core::RakeTask` with a custom `pattern` that limits discovery.
2. **`.rspec` file is malformed.** A typo in `.rspec` (e.g., a stray
   `--pattern` line) silently narrows the scope.
3. **`spec_helper.rb` filter.** A `config.filter_run` rule excludes
   most examples.
4. **Tag-based exclusion.** Examples tagged `:type => :integration` (or
   similar) are excluded by default.
5. **Filename mismatch.** Some spec files use `_spec.rb` in directories
   the pattern doesn't reach.

## Solution

### Step 1 — Diagnose

```bash
# What pattern does rake actually invoke?
bundle exec rake spec --trace

# What does the .rspec file contain?
cat .rspec

# What does spec_helper.rb filter?
grep -n 'filter_run\|exclude_patterns\|include_context' spec/spec_helper.rb

# How many spec files exist? Where?
find spec -name '*_spec.rb' | head -50
find spec -name '*_spec.rb' | wc -l
```

### Step 2 — Fix

The most likely fix is one of:

- Remove a custom `pattern` from the Rakefile's `RSpec::Core::RakeTask`.
- Correct `.rspec` to not specify a narrow pattern.
- Remove a `filter_run` from `spec_helper.rb` that excludes by default.

### Step 3 — Verify

```bash
bundle exec rake spec
# Expect: ~1375 examples, 0 failures (or known-failing examples surface)
```

### Step 4 — Triage any new failures

Once discovery is fixed, previously-hidden failures will surface. Triage
each:

- Real bug? Fix the code.
- Stale spec? Update or delete.
- Anti-pattern in spec (double/instance_variable_set/etc.)? Fix per
  TODO.clean/08.

## Files affected

Likely one or more of:
- `Rakefile`
- `.rspec`
- `spec/spec_helper.rb`
- `.bundle/config` (if `BUNDLE_GEMFILE` affects rake)

## Acceptance criteria

- [ ] `bundle exec rake spec` discovers and runs all examples that
  `bundle exec rspec --dry-run` reports
- [ ] No intentional exclusion of large groups of examples without an
  explicit, documented reason (e.g., a `:type => :slow` tag with a
  documented opt-in)
- [ ] Any newly-discovered failures are either fixed or tracked in a
  follow-up TODO with a reason

## Specs required

- This is a tooling fix; no new specs are required. CI should now run
  the full suite.

## Risks

- Surfacing many previously-hidden failures could be demoralizing. But
  hidden failures are worse than visible ones — at least visible ones
  can be triaged.
- Some hidden failures may be genuine regressions from earlier
  refactor work; be ready to fix them.
