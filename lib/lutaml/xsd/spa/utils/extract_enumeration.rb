# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Utils
        module ExtractEnumeration
          # Extract enumeration default value from an attribute
          # with inline simpleType
          #
          # @param attr [Attribute] Attribute object
          # @return [String, nil] Formatted enumeration default string
          def extract_enumeration_default(attr)
            unless attr.respond_to?(:simple_type) && attr.simple_type
              return [nil,
                      nil]
            end

            st = attr.simple_type
            if st.respond_to?(:restriction) && st.restriction
              # <xsd:simpleType>
              #   <xsd:restriction base="xsd:token">
              #     <xsd:enumeration value="A"/>
              #     <xsd:enumeration value="B"/>
              #   </xsd:restriction>
              # </xsd:simpleType>
              restriction = st.restriction
              if restriction.respond_to?(:enumeration) && restriction.enumeration
                enum_str = extract_enumeration_values(restriction.enumeration)
                return [enum_str, restriction.base]
              end
            elsif st.respond_to?(:union) && st.union
              # <xsd:simpleType>
              #   <xsd:union memberTypes="xsd:token">
              #     <xsd:simpleType>
              #       <xsd:restriction base="xsd:token">
              #         <xsd:enumeration value="A"/>
              #         <xsd:enumeration value="B"/>
              #       </xsd:restriction>
              #     </xsd:simpleType>
              #   </xsd:union>
              # </xsd:simpleType>
              union = st.union
              union_type_str = ""
              if union.respond_to?(:member_types)
                union_type_str = union.member_types
              end

              if union.respond_to?(:simple_type) && union.simple_type
                union_sub_type = union.simple_type.first
                if union_sub_type.respond_to?(:restriction) &&
                    union_sub_type.restriction
                  union_restriction = union_sub_type.restriction
                  if union_restriction.respond_to?(:enumeration) &&
                      union_restriction.enumeration
                    enum_val_str = extract_enumeration_values(union_restriction
                      .enumeration)

                    enum_type_str = union_restriction.base
                    enum_str = "union of: [ #{union_type_str}, " \
                               "[ #{union_restriction.base} " \
                               "(#{enum_val_str}) ] ]"

                    return [enum_str, enum_type_str]
                  end
                end
              end
            end

            [nil, nil]
          end

          # Extract enumeration values in string
          #
          # @param attr [Enumeration] Enumeration object
          # @return [String]
          def extract_enumeration_values(enumeration)
            values = enumeration.map { |e| "'#{e.value}'" }
            "value comes from list: #{values.join('|')}"
          end
        end
      end
    end
  end
end
