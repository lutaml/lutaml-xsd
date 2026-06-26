# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Builds Lutaml::Xml::Schema::Xsd::SimpleType instances from Rng data,
      # value, list, choice, and ref patterns. Pure construction — takes a
      # FacetBuilder and a define_resolver (anything that responds to
      # #call(name) and returns a result hash with :simple_type etc.).
      class SimpleTypeBuilder
        Xsd = Lutaml::Xml::Schema::Xsd
        Inspector = PatternInspector

        def initialize(facet_builder:, define_resolver:, grammar:, file_path: nil)
          @facet_builder = facet_builder
          @define_resolver = define_resolver
          @grammar = grammar
          @file_path = file_path
        end

        # Build a SimpleType from data/value patterns (multiple -> union).
        def build_from_patterns(name, patterns)
          if patterns.size == 1
            build(name, patterns.first)
          else
            types = patterns.filter_map { |p| build(nil, p) }
            return nil if types.empty?

            if types.size == 1
              types.first.name = name
              types.first
            else
              Xsd::SimpleType.new(
                name: name,
                union: Xsd::Union.new(simple_type: types),
              )
            end
          end
        end

        # Build a SimpleType from a single data/value/list/text/choice/ref.
        def build(name, pattern)
          case pattern
          when Rng::Data
            build_from_data(name, pattern)
          when Rng::Value
            build_from_value(name, pattern)
          when Rng::List
            build_from_list(name, pattern)
          when Rng::Text
            Xsd::SimpleType.new(
              name: name,
              restriction: Xsd::RestrictionSimpleType.new(base: "xs:string"),
            )
          when Rng::Choice
            build_from_choice(name, pattern)
          when Rng::Ref
            build_from_ref(name, pattern)
          end
        end

        def build_from_data(name, data)
          type_name = data_type_name(data)
          restriction = Xsd::RestrictionSimpleType.new(base: type_name)

          (data.param || []).each do |param|
            @facet_builder.apply(restriction, param, file_path: @file_path)
          end

          Xsd::SimpleType.new(name: name, restriction: restriction)
        end

        def build_from_value(name, value)
          type_name = value.type ? "xs:#{value.type}" : "xs:string"
          Xsd::SimpleType.new(
            name: name,
            restriction: Xsd::RestrictionSimpleType.new(
              base: type_name,
              enumeration: [
                Xsd::Enumeration.new(value: value.value),
              ],
            ),
          )
        end

        def build_from_list(name, list_pattern)
          inner = Inspector.all_patterns(list_pattern).first
          item_type = inner ? resolve_data_type(inner) : "xs:string"
          Xsd::SimpleType.new(
            name: name,
            list: Xsd::List.new(item_type: item_type),
          )
        end

        def build_enum(name, values)
          type_name = values.first[:type] || "xs:string"
          enums = values.map do |v|
            Xsd::Enumeration.new(value: v[:value])
          end
          Xsd::SimpleType.new(
            name: name,
            restriction: Xsd::RestrictionSimpleType.new(
              base: type_name,
              enumeration: enums,
            ),
          )
        end

        def collect_values(pattern)
          case pattern
          when Rng::Value
            [{ type: pattern.type ? "xs:#{pattern.type}" : nil, value: pattern.value }]
          when Rng::Choice
            Inspector.all_patterns(pattern).flat_map { |p| collect_values(p) }
          else
            []
          end
        end

        def resolve_data_type(pattern)
          case pattern
          when Rng::Data
            data_type_name(pattern)
          when Rng::Value
            pattern.type ? "xs:#{pattern.type}" : "xs:string"
          when Rng::Ref
            pattern.name
          else
            "xs:string"
          end
        end

        def data_type_name(data)
          lib = Inspector.resolve_string(data.datatypeLibrary) ||
            Inspector.resolve_string(@grammar.datatypeLibrary) || ""
          type = data.type || "string"

          if lib.empty? || lib.include?("XMLSchema-datatypes") || lib.include?("XMLSchema")
            type = "QName" if type == "NOTATION"
          else
            warn "Warning: Non-XSD datatype library '#{lib}' in #{@file_path}, " \
                 "using type name as-is: #{type}"
          end

          "xs:#{type}"
        end

        private

        def build_from_choice(name, choice)
          values = collect_values(choice)
          if values.any?
            build_enum(name, values)
          else
            child_types = Inspector.all_patterns(choice).filter_map { |p| build(nil, p) }
            return nil if child_types.empty?

            Xsd::SimpleType.new(
              name: name,
              union: Xsd::Union.new(simple_type: child_types),
            )
          end
        end

        def build_from_ref(name, ref)
          result = @define_resolver.call(ref.name)
          return nil unless result[:simple_type]

          Xsd::SimpleType.new(
            name: name,
            restriction: Xsd::RestrictionSimpleType.new(base: ref.name),
          )
        end
      end
    end
  end
end
