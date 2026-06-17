# Split SchemaExporter into focused collaborators

## Problem

`lib/lutaml/xsd/schema_exporter.rb` is small (~121 lines) but mixes three
distinct concerns:

1. **Statistics computation** — counting types, elements, namespaces,
   schemas
2. **Formatting** — rendering those statistics as text, JSON, YAML
3. **Documentation extraction** — pulling docstrings out of schemas for
   display

This violates SRP. As soon as one of these concerns grows (e.g., adding
HTML output, adding per-namespace breakdown, extracting more
documentation sources), the file will balloon.

## Solution

Split into three focused collaborators under a
`Lutaml::Xsd::Stats` namespace:

```ruby
module Lutaml
  module Xsd
    module Stats
      # Pure computation: repository → stats hash
      class Collector
        def initialize(repository)
          @repository = repository
        end

        def call
          { ... }
        end
      end

      # Pure formatting: stats hash → string in requested format
      class Formatter
        def self.format(stats, format:)
          case format
          when :text then TextFormat.new(stats).render
          when :json then JSONFormat.new(stats).render
          when :yaml then YAMLFormat.new(stats).render
          else raise ArgumentError, "Unknown format: #{format}"
          end
        end
      end

      # Pure docstring extraction
      class DocumentationExtractor
        def self.from_schema(schema)
          # ...
        end
      end
    end
  end
end
```

### Open/closed formatting

The `case` in `Formatter` is a violation of OCP. Replace with a registry:

```ruby
module Stats
  module Formatters
    REGISTRY = {}  # format => class

    def self.register(format, klass)
      REGISTRY[format] = klass
    end

    def self.for(format)
      REGISTRY.fetch(format) do
        raise ArgumentError, "Unknown format: #{format}"
      end
    end

    class TextFormat; end
    class JsonFormat; end
    class YamlFormat; end

    register :text, TextFormat
    register :json, JsonFormat
    register :yaml, YamlFormat
  end
end
```

Adding a new format (e.g., HTML) means adding `class HtmlFormat` and
`register :html, HtmlFormat` — zero edits to existing classes.

### SchemaExporter becomes a thin entry point

```ruby
class SchemaExporter
  def initialize(repository)
    @repository = repository
  end

  def statistics
    Stats::Collector.new(@repository).call
  end

  def export_statistics(format:)
    Stats::Formatter.format(statistics, format: format)
  end

  def namespace_summary
    statistics[:namespaces]
  end

  def elements_by_namespace(namespace_uri:)
    statistics[:elements].select { |e| e[:namespace] == namespace_uri }
  end
end
```

## Files affected

- NEW: `lib/lutaml/xsd/stats.rb` (parent namespace with autoloads)
- NEW: `lib/lutaml/xsd/stats/collector.rb`
- NEW: `lib/lutaml/xsd/stats/formatter.rb`
- NEW: `lib/lutaml/xsd/stats/documentation_extractor.rb`
- NEW: `lib/lutaml/xsd/stats/formatters/text_format.rb`
- NEW: `lib/lutaml/xsd/stats/formatters/json_format.rb`
- NEW: `lib/lutaml/xsd/stats/formatters/yaml_format.rb`
- `lib/lutaml/xsd/schema_exporter.rb` (slimmed to delegator)
- `lib/lutaml/xsd.rb` (autoload entries)

## Acceptance criteria

- [ ] Each collaborator under 80 lines
- [ ] `SchemaExporter` under 50 lines (delegator only)
- [ ] Formatter registry allows new formats without modifying existing
  classes
- [ ] All existing specs pass
- [ ] `bundle exec rake` passes
- [ ] `bundle exec rubocop` clean

## Specs required

- `spec/lutaml/xsd/stats/collector_spec.rb` — input repository → output
  stats hash (no formatting concerns)
- `spec/lutaml/xsd/stats/formatter_spec.rb` — for each registered
  format, assert output structure
- `spec/lutaml/xsd/stats/documentation_extractor_spec.rb` — schemas with
  and without docstrings
- Registry spec — assert all three formats are registered; assert
  `:unknown_format` raises

## Risks

- Low. The current API is preserved (delegators stay), so callers don't
  need changes immediately. After one release, callers can migrate to
  the namespace collaborators directly.
