#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lutaml/xsd"

# Parse metaschema.xsd - a simpler example without complex dependencies
xsd_file = File.expand_path("../spec/fixtures/metaschema.xsd", __dir__)
xsd_content = File.read(xsd_file)

puts "=" * 80
puts "Parsing metaschema.xsd with Array-Based Schema Mappings"
puts "=" * 80
puts

begin
  # Parse without schema mappings first (local file, no external dependencies)
  parsed_schema = Lutaml::Xsd.parse(
    xsd_content,
    location: File.dirname(xsd_file)
  )

  # Display schema information
  puts "SCHEMA INFORMATION"
  puts "-" * 80
  puts "Target Namespace: #{parsed_schema.target_namespace}"
  puts "Element Form Default: #{parsed_schema.element_form_default || "unqualified"}"
  puts "Attribute Form Default: #{parsed_schema.attribute_form_default || "unqualified"}"
  puts

  # Display imports
  if parsed_schema.import && !parsed_schema.import.empty?
    puts "IMPORTS (#{parsed_schema.import.size})"
    puts "-" * 80
    parsed_schema.import.each do |imp|
      puts "  Namespace: #{imp.namespace}"
      puts "  Schema Location: #{imp.schema_location}" if imp.schema_location
      puts
    end
  end

  # Display includes
  if parsed_schema.include && !parsed_schema.include.empty?
    puts "INCLUDES (#{parsed_schema.include.size})"
    puts "-" * 80
    parsed_schema.include.each do |inc|
      puts "  Schema Location: #{inc.schema_location}"
    end
    puts
  end

  # Display elements
  if parsed_schema.element && !parsed_schema.element.empty?
    puts "ELEMENTS (#{parsed_schema.element.size})"
    puts "-" * 80
    parsed_schema.element.each_with_index do |element, idx|
      puts "  [#{idx + 1}] Element: #{element.name}"
      puts "      Type: #{element.type}" if element.type
      puts "      Ref: #{element.ref}" if element.ref
      puts "      Min Occurs: #{element.min_occurs || 1}"
      puts "      Max Occurs: #{element.max_occurs || 1}"
      puts "      Substitution Group: #{element.substitution_group}" if element.substitution_group

      # Show documentation if available
      if element.annotation
        docs = []
        element.annotation.documentation&.each do |doc|
          docs << doc.content.strip if doc.content
        end
        puts "      Documentation: #{docs.join(" ")}" unless docs.empty?
      end

      puts
    end
  end

  # Display complex types
  if parsed_schema.complex_type && !parsed_schema.complex_type.empty?
    puts "COMPLEX TYPES (#{parsed_schema.complex_type.size})"
    puts "-" * 80
    parsed_schema.complex_type.each_with_index do |ct, idx|
      puts "  [#{idx + 1}] ComplexType: #{ct.name}"
      puts "      Abstract: #{ct.abstract}" if ct.abstract
      puts "      Mixed: #{ct.mixed}" if ct.mixed

      # Show sequence elements if available
      if ct.sequence&.element && !ct.sequence.element.empty?
        puts "      Sequence Elements (#{ct.sequence.element.size}):"
        ct.sequence.element.each do |elem|
          elem_info = "        - #{elem.name || elem.ref}"
          elem_info += " (type: #{elem.type})" if elem.type
          elem_info += " [#{elem.min_occurs || 1}..#{elem.max_occurs || 1}]"
          puts elem_info
        end
      end

      # Show choice elements if available
      if ct.choice&.element && !ct.choice.element.empty?
        puts "      Choice Elements (#{ct.choice.element.size}):"
        ct.choice.element.each do |elem|
          elem_info = "        - #{elem.name || elem.ref}"
          elem_info += " (type: #{elem.type})" if elem.type
          puts elem_info
        end
      end

      # Show attributes
      if ct.attribute && !ct.attribute.empty?
        puts "      Attributes (#{ct.attribute.size}):"
        ct.attribute.each do |attr|
          attr_info = "        - #{attr.name || attr.ref}"
          attr_info += " (type: #{attr.type})" if attr.type
          attr_info += " [#{attr.use}]" if attr.use
          puts attr_info
        end
      end

      # Show attribute groups
      if ct.attribute_group && !ct.attribute_group.empty?
        puts "      Attribute Groups (#{ct.attribute_group.size}):"
        ct.attribute_group.each do |ag|
          puts "        - #{ag.name || ag.ref}"
        end
      end

      # Show complex content if available
      if ct.complex_content
        puts "      Complex Content:"
        if ct.complex_content.extension
          ext = ct.complex_content.extension
          puts "        Extension base: #{ext.base}"
          puts "        Extension adds #{ext.sequence.element.size} element(s)" if ext.sequence&.element && !ext.sequence.element.empty?
        end
        puts "        Restriction base: #{ct.complex_content.restriction.base}" if ct.complex_content.restriction
      end

      # Show simple content if available
      if ct.simple_content
        puts "      Simple Content:"
        puts "        Extension base: #{ct.simple_content.extension.base}" if ct.simple_content.extension
        puts "        Restriction base: #{ct.simple_content.restriction.base}" if ct.simple_content.restriction
      end

      puts
    end
  end

  # Display simple types
  if parsed_schema.simple_type && !parsed_schema.simple_type.empty?
    puts "SIMPLE TYPES (#{parsed_schema.simple_type.size})"
    puts "-" * 80
    parsed_schema.simple_type.each_with_index do |st, idx|
      puts "  [#{idx + 1}] SimpleType: #{st.name}"

      # Show restriction if available
      if st.restriction
        puts "      Restriction base: #{st.restriction.base}"

        # Show enumerations
        if st.restriction.enumeration && !st.restriction.enumeration.empty?
          puts "      Enumerations (#{st.restriction.enumeration.size}):"
          st.restriction.enumeration.first(5).each do |enum|
            puts "        - #{enum.value}"
          end
          puts "        ... (#{st.restriction.enumeration.size - 5} more)" if st.restriction.enumeration.size > 5
        end

        # Show patterns
        if st.restriction.pattern
          patterns = [st.restriction.pattern].flatten
          unless patterns.empty?
            puts "      Patterns:"
            patterns.each do |pattern|
              pattern_val = pattern.respond_to?(:value) ? pattern.value : pattern.to_s
              puts "        - #{pattern_val}"
            end
          end
        end

        # Show length constraints
        if st.restriction.min_length
          min_val = st.restriction.min_length.respond_to?(:value) ? st.restriction.min_length.value : st.restriction.min_length
          puts "      Min Length: #{min_val}"
        end
        if st.restriction.max_length
          max_val = st.restriction.max_length.respond_to?(:value) ? st.restriction.max_length.value : st.restriction.max_length
          puts "      Max Length: #{max_val}"
        end
        if st.restriction.length
          len_val = st.restriction.length.respond_to?(:value) ? st.restriction.length.value : st.restriction.length
          puts "      Length: #{len_val}"
        end
      end

      # Show union if available
      puts "      Union member types: #{st.union.member_types}" if st.union

      # Show list if available
      puts "      List item type: #{st.list.item_type}" if st.list

      puts
    end
  end

  # Display attribute groups
  if parsed_schema.attribute_group && !parsed_schema.attribute_group.empty?
    puts "ATTRIBUTE GROUPS (#{parsed_schema.attribute_group.size})"
    puts "-" * 80
    parsed_schema.attribute_group.each_with_index do |ag, idx|
      puts "  [#{idx + 1}] AttributeGroup: #{ag.name || ag.ref}"
      if ag.attribute && !ag.attribute.empty?
        puts "      Attributes (#{ag.attribute.size}):"
        ag.attribute.each do |attr|
          puts "        - #{attr.name || attr.ref} (type: #{attr.type})"
        end
      end
      puts
    end
  end

  # Display groups
  if parsed_schema.group && !parsed_schema.group.empty?
    puts "GROUPS (#{parsed_schema.group.size})"
    puts "-" * 80
    parsed_schema.group.each_with_index do |grp, idx|
      puts "  [#{idx + 1}] Group: #{grp.name || grp.ref}"
      if grp.sequence&.element
        puts "      Sequence Elements (#{grp.sequence.element.size}):"
        grp.sequence.element.each do |elem|
          puts "        - #{elem.name || elem.ref}"
        end
      end
      if grp.choice&.element
        puts "      Choice Elements (#{grp.choice.element.size}):"
        grp.choice.element.each do |elem|
          puts "        - #{elem.name || elem.ref}"
        end
      end
      puts
    end
  end

  puts "=" * 80
  puts "Summary Statistics"
  puts "=" * 80
  puts "Total Elements: #{parsed_schema.element&.size || 0}"
  puts "Total Complex Types: #{parsed_schema.complex_type&.size || 0}"
  puts "Total Simple Types: #{parsed_schema.simple_type&.size || 0}"
  puts "Total Attribute Groups: #{parsed_schema.attribute_group&.size || 0}"
  puts "Total Groups: #{parsed_schema.group&.size || 0}"
  puts
  puts "Parsing completed successfully!"
  puts "=" * 80
rescue StandardError => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
