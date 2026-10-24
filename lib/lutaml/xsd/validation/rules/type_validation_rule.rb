# frozen_string_literal: true

require_relative "../validation_rule"
require_relative "../xsd_regex"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # TypeValidationRule validates element types
        #
        # This rule checks:
        # - Resolves element type from schema
        # - Validates simple type content
        # - Validates complex type content
        # - Delegates to base type validators and facet validators
        #
        # Based on Jing validator type validation algorithm.
        #
        # @example Using the rule
        #   rule = TypeValidationRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Type Validation
        class TypeValidationRule < ValidationRule
          include EngineBacked

          # Lexicographic (months, seconds) ordering per XSD 1.0
          # Appendix E; Comparable gives the range facets >= > <= <.
          DurationKey = Struct.new(:months, :seconds) do
            include Comparable

            def <=>(other)
              [months, seconds] <=> [other.months, other.seconds]
            end
          end

          RANGE_FACETS = {
            "min_inclusive" => ->(value, bound) { value >= bound },
            "min_exclusive" => ->(value, bound) { value > bound },
            "max_inclusive" => ->(value, bound) { value <= bound },
            "max_exclusive" => ->(value, bound) { value < bound },
          }.freeze
          # Rule category
          #
          # @return [Symbol] :type
          def category
            :type
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element content against XSD type definitions"
          end

          # Validate element type
          #
          # Validates the element's content against its type definition,
          # handling both simple and complex types.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @param collector [ResultCollector] Collector for validation
          #   results
          # @return [void]
          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless schema_element

            return if xsi_nil_handled?(xml_element, schema_element, collector)

            type_def = resolve_element_type(schema_element, repository)
            if xsi_type_name(xml_element)
              type_def = resolve_xsi_type(xsi_type_name(xml_element),
                                          repository)
              unless type_def
                report_error(
                  collector,
                  code: "xsi_type_unknown",
                  message: "xsi:type '#{xsi_type_name(xml_element)}' does " \
                           "not resolve to a known type definition",
                  location: xml_element.xpath,
                  context: { xsi_type: xsi_type_name(xml_element) },
                )
                return
              end

              if override_blocked?(schema_element, type_def, repository)
                report_error(
                  collector,
                  code: "xsi_type_blocked",
                  message: "xsi:type override on element " \
                           "'#{xml_element.name}' is forbidden by its " \
                           "block facet",
                  location: xml_element.xpath,
                  context: { element: xml_element.name },
                )
                return
              end
            end
            return unless type_def

            case type_def
            when Lutaml::Xsd::SimpleType
              validate_simple_type_content(xml_element, type_def, collector,
                                           repository: repository)
            when Lutaml::Xsd::ComplexType
              validate_complex_type_content(xml_element, type_def, collector)
            else
              # Handle built-in types
              validate_builtin_type(xml_element, type_def, collector)
            end
          end

          # XSD 1.0 §3.3.4 / §3.4.6: block on the element declaration
          # AND on the declared complexType forbids replacing the type
          # with one derived by the blocked kind. Direct derivation from
          # the declared base is checked; deeper chains need the
          # derivation-closure backlog.
          #
          # @return [Boolean]
          def override_blocked?(schema_element, override_type, repository)
            declared_local = schema_element.type.to_s.split(":").last
            return false if declared_local.to_s.empty?

            kind = derivation_kind_from(override_type, declared_local)
            return false unless kind

            tokens = schema_element.block.to_s.split(/\s+/)
            declared = repository&.resolve_named_type(declared_local)
            if declared.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
              tokens += declared.block.to_s.split(/\s+/)
            end
            return false if tokens.empty?
            return false unless tokens.include?("#all") ||
              tokens.intersect?(%w[extension restriction])

            blocked = tokens.include?("#all") ? %w[extension restriction] : tokens
            blocked.include?(kind)
          end

          # The derivation kind of the override type when it directly
          # derives from the declared base; nil otherwise.
          #
          # @return [String, nil]
          def derivation_kind_from(override_type, declared_local)
            return nil if declared_local.to_s.empty?

            case override_type
            when Lutaml::Xml::Schema::Xsd::ComplexType
              content = override_type.complex_content
              return nil unless content

              %i[extension restriction].each do |kind|
                part = content.public_send(kind)
                next unless part

                return kind.to_s if
                  part.base.to_s.split(":").last == declared_local
              end
              nil
            when Lutaml::Xml::Schema::Xsd::SimpleType
              restriction = override_type.restriction
              if restriction &&
                  restriction.base.to_s.split(":").last == declared_local
                return "restriction"
              end

              nil
            end
          end

          private

          # xsi:nil handling: the attribute may appear only on nillable
          # declarations (regardless of its value), and a nilled element
          # must have no content — character or element. Returns true
          # when the element is nilled (nothing further to validate).
          #
          # @return [Boolean]
          def xsi_nil_handled?(xml_element, schema_element, collector)
            nil_attr = xsi_attribute(xml_element, "nil")
            return false unless nil_attr

            nillable = schema_element.nillable.to_s.match?(/\A(true|1)\z/)

            if nil_attr.value.to_s.match?(/\A(true|1)\z/)
              unless nillable
                report_error(
                  collector,
                  code: "xsi_nil_not_allowed",
                  message: "Element '#{xml_element.name}' is not " \
                           "nillable but carries xsi:nil",
                  location: xml_element.xpath,
                  context: { element: xml_element.name },
                )
                return true
              end

              if xml_element.children.empty? &&
                  xml_element.text_content.to_s.strip.empty?
                return true
              end

              report_error(
                collector,
                code: "xsi_nil_with_content",
                message: "Element '#{xml_element.name}' has xsi:nil but " \
                         "carries content",
                location: xml_element.xpath,
                context: { element: xml_element.name },
              )
              return true
            end

            # xsi:nil="false" still advertises nil handling the
            # declaration forbids; content validates normally.
            unless nillable
              report_error(
                collector,
                code: "xsi_nil_not_allowed",
                message: "Element '#{xml_element.name}' is not " \
                         "nillable but carries xsi:nil",
                location: xml_element.xpath,
                context: { element: xml_element.name },
              )
            end
            false
          end

          # The xsi:type attribute value (local part), or nil.
          #
          # @param xml_element [XmlElement]
          # @return [String, nil]
          def xsi_type_name(xml_element)
            attr = xsi_attribute(xml_element, "type")
            return nil unless attr&.value.to_s.match?(/\S/)

            attr.value.to_s.split(":").last
          end

          # Resolve an xsi:type local name to a named type definition.
          #
          # @param local_name [String]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Object, nil]
          def resolve_xsi_type(local_name, repository)
            return nil unless repository

            repository.resolve_named_type(local_name)
          end

          # Resolve the type definition for an element
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::SimpleType, Lutaml::Xsd::ComplexType, nil]
          def resolve_element_type(schema_element, repository = nil)
            # Check for inline type definition
            return schema_element.simple_type if
              schema_element.simple_type

            return schema_element.complex_type if
              schema_element.complex_type

            # Check for type reference
            if schema_element.type
              resolved = repository&.resolve_type(schema_element)
              return resolved if resolved

              return schema_element.type
            end

            nil
          end

          # Validate simple type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param simple_type [Lutaml::Xsd::SimpleType] The simple type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_type_content(xml_element, simple_type,
                                           collector, repository: nil)
            value = xml_element.text_content

            # Validate base type if present
            if simple_type.restriction
              validate_restriction(value, simple_type.restriction,
                                   xml_element, collector)
            elsif simple_type.list
              validate_list(value, simple_type.list, xml_element, collector,
                            repository: repository)
            elsif simple_type.union
              validate_union(value, simple_type.union, xml_element, collector,
                             repository: repository)
            end
          end

          # Validate complex type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param complex_type [Lutaml::Xsd::ComplexType] Complex type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_complex_type_content(xml_element, complex_type,
                                            collector)
            # Complex type validation is handled by:
            # - AttributeValidationRule for attributes
            # - ContentModelValidationRule for content model
            # This rule focuses on type-level constraints

            # Check for simple content
            if complex_type.simple_content
              validate_simple_content(xml_element, complex_type.simple_content,
                                      collector)
            end
          end

          # Validate restriction facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_restriction(value, restriction, xml_element, collector)
            # Validate base type first
            if restriction.base
              validate_base_type(value, restriction.base, xml_element,
                                 collector)
            end

            # Validate facets
            validate_facets(value, restriction, xml_element, collector)
          end

          # Validate base type
          #
          # @param value [String] The value to validate
          # @param base_type [String] The base type name
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_base_type(value, base_type, xml_element, collector)
            answer = engine_builtin_answer(base_type, value)
            return if answer.nil? || answer

            report_error(
              collector,
              code: "type_validation_error",
              message: "'#{value}' is not a valid #{base_type}",
              location: xml_element.xpath,
              context: { value: value, type: base_type },
            )
          end

          # Validate facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_facets(value, restriction, xml_element, collector)
            # Check each facet type
            validate_pattern_facets(value, restriction, xml_element, collector)
            validate_length_facets(value, restriction, xml_element, collector)
            validate_range_facets(value, restriction, xml_element, collector)
            validate_enumeration_facets(value, restriction, xml_element,
                                        collector)
          end

          # Validate pattern facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_pattern_facets(value, restriction, xml_element,
                                      collector)
            return unless restriction.pattern

            patterns = Array(restriction.pattern)
            return if patterns.empty?

            patterns.each do |pattern|
              pattern_value = pattern.value || pattern.to_s

              begin
                regex = XsdRegex.to_regexp(pattern_value)
                next if value.match?(regex)

                report_error(
                  collector,
                  code: "pattern_mismatch",
                  message: "Value '#{value}' does not match pattern " \
                           "'#{pattern_value}'",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    pattern: pattern_value,
                  },
                )
              rescue RegexpError => e
                report_warning(
                  collector,
                  code: "invalid_pattern",
                  message: "Invalid pattern in schema: #{e.message}",
                  location: xml_element.xpath,
                )
              end
            end
          end

          # Validate length facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_length_facets(value, restriction, xml_element,
                                     collector)
            value_length = value.length

            # Facet collections are arrays; an empty array must not be
            # treated as a present facet.
            length_facet = Array(restriction.length).first
            if length_facet
              expected_length = length_facet.value.to_i
              if value_length != expected_length
                report_error(
                  collector,
                  code: "length_mismatch",
                  message: "Value length #{value_length} does not equal " \
                           "required length #{expected_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    expected_length: expected_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check minimum length
            min_length_facet = Array(restriction.min_length).first
            if min_length_facet
              min_length = min_length_facet.value.to_i
              if value_length < min_length
                report_error(
                  collector,
                  code: "min_length_violation",
                  message: "Value length #{value_length} is less than " \
                           "minimum #{min_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    min_length: min_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check maximum length
            max_length_facet = Array(restriction.max_length).first
            return unless max_length_facet

            max_length = max_length_facet.value.to_i
            return unless value_length > max_length

            report_error(
              collector,
              code: "max_length_violation",
              message: "Value length #{value_length} exceeds maximum " \
                       "#{max_length}",
              location: xml_element.xpath,
              context: {
                value: value,
                max_length: max_length,
                actual_length: value_length,
              },
            )
          end

          # Validate range facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_range_facets(value, restriction, xml_element, collector)
            domain = range_domain(restriction.base)
            RANGE_FACETS.each do |facet, compare|
              facet_values = Array(restriction.public_send(facet))
              next if facet_values.empty?

              bound = facet_values.first.value
              value_key = facet_key(value, domain)
              bound_key = facet_key(bound, domain)
              next unless value_key && bound_key
              next if compare.call(value_key, bound_key)

              report_error(
                collector,
                code: "#{facet}_violation",
                message: "Value '#{value}' violates #{facet}='#{bound}'",
                location: xml_element.xpath,
                context: { value: value, bound: bound, facet: facet },
              )
            end
          end

          # Range comparisons run in the lexical space of the base type:
          # numeric types compare numerically, durations order by
          # (months, seconds) per XSD 1.0 Appendix E, and the date/time
          # family compares temporally. Derived types whose base is not
          # a built-in name are not range-checked here.
          def range_domain(base)
            case base.to_s.split(":").last
            when "duration" then :duration
            when "date", "dateTime", "time", "gYear", "gYearMonth"
              :temporal
            end
          end

          def facet_key(value, domain)
            case domain
            when :duration then duration_key(value)
            when :temporal then temporal_key(value)
            else numeric_key(value)
            end
          end

          def numeric_key(value)
            Integer(value, 10)
          rescue ArgumentError, TypeError
            Float(value, exception: false)
          end

          # XSD 1.0 Appendix E ordering: durations order by total months,
          # then by total seconds (days count as 24 hours).
          def duration_key(value)
            match = value.to_s.match(
              /\A(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?((?:\d+(?:\.\d*)?|\.\d+)S)?)?\z/,
            )
            return nil unless match
            return nil unless match[2] || match[3] || match[4] ||
              match[5] || match[6] || match[7]

            sign = match[1] ? -1 : 1
            months = sign * ((match[2].to_i * 12) + match[3].to_i)
            seconds = sign * ((match[4].to_i * 86_400) +
              (match[5].to_i * 3600) + (match[6].to_i * 60) +
              match[7].to_f)
            DurationKey.new(months, seconds)
          end

          def temporal_key(value)
            require "date"
            DateTime.parse(value.to_s)
          rescue StandardError
            nil
          end

          # Compares the value and bound as integers, then floats; facets
          # on non-numeric types (dates, strings) are not checked here.
          # Validate enumeration facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_enumeration_facets(value, restriction, xml_element,
                                          collector)
            return unless restriction.enumeration

            enumerations = Array(restriction.enumeration)
            return if enumerations.empty?

            allowed_values = enumerations.map do |enum|
              enum.value || enum.to_s
            end

            return if allowed_values.include?(value)

            report_error(
              collector,
              code: "enumeration_violation",
              message: "Value '#{value}' is not in enumeration",
              location: xml_element.xpath,
              context: {
                value: value,
                allowed_values: allowed_values,
              },
              suggestion: "Use one of: #{allowed_values.join(', ')}",
            )
          end

          # Validate list type
          #
          # @param value [String] The value
          # @param list [Lutaml::Xsd::List] The list definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_list(value, list, xml_element, collector,
                            repository: nil)
            items = value.split(/\s+/).reject(&:empty?)
            return if items.empty?

            inline = Array(list.simple_type).first
            if inline.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType) &&
                inline.restriction
              items.each do |item|
                validate_facets(item, inline.restriction, xml_element,
                                collector)
              end
              return
            end

            local = list.item_type.to_s.split(":").last
            return if local.to_s.empty?

            named = repository&.resolve_named_type(local)
            if named.is_a?(Lutaml::Xsd::SimpleType) && named.restriction
              items.each do |item|
                validate_facets(item, named.restriction, xml_element,
                                collector)
              end
              return
            end

            items.each do |item|
              answer = engine_builtin_answer(local, item)
              next if answer.nil? || answer

              report_error(
                collector,
                code: "list_item_violation",
                message: "List item '#{item}' is not a valid #{local}",
                location: xml_element.xpath,
                context: { item: item, item_type: local },
              )
            end
          end

          # Validate union type
          #
          # @param value [String] The value
          # @param union [Lutaml::Xsd::Union] The union definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_union(value, union, xml_element, collector,
                             repository: nil)
            return if union_accepts?(value, union, xml_element, collector,
                                     repository)

            report_error(
              collector,
              code: "union_violation",
              message: "Value '#{value}' does not match any member type " \
                       "of the union",
              location: xml_element.xpath,
              context: { value: value },
            )
          end

          # A value is valid when any member of the union accepts it.
          # Members are inline simple types or whitespace-separated
          # type references; dry runs collect into a throwaway collector.
          def union_accepts?(value, union, xml_element, _collector,
                             repository)
            Array(union.simple_type).each do |member|
              dry = ResultCollector.new(ValidationConfiguration.new)
              if member.restriction
                validate_facets(value, member.restriction, xml_element, dry)
                return true if dry.errors.empty? && dry.warnings.empty?
              else
                return true
              end
            end

            union.member_types.to_s.split(/\s+/).any? do |ref|
              ref_accepts?(value, ref, xml_element, repository)
            end
          end

          def ref_accepts?(value, ref, xml_element, repository)
            local = ref.to_s.split(":").last
            return false if local.to_s.empty?

            answer = engine_builtin_answer(local, value)
            return answer if [true, false].include?(answer)

            named = repository&.resolve_named_type(local)
            return false unless named.is_a?(Lutaml::Xsd::SimpleType)

            dry = ResultCollector.new(ValidationConfiguration.new)
            if named.restriction
              validate_facets(value, named.restriction, xml_element, dry)
              dry.errors.empty? && dry.warnings.empty?
            else
              true
            end
          end

          # Validate simple content
          #
          # @param xml_element [XmlElement] The element
          # @param simple_content [Lutaml::Xsd::SimpleContent] Simple content
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_content(xml_element, simple_content, collector)
            # Simple content means element has text content and attributes
            # Validate the text content as a simple type
            if simple_content.extension
              # Extension adds attributes to a simple type
              # Text content validation handled by base type
            elsif simple_content.restriction
              # Restriction constrains a simple type
              value = xml_element.text_content
              validate_restriction(value, simple_content.restriction,
                                   xml_element, collector)
            end
          end

          # Validate built-in type
          #
          # The engine answers builtin lexical checks when the adapter ships
          # an XSD engine; otherwise validation stays unimplemented here
          # (matching historical behavior).
          #
          # @param xml_element [XmlElement] The element
          # @param type_name [String] The type name
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_builtin_type(xml_element, type_name, collector)
            answer = engine_builtin_answer(type_name, xml_element.text_content)
            return if answer.nil?
            return if answer

            report_error(
              collector,
              code: "type_validation_error",
              message: "'#{xml_element.text_content}' is not a valid " \
                       "#{type_name}",
              location: xml_element.xpath,
              context: {
                value: xml_element.text_content,
                type: type_name,
              },
            )
          end

          # Engine answer for a builtin lexical check, nil when unavailable
          #
          # @param type_name [String] XSD type name (any prefix spelling)
          # @param value [String, nil] The lexical value
          # @return [Boolean, nil]
          def engine_builtin_answer(type_name, value)
            engine = validation_engine
            return unless engine&.supported?

            engine.builtin_valid?(
              "xs:#{type_name.to_s.split(':').last}", value
            )
          end
        end
      end
    end
  end
end
