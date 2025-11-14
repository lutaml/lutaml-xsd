# Lutaml-XSD Examples

This directory contains practical examples demonstrating various features of lutaml-xsd.

## Directory Structure

```
examples/
├── validation/                      # XML validation examples
│   ├── sample_schemas/             # Sample XSD schemas and XML files
│   │   ├── person.xsd              # Simple person schema
│   │   ├── person_valid.xml        # Valid person XML
│   │   ├── person_invalid.xml      # Invalid person XML
│   │   ├── company.xsd             # Complex company schema
│   │   └── company.xml             # Company XML instance
│   ├── config/                     # Sample validation configurations
│   │   ├── strict_validation.yml   # Strict validation config
│   │   └── lenient_validation.yml  # Lenient validation config
│   ├── validate_xml_basic.rb       # Basic validation example
│   ├── validate_xml_advanced.rb    # Advanced validation with config
│   └── validate_with_suggestions.rb # Error suggestions demo
├── lxr_build.rb                    # LXR package building
├── lxr_search.rb                   # Type searching
└── lxr_type_resolution.rb          # Type resolution

```

## Validation Examples

### Basic XML Validation (`validation/validate_xml_basic.rb`)

Demonstrates fundamental XML validation workflow:
- Building an LXR package from XSD schemas
- Loading schema repositories
- Validating XML files
- Displaying validation results

**Usage:**
```bash
ruby examples/validation/validate_xml_basic.rb
```

**Key Concepts:**
- Creating schema repositories from XSD files
- Building LXR packages for reuse
- Basic validation workflow
- Error reporting

### Advanced Validation (`validation/validate_xml_advanced.rb`)

Shows advanced validation features:
- Batch validation of multiple files
- Custom validation configurations
- Error filtering and grouping
- JSON output format

**Usage:**
```bash
ruby examples/validation/validate_xml_advanced.rb
```

**Key Concepts:**
- Multi-file validation
- Configuration-driven validation
- Error categorization
- Structured output formats

### Validation with Suggestions (`validation/validate_with_suggestions.rb`)

Demonstrates the error enhancement system:
- Fuzzy matching for type names
- Detailed error messages with context
- Troubleshooting suggestions
- Namespace mismatch detection

**Usage:**
```bash
ruby examples/validation/validate_with_suggestions.rb
```

**Key Concepts:**
- Enhanced error reporting
- Suggestion system
- Type name fuzzy matching
- Namespace troubleshooting

## Package Examples

### LXR Package Building (`lxr_build.rb`)

Comprehensive guide to building LXR packages:
- Building from XSD files directly
- Different serialization formats (Marshal, JSON, YAML)
- Package metadata customization
- Smart caching for development

**Usage:**
```bash
ruby examples/lxr_build.rb
```

**Key Concepts:**
- LXR package structure
- Serialization format comparison
- Package validation
- Performance optimization

**Output:** Creates packages in `examples/output/`:
- `schemas_marshal.lxr` - Fastest, binary format
- `schemas_json.lxr` - Portable, text format
- `schemas_yaml.lxr` - Human-readable format
- `cached_schemas.lxr` - Smart cache example

### LXR Package Searching (`lxr_search.rb`)

Demonstrates searching capabilities:
- Search types by name
- Filter by namespace
- Filter by category
- Documentation search
- Batch queries

**Usage:**
```bash
ruby examples/lxr_search.rb
```

**Key Concepts:**
- Type searching with relevance ranking
- Namespace-aware filtering
- Category-based filtering
- Documentation search

### Type Resolution (`lxr_type_resolution.rb`)

Shows type resolution features:
- Multiple name formats (prefixed, Clark notation)
- Type hierarchy analysis
- Dependency tracking
- Quick existence checks

**Usage:**
```bash
ruby examples/lxr_type_resolution.rb
```

**Key Concepts:**
- Qualified name parsing
- Type resolution strategies
- Hierarchy navigation
- Dependency graphs

## Sample Schemas

### Person Schema (`validation/sample_schemas/person.xsd`)

Simple schema demonstrating:
- Basic complex types
- Simple type restrictions
- Pattern validation (email)
- Range validation (age)
- Optional elements (address)

### Company Schema (`validation/sample_schemas/company.xsd`)

Complex schema demonstrating:
- Schema imports
- Type extension (Employee extends Person)
- ID/IDREF references
- Multiple namespaces
- Hierarchical structures

## Running All Examples

To run all validation examples:
```bash
cd examples/validation
ruby validate_xml_basic.rb
ruby validate_xml_advanced.rb
ruby validate_with_suggestions.rb
```

To run all package examples:
```bash
cd examples
ruby lxr_build.rb
ruby lxr_search.rb
ruby lxr_type_resolution.rb
```

## Configuration Files

### Strict Validation (`validation/config/strict_validation.yml`)

Configuration for strict validation:
- Fail-fast mode (stop on first error)
- Enhanced error messages
- Full context display
- All validation rules enabled

### Lenient Validation (`validation/config/lenient_validation.yml`)

Configuration for lenient validation:
- Collect all errors before failing
- Basic error messages
- Minimal validation rules
- Suitable for development

## Common Patterns

### Building a Package

```ruby
repository = Lutaml::Xsd::SchemaRepository.new
repository.instance_variable_set(:@files, [schema_file])
repository.parse.resolve

repository.to_package(
  "output.lxr",
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal
)
```

### Loading and Using a Package

```ruby
repository = Lutaml::Xsd::SchemaRepository.from_package("schemas.lxr")
validator = Lutaml::Xsd::Validator.new(repository)

result = validator.validate(xml_content)
if result.valid?
  puts "Valid!"
else
  result.errors.each { |e| puts e.message }
end
```

### Searching for Types

```ruby
searcher = Lutaml::Xsd::TypeSearcher.new(repository)
results = searcher.search("Person", in_field: "both", limit: 10)

results.each do |result|
  puts "#{result.qualified_name} - #{result.relevance_score}"
end
```

### Resolving Types

```ruby
result = repository.find_type("p:PersonType")
if result.resolved?
  puts "Found: #{result.definition.class}"
else
  puts "Not found: #{result.error_message}"
end
```

## Integration with CLI

All examples demonstrate features also available through the CLI:

```bash
# Build package
lutaml-xsd package create schemas.yml output.lxr

# Validate XML
lutaml-xsd validate file.xml schemas.lxr

# Search types
lutaml-xsd search Person schemas.lxr

# Get type information
lutaml-xsd type p:PersonType schemas.lxr
```

## Troubleshooting

### Package not loading correctly

Ensure the package was built with `resolution_mode: :resolved`:
```ruby
repository.to_package(path, resolution_mode: :resolved)
```

### Type not found

Check namespace configuration:
```ruby
repository.configure_namespace(prefix: "p", uri: "http://example.com/person")
```

### Validation errors

The validation framework is currently in development. Some features may not be fully implemented yet.

## Next Steps

1. Read the [Architecture Documentation](../docs/PROJECT_ARCHITECTURE_SUMMARY.md)
2. Explore the [API Reference](../docs/RUBY_API.adoc)
3. Check the [CLI Commands](../docs/quick-reference/cli-commands-cheatsheet.adoc)
4. Review [Serialization Guide](../docs/SERIALIZATION.adoc)

## Contributing

When adding new examples:
1. Follow the existing structure and naming conventions
2. Include comprehensive comments explaining each step
3. Add error handling for common cases
4. Reference related documentation
5. Update this README with the new example