# Eliminate spec anti-patterns: doubles, instance_variable_set, send

## Problem

Per the global CLAUDE.md rules:

> NEVER use `double()` in specs. NEVER use `instance_variable_set` or
> `instance_variable_get`. NEVER use `send` to call private methods.

20+ spec files violate one or more of these rules:

```
spec/lutaml/xsd/interactive_builder_spec.rb
spec/lutaml/xsd/package_conflict_resolver_spec.rb
spec/lutaml/xsd/schema_classifier_spec.rb
spec/lutaml/xsd/conflict_report_spec.rb
spec/lutaml/xsd/batch_type_query_spec.rb
spec/lutaml/xsd/type_hierarchy_analyzer_spec.rb
spec/lutaml/xsd/package_conflict_detector_spec.rb
spec/lutaml/xsd/spa/svg/layout_engine_spec.rb
spec/lutaml/xsd/conflicts/namespace_conflict_spec.rb
spec/lutaml/xsd/spa/output_strategy_spec.rb
spec/lutaml/xsd/coverage_analyzer_spec.rb
spec/lutaml/xsd/conflicts/type_conflict_spec.rb
spec/lutaml/xsd/spa/generator_spec.rb
spec/lutaml/xsd/commands/validate_command_spec.rb
spec/lutaml/xsd/commands/build_command_spec.rb
spec/lutaml/xsd/commands/tree_command_spec.rb
spec/lutaml/xsd/commands/generate_spa_command_spec.rb
spec/lutaml/xsd/namespace_prefix_manager_spec.rb
spec/lutaml/xsd/commands/pkg_command_spec.rb
spec/lutaml/xsd/errors/suggesters/fuzzy_matcher_spec.rb
spec/lutaml/xsd/xsd_spec_validator_spec.rb
spec/lutaml/xsd/type_searcher_spec.rb
spec/lutaml/xsd/schema_repository_helper_methods_spec.rb
spec/lutaml/xsd/schema_repository_spec.rb
spec/lutaml/xsd/dependency_grapher_spec.rb
spec/lutaml/xsd/smart_loading_spec.rb
spec/lutaml/xsd/namespace_remapper_spec.rb
spec/lutaml/xsd/namespace_registry_package_loading_spec.rb
spec/lutaml/xsd/package_tree_formatter_spec.rb
spec/lutaml/xsd/spa/svg/connector_renderer_spec.rb
spec/lutaml/xsd/spa/configuration_loader_spec.rb
spec/lutaml/xsd/spa/svg/component_renderer_spec.rb
spec/lutaml/xsd/spa/schema_serializer_spec.rb
spec/lutaml/xsd/schema_repository_merge_spec.rb
spec/lutaml/xsd/validation/rules/attribute_validation_rule_spec.rb (respond_to?)
```

Doubles are particularly damaging: they couple tests to *which methods are
called* rather than *what state is produced*, so a refactor of a real
class's interface can pass tests while breaking real usage.

TODO.refactor/06 was opened for this; only some files were updated.

## Solution

Replace each anti-pattern with a real model or a plain Struct.

### Anti-pattern → replacement cheat sheet

| Anti-pattern | Replacement |
|---|---|
| `double(target_namespace: ...)` | Real `Lutaml::Xml::Schema::Xsd::Schema` instance (or a `TestSchema` factory) |
| `double(name: "MyType")` | Real `Lutaml::Xml::Schema::Xsd::ComplexType` (or `Struct.new(:name, :base)`) |
| `instance_double(SchemaRepository)` | Real `SchemaRepository` populated with a test schema |
| `allow(x).to receive(:foo).and_return(y)` | Use the real `x`, drive it to a state where `x.foo` returns `y` |
| `instance_variable_set(:@x, y)` | Use a constructor argument or a public setter |
| `instance_variable_get(:@x)` | Add a public reader, or use the existing one |
| `subject.send(:private_method)` | Make the method public, or test through the public API that uses it |
| `respond_to?(:x)` | `is_a?(SomeClass)` — type the inputs explicitly |

### Test factories, not mocks

For tests that need a complex real model, build a small factory in
`spec/support/factories/`:

```ruby
module Factories
  def self.schema_with_types(types, namespace: "http://example.com/ns")
    schema = Lutaml::Xml::Schema::Xsd::Schema.new(
      target_namespace: namespace,
    )
    types.each { |t| schema.complex_type(t) }
    schema
  end
end

RSpec.configure { |c| c.include Factories }
```

This keeps specs short while using real classes.

### Spec discovery note

The default `rake spec` task only runs **88 of 1375** examples (a
separate TODO.clean/09 covers investigation). Once the anti-patterns are
gone, all examples should be discoverable; the spec discovery fix may
uncover additional latent anti-patterns. Plan for a second sweep after
TODO.clean/09.

## Files affected

All spec files listed in the problem statement. Plus a new
`spec/support/factories.rb` and `spec/support/factories/` directory.

## Acceptance criteria

- [ ] Zero `double(` calls in `spec/`
- [ ] Zero `instance_double(` calls in `spec/`
- [ ] Zero `instance_variable_set` calls in `spec/`
- [ ] Zero `instance_variable_get` calls in `spec/`
- [ ] Zero `.send(:` calls invoking private methods in `spec/`
- [ ] Zero `respond_to?` in `spec/`
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- No new specs — the existing specs are the spec. The task is to
  rewrite them to use real models.

## Risks

- **Time-consuming.** This is a large refactor. Scope it per file, not
  per anti-pattern occurrence.
- **Loss of "interaction" coverage.** Tests that asserted "method X was
  called" with doubles no longer assert that. This is intentional:
  interactions are not behavior. The new specs assert state and
  return values, which is what real callers care about.
- **Test fixtures may need extending.** If a real model needs more
  attributes set than the original double did, the fixture must grow.
