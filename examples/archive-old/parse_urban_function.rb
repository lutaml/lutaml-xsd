#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/lutaml/xsd'

# Parse urbanFunction.xsd with schema mappings demonstrating:
# 1. Mapping relative paths to local files
# 2. Mapping URL prefixes to local directory structures
# 3. Auto-generating bare filename mappings (DRY principle)
xsd_file = File.expand_path('../spec/fixtures/i-ur/urbanFunction.xsd', __dir__)
xsd_content = File.read(xsd_file)

# Define schema mappings using array-based structure with from/to keys
# NOTE: Order matters! More specific patterns should come first.
# IMPORTANT: Only map what we have locally - let URL fetching work for everything else!
schema_mappings = [
  # Map specific relative path to local file (urbanFunction.xsd imports)
  { from: '../../uro/3.2/urbanObject.xsd',
    to: File.expand_path('../spec/fixtures/i-ur/urbanObject.xsd', __dir__) },

  # Map xlink relative paths to codesynthesis directory (handles any number of ../)
  { from: %r{(?:\.\./)+xlink/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/xlink/\\1', __dir__) },

  # Map GML relative paths to codesynthesis directory (e.g., ../../../../gml/3.2.1/gml.xsd)
  { from: %r{(?:\.\./)+gml/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/gml/\\1', __dir__) },

  # Map ISO relative paths to codesynthesis directory (e.g., ../../iso/19139/20070417/gmd/gmd.xsd)
  { from: %r{(?:\.\./)+iso/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/\\1', __dir__) },

  # Map simple relative paths for GMD, GSS, GTS, GSR, GCO, GMX (e.g., ../gmd/metadataApplication.xsd)
  { from: %r{^\.\./gmd/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gmd/\\1', __dir__) },
  { from: %r{^\.\./gss/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gss/\\1', __dir__) },
  { from: %r{^\.\./gts/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gts/\\1', __dir__) },
  { from: %r{^\.\./gsr/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gsr/\\1', __dir__) },
  { from: %r{^\.\./gco/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gco/\\1', __dir__) },
  { from: %r{^\.\./gmx/(.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gmx/\\1', __dir__) },

  # Map specific bare .xsd filenames to codesynthesis-gml-3.2.1 directories
  # GML files (all files in gml/3.2.1)
  { from: /^(basicTypes|coordinateOperations|coordinateReferenceSystems|coordinateSystems|coverage|datums|defaultStyle|deprecatedTypes|dictionary|direction|dynamicFeature|feature|geometryAggregates|geometryBasic0d1d|geometryBasic2d|geometryComplexes|geometryPrimitives|gml|gmlBase|grids|measures|observation|referenceSystems|temporal|temporalReferenceSystems|temporalTopology|topology|units|valueObjects)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/gml/3.2.1/\\1.xsd', __dir__) },

  # GMD files (main schema and included files in iso/19139/20070417/gmd)
  { from: /^(applicationSchema|citation|constraints|content|dataQuality|distribution|extent|freeText|gmd|identification|maintenance|metadataApplication|metadataEntity|metadataExtension|portrayalCatalogue|referenceSystem|spatialRepresentation)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gmd/\\1.xsd', __dir__) },

  # GSS files (geometric schema in iso/19139/20070417/gss)
  { from: /^(geometry|gss)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gss/\\1.xsd', __dir__) },

  # GTS files (temporal schema in iso/19139/20070417/gts)
  { from: /^(gts|temporalObjects)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gts/\\1.xsd', __dir__) },

  # GSR files (spatial referencing in iso/19139/20070417/gsr)
  { from: /^(gsr|spatialReferencing)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gsr/\\1.xsd', __dir__) },

  # GCO files (common objects in iso/19139/20070417/gco)
  { from: /^(basicTypes|gco|gcoBase)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gco/\\1.xsd', __dir__) },

  # GMX files (extended types in iso/19139/20070417/gmx)
  { from: /^(catalogues|codelistItem|crsItem|extendedTypes|gmx|gmxUsage|uomItem)\.xsd$/,
    to: File.expand_path('../spec/fixtures/codesynthesis-gml-3.2.1/iso/19139/20070417/gmx/\\1.xsd', __dir__) },

  # W3C SMIL20 files
  { from: /^(smil20-.*|smil20|xml-mod|rdf)\.xsd$/,
    to: File.expand_path('../spec/fixtures/smil20/\\1.xsd', __dir__) },

  # Map ISO TC211 HTTPS URLs to local directory structure
  { from: %r{https://schemas\.isotc211\.org/(.+)},
    to: File.expand_path('../spec/fixtures/isotc211/\\1', __dir__) },

  # Map ISO TC211 relative paths (e.g., ../../../../19136/-/gml/1.0/gml.xsd)
  { from: %r{(?:\.\./)+(\d{5}/.+\.xsd)$},
    to: File.expand_path('../spec/fixtures/isotc211/\\1', __dir__) }
]

# NOTE: We removed overly broad mappings to allow URL fetching to work!
# The system will automatically fetch schemas from their schemaLocation URLs
# when no local mapping matches.

puts '=' * 80
puts 'Parsing urbanFunction.xsd with Minimal Schema Mappings'
puts '=' * 80
puts
puts 'This example demonstrates:'
puts '  - Mapping specific relative paths to local files'
puts '  - Mapping URL prefixes to local directory structures using regex'
puts '  - Letting URL fetching handle remote schemas automatically'
puts
puts "Schema Mappings Configured: #{schema_mappings.size} total"
puts '  - 1 specific relative path (urbanObject.xsd)'
puts '  - 1 xlink relative path pattern (../../xlink/...)'
puts '  - 1 GML relative path pattern (../../gml/...)'
puts '  - 1 ISO relative path pattern (../../iso/...)'
puts '  - 6 simple relative path patterns (../gmd/, ../gss/, ../gts/, ../gsr/, ../gco/, ../gmx/)'
puts '  - 8 bare .xsd filename patterns (64 files total from codesynthesis-gml-3.2.1)'
puts '    * GML (29 files), GMD (17 files), GSS (2 files), GTS (2 files)'
puts '    * GSR (2 files), GCO (3 files), GMX (7 files), SMIL20 (2 files)'
puts '  - 1 ISO TC211 HTTPS URL pattern (maps to codesynthesis directory)'
puts
puts 'Note: Minimal mappings allow the system to fetch remote schemas'
puts '      from their schemaLocation URLs when no local mapping matches.'
puts '=' * 80
puts

begin
  parsed_schema = Lutaml::Xsd.parse(
    xsd_content,
    location: File.dirname(xsd_file),
    schema_mappings: schema_mappings
  )

  # Display schema information
  puts 'SCHEMA INFORMATION'
  puts '-' * 80
  puts "Target Namespace: #{parsed_schema.target_namespace}"
  puts "Element Form Default: #{parsed_schema.element_form_default || 'unqualified'}"
  puts

  # Display imports
  if parsed_schema.imports && !parsed_schema.imports.empty?
    puts "IMPORTS (#{parsed_schema.imports.size})"
    puts '-' * 80
    parsed_schema.imports.each do |imp|
      puts "  Namespace: #{imp.namespace}"
      puts "  Schema Location: #{imp.schema_path}" if imp.schema_path
    end
    puts
  end

  # Display includes
  if parsed_schema.includes && !parsed_schema.includes.empty?
    puts "INCLUDES (#{parsed_schema.includes.size})"
    puts '-' * 80
    parsed_schema.includes.each do |inc|
      puts "  Schema Location: #{inc.schema_path}"
    end
    puts
  end

  # Display top-level elements (limit output)
  if parsed_schema.element && !parsed_schema.element.empty?
    puts "ELEMENTS (#{parsed_schema.element.size})"
    puts '-' * 80
    parsed_schema.element.first(10).each_with_index do |element, idx|
      puts "  [#{idx + 1}] Element: #{element.name}"
      puts "      Type: #{element.type}" if element.type
      puts "      Substitution Group: #{element.substitution_group}" if element.substitution_group
    end
    puts "  ... (showing first 10 of #{parsed_schema.element.size})" if parsed_schema.element.size > 10
    puts
  end

  # Display complex types (limit output)
  if parsed_schema.complex_type && !parsed_schema.complex_type.empty?
    puts "COMPLEX TYPES (#{parsed_schema.complex_type.size})"
    puts '-' * 80
    parsed_schema.complex_type.first(5).each_with_index do |ct, idx|
      puts "  [#{idx + 1}] ComplexType: #{ct.name}"

      # Show sequence elements if available
      puts "      Sequence Elements: #{ct.sequence.element.size}" if ct.sequence&.element && !ct.sequence.element.empty?

      # Show attributes if available
      puts "      Attributes: #{ct.attribute.size}" if ct.attribute && !ct.attribute.empty?

      # Show complex content if available
      next unless ct.complex_content

      puts "      Extension base: #{ct.complex_content.extension.base}" if ct.complex_content.extension
    end
    puts "  ... (showing first 5 of #{parsed_schema.complex_type.size})" if parsed_schema.complex_type.size > 5
    puts
  end

  # Display summary
  puts '=' * 80
  puts 'Summary Statistics'
  puts '=' * 80
  puts "Total Elements: #{parsed_schema.element&.size || 0}"
  puts "Total Complex Types: #{parsed_schema.complex_type&.size || 0}"
  puts "Total Simple Types: #{parsed_schema.simple_type&.size || 0}"
  puts "Total Imports: #{parsed_schema.imports&.size || 0}"
  puts "Total Includes: #{parsed_schema.includes&.size || 0}"
  puts
  puts '✓ Parsing completed successfully!'
  puts '=' * 80
  puts
  puts 'Key Takeaways:'
  puts '  1. Keep mappings minimal - only map what you have locally'
  puts '  2. Let URL fetching work for remote schemas (sweCommon, CityGML, etc.)'
  puts '  3. Use exact strings for specific relative path mappings'
  puts '  4. Use regex patterns for URL prefix to directory mappings'
  puts '  5. Mappings are processed in order (first match wins)'
  puts '  6. Overly broad mappings prevent automatic URL fetching'
  puts
rescue StandardError => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts
  puts 'Backtrace:'
  puts e.backtrace.first(10).join("\n")
  exit 1
end
