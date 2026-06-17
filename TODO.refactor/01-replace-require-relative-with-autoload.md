# Replace all `require_relative` with Ruby `autoload`

## Problem
`lib/lutaml/xsd.rb` has 41 `require_relative` calls. `schema_repository.rb` has 5 more
(at bottom of file and inside method bodies). `spa.rb`, `formatters/`, `commands/`,
`validation/` all use `require_relative` internally.

Per global rules: never use `require_relative` for internal library code.
Use Ruby `autoload` instead, defined in the immediate parent namespace's file.

## Solution

### 1. Convert `lib/lutaml/xsd.rb` to autoload
Replace all `require_relative` with `autoload` entries under `module Lutaml::Xsd`.

### 2. Create parent namespace files where missing
- `lib/lutaml/xsd/conflicts.rb` — defines `module Conflicts` with autoload for namespace_conflict, type_conflict, schema_conflict
- `lib/lutaml/xsd/formatters.rb` — defines `module Formatters` with autoload for base, registry, formatter_factory, text/json/yaml formatters
- `lib/lutaml/xsd/validation.rb` — defines `module Validation` with autoload for all validation sub-classes
- `lib/lutaml/xsd/commands.rb` — defines `module Commands` with autoload for all command classes
- `lib/lutaml/xsd/schema_repository.rb` already exists — add autoload for type_index, namespace_registry, qualified_name_parser

### 3. Update sub-directory files
Remove `require_relative` from files inside:
- `formatters/` (base, registry, formatter_factory, json/text/yaml_formatter)
- `commands/` (all 17 command files use require_relative)
- `validation/` (all 15+ validation files use require_relative)
- `spa.rb` and `spa/` sub-files
- `errors/` sub-files

### 4. Handle cross-cutting requires
Some files require gems (e.g., `require "thor"`, `require "json"`). These external
requires are fine — only internal `require_relative` must be replaced.

## Files affected
- `lib/lutaml/xsd.rb` (main entry point — 41 require_relative → autoload)
- `lib/lutaml/xsd/schema_repository.rb` (5 require_relative)
- `lib/lutaml/xsd/spa.rb` (7 require_relative)
- NEW: `lib/lutaml/xsd/conflicts.rb`
- NEW: `lib/lutaml/xsd/formatters.rb`
- NEW: `lib/lutaml/xsd/validation.rb`
- NEW: `lib/lutaml/xsd/commands.rb`
- All files in `commands/`, `formatters/`, `validation/`, `spa/`, `errors/`

## Acceptance criteria
- [ ] Zero `require_relative` calls in `lib/`
- [ ] All classes load correctly via autoload
- [ ] `bundle exec rake` passes (specs + rubocop)
- [ ] `bundle exec ruby -e "require 'lutaml/xsd'"` succeeds
