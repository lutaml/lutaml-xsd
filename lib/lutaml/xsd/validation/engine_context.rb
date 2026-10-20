# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    module Validation
      # EngineContext adapts Moxml::XSD (engine-native XSD validation on
      # leptris/nokogiri) to lutaml-xsd's validation stack.
      #
      # Engine findings are additive: tier-1 engine scope validates laxly
      # outside named+typed top-level elements / one-level content-model
      # descent / lexical checks, so the Ruby rule engine stays
      # authoritative. All query methods return nil (not false) when the
      # engine cannot answer, and callers fall back to Ruby logic.
      class EngineContext
        ENGINE_CODE = "engine_validation"

        attr_reader :context, :schemas

        class << self
          # Compile repository schemas for the current adapter.
          #
          # @param repository [#all_schemas] Schema repository
          # @param context [Moxml::Context] Adapter context
          # @return [EngineContext, nil] nil when the adapter has no engine
          def compile(repository, context: Moxml::Context.new)
            return nil unless xsd_supported?(context)

            schemas = repository.all_schemas.values.filter_map do |schema|
              compile_schema(context, schema)
            end
            new(context, schemas)
          end

          # Whether the adapter ships an XSD validator.
          #
          # @param context [Moxml::Context] Adapter context
          # @return [Boolean]
          def xsd_supported?(context)
            Moxml::XSD.supported?(context)
          rescue Moxml::NotImplementedError, NameError
            false
          end

          # Map a Moxml::XSD::ValidationError into the lutaml-xsd error type
          #
          # @param finding [Moxml::XSD::ValidationError]
          # @return [Validation::ValidationError]
          def map_finding(finding)
            ValidationError.new(
              code: ENGINE_CODE,
              message: finding.message,
              severity: :error,
              location: finding.path,
              line_number: finding.line,
              context: { column: finding.column }.compact,
            )
          end

          private

          def compile_schema(context, schema)
            compiled = context.xsd(schema.to_xml)
            compiled.compile_error ? nil : compiled
          rescue StandardError
            nil
          end
        end

        def initialize(context, schemas)
          @context = context
          @schemas = schemas
        end

        # @return [Boolean] true when at least one schema compiled
        def supported?
          !@schemas.empty?
        end

        # Validate raw XML against all compiled schemas.
        #
        # @param xml_content [String]
        # @return [Array<Validation::ValidationError>]
        def findings_for(xml_content)
          @schemas.flat_map { |schema| schema.validate(xml_content) }
                  .map { |finding| self.class.map_finding(finding) }
        end

        # Lexical check against the built-in type table ("xs:NAME" spelling).
        #
        # @param builtin_name [String] e.g. "xs:date"
        # @param lexical [String] the value to check
        # @return [Boolean, nil] nil when the engine cannot answer
        def builtin_valid?(builtin_name, lexical)
          Moxml::XSD.builtin_valid?(@context, builtin_name, lexical)
        rescue ArgumentError, StandardError
          nil
        end

        # Lexical check against a schema's named simpleType.
        #
        # @param type_name [String]
        # @param lexical [String]
        # @return [Boolean, nil] nil when no compiled schema knows the type
        def simple_valid?(type_name, lexical)
          @schemas.each do |schema|
            answer = schema.simple_valid?(type_name, lexical)
            return answer
          rescue StandardError
            next
          end
          nil
        end

        # Content-model check for one element's children (Moxml nodes).
        #
        # @param element_name [String]
        # @param children [Array<Moxml::Node>]
        # @return [Boolean, nil] nil when the engine cannot answer
        def content_valid?(element_name, children)
          @schemas.each do |schema|
            answer = schema.content_valid?(element_name, children)
            return answer
          rescue StandardError
            next
          end
          nil
        end
      end
    end
  end
end
