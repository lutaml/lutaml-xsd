# Replace `rescue NoMethodError` with explicit type dispatch in RngToXsdConverter

## Problem

`lib/lutaml/xsd/rng_to_xsd_converter.rb:1154-1163` contains:

```ruby
def get_attribute_child(attr)
  pattern_types.each do |type_name|
    child = attr.public_send(type_name)
    return child if child && !child.is_a?(Array) &&
                    !child.is_a?(Lutaml::Model::UninitializedClass)
  rescue NoMethodError
    next
  end
  nil
end
```

Blanket-rescuing `NoMethodError` is the "ask forgiveness" style applied to a
place where it is wrong: the method swallows real programming errors (a typo
in `type_name`, a renamed reader, an unrelated `NoMethodError` raised inside
the reader body).

The right fix is to dispatch on the actual RNG node type, not to guess by
probing method names.

## Solution

Replace the rescue loop with a `{ class => reader }` registry and `is_a?`
dispatch. The registry encodes the mapping "for an RNG node of class X, read
attribute Y".

```ruby
PATTERN_TYPE_READERS = {
  Rng::Element   => :element,
  Rng::Choice    => :choice,
  Rng::Interleave => :interleave,
  Rng::Group     => :group,
  Rng::Optional  => :optional,
  Rng::ZeroOrMore => :zero_or_more,
  Rng::OneOrMore => :one_or_more,
  Rng::Ref       => :ref,
  Rng::Data      => :data,
  Rng::Value     => :value,
  Rng::List      => :list,
  Rng::Text      => :text,
  Rng::Empty     => :empty
}.freeze

def get_attribute_child(attr)
  _, reader = PATTERN_TYPE_READERS.find { |klass, _| attr.is_a?(klass) }
  return nil unless reader

  child = attr.public_send(reader)
  return nil if child.nil? || child.is_a?(Array) ||
                child.is_a?(Lutaml::Model::UninitializedClass)
  child
end
```

This is open/closed: adding a new RNG pattern type means adding one entry to
the registry, not editing the method.

## Discovery step

Before writing the registry, run `Rng.constants` and inspect each class's
public methods to confirm the reader names. The previous `pattern_types` array
already enumerates them; cross-check against `Rng`'s actual interface.

If a reader is optional on a class (some instances respond, others don't),
model that explicitly with a sentinel value rather than rescuing.

## Files affected

- `lib/lutaml/xsd/rng_to_xsd_converter.rb` (rewrite `get_attribute_child`;
  remove `pattern_types` if it becomes redundant with the registry)
- After TODO.clean/02: this method moves to a collaborator
  (probably `AttributeBuilder`). The registry moves with it.

## Acceptance criteria

- [ ] Zero `rescue NoMethodError` in `lib/`
- [ ] `get_attribute_child` returns the same value for every RNG input as
  before (verified by an A/B spec: run the old and new versions over the
  fixture corpus, assert identical results)
- [ ] Registry-based dispatch covers every `Rng::*` class that can appear as
  an attribute child
- [ ] Unknown RNG class returns `nil` (not raise)
- [ ] `bundle exec rake` passes

## Specs required

- `spec/lutaml/xsd/rng_to_xsd_converter_spec.rb` — add focused specs for
  `get_attribute_child` covering each registry entry. Use real `Rng::*`
  instances, not doubles.

## Risks

- If the registry misses a class that the old rescue-based loop handled by
  accident, behavior regresses. Mitigation: the A/B spec on the fixture
  corpus catches this.
