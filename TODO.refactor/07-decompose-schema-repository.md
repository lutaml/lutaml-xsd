# Decompose SchemaRepository (1227-line god object) into focused service objects

## Problem
SchemaRepository violates SRP/MECE — it handles parsing, package loading,
namespace management, type resolution, statistics, export, circular dependency
checking, RNG conversion, and more. At 1227 lines it's unmaintainable.

## Solution
Extract service objects while keeping SchemaRepository as a thin coordinator.
Each service owns a single responsibility.

### Extracted services:

1. **SchemaParser** — parse XSD/RNG files, manage the parsed_schemas store
   - `parse_file(path)`, `parse_xsd(path)`, `parse_rng(path)`
   - Owns `@parsed_schemas` BasicStore

2. **PackageLoader** — load LXR packages with conflict detection
   - `load_package(path)`, `load_with_conflict_detection(configs)`
   - Extracted from `load_base_packages`, `load_base_packages_with_conflict_detection`

3. **SchemaQueryService** — type/element/attribute search
   - `find_type(qname)`, `find_element(qname)`, `find_group(qname)`
   - `find_attribute(qname)`, `find_attribute_group(qname)`
   - Delegates to TypeIndex

4. **SchemaExporter** — statistics, export, package creation
   - `statistics`, `export_statistics(format)`, `to_package(path)`
   - Extracted from statistics/export methods

### SchemaRepository becomes a coordinator:
```ruby
class SchemaRepository
  attr_reader :parser, :loader, :query, :exporter

  def initialize(**attrs)
    @parser = SchemaParser.new(self)
    @loader = PackageLoader.new(self)
    @query = SchemaQueryService.new(self)
    @exporter = SchemaExporter.new(self)
  end

  def parse(...) = @parser.parse(...)
  def find_type(...) = @query.find_type(...)
  # etc.
end
```

## Files affected
- NEW: `lib/lutaml/xsd/schema_parser.rb`
- NEW: `lib/lutaml/xsd/package_loader.rb`
- NEW: `lib/lutaml/xsd/schema_query_service.rb`
- NEW: `lib/lutaml/xsd/schema_exporter.rb`
- `lib/lutaml/xsd/schema_repository.rb` (slimmed down to coordinator)
- All specs referencing SchemaRepository methods

## Acceptance criteria
- [ ] SchemaRepository under 300 lines (coordinator only)
- [ ] Each service under 300 lines
- [ ] All public API preserved (backward compatible)
- [ ] `bundle exec rake` passes
