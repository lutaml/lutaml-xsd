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
      #
      # An instance document is validated only against compiled schemas
      # that declare its root element with a matching targetNamespace —
      # repositories (and the global processed-schema cache) hold many
      # unrelated schemas, and blanket validation would let every schema
      # reject every document.
      class EngineContext
        ENGINE_CODE = "engine_validation"

        XSD_NAMESPACE = "http://www.w3.org/2001/XMLSchema"

        CompiledSchema = Struct.new(:handle, :target_namespace, :element_names)

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
            source = schema.to_xml
            compiled = context.xsd(source)
            return nil if compiled.compile_error

            info = inspect_schema(context, source)
            CompiledSchema.new(
              compiled, info[:target_namespace], info[:element_names]
            )
          rescue StandardError
            nil
          end

          def inspect_schema(context, source)
            doc = context.parse(source)
            root = doc.root
            names = doc.xpath("/xs:schema/xs:element[@name]",
                              "xs" => XSD_NAMESPACE).map { |node| node["name"] }
            { target_namespace: root&.[]("targetNamespace"),
              element_names: names }
          rescue StandardError
            { target_namespace: nil, element_names: [] }
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

        # Free the engine-side schema handles. Document pools otherwise
        # accumulate across batched suite runs (moxml#350). Builtin
        # lexical checks are adapter-level and stay usable afterwards.
        #
        # @return [void]
        def release
          @schemas.each do |compiled|
            handle = compiled.handle
            handle.release if handle.is_a?(Moxml::XSD::Schema)
          end
        end

        # Validate raw XML against the compiled schemas that declare the
        # document's root element.
        #
        # @param xml_content [String]
        # @return [Array<Validation::ValidationError>]
        def findings_for(xml_content)
          root = instance_root(xml_content)
          return [] unless root

          matching_schemas(root).flat_map do |compiled|
            compiled.handle.validate(xml_content)
          end.map { |finding| self.class.map_finding(finding) }
        end

        # Lexical check against the built-in type table ("xs:NAME" spelling).
        #
        # @param builtin_name [String] e.g. "xs:date"
        # @param lexical [String] the value to check
        # @return [Boolean, nil] nil when the engine cannot answer
        def builtin_valid?(builtin_name, lexical)
          Moxml::XSD.builtin_valid?(@context, builtin_name, lexical)
        rescue StandardError
          nil
        end

        # Lexical check against a schema's named simpleType.
        #
        # @param type_name [String]
        # @param lexical [String]
        # @return [Boolean, nil] nil when no compiled schema knows the type
        def simple_valid(type_name, lexical)
          @schemas.each do |compiled|
            answer = compiled.handle.simple_valid?(type_name, lexical)
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
        def content_valid(element_name, children)
          @schemas.each do |compiled|
            answer = compiled.handle.content_valid?(element_name, children)
            return answer
          rescue StandardError
            next
          end
          nil
        end

        private

        def instance_root(xml_content)
          @context.parse(xml_content).root
        rescue StandardError
          nil
        end

        def matching_schemas(root)
          name = root.name
          ns = root_namespace(root)

          @schemas.select do |compiled|
            compiled.element_names.include?(name) &&
              (compiled.target_namespace.nil? ||
               compiled.target_namespace == ns)
          end
        end

        def root_namespace(root)
          root.namespace&.uri
        rescue StandardError
          nil
        end
      end
    end
  end
end
