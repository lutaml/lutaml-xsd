# frozen_string_literal: true

module Lutaml
  module Xsd
    # Converts an Rng::Grammar to an Lutaml::Xml::Schema::Xsd::Schema.
    #
    # This class is the orchestrator: it builds the schema, wires the
    # RngToXsd collaborators together, and runs the conversion phases
    # (includes -> defines -> start elements -> grammar elements).
    # Each phase's actual work lives in the collaborator that owns it.
    #
    # The collaborators are constructed once in #initialize and reused
    # across phases. They communicate via constructor-injected dependencies
    # (and small callable seams for schema mutation and define resolution),
    # never via shared instance variables on the orchestrator.
    class RngToXsdConverter
      Xsd = Lutaml::Xml::Schema::Xsd
      RngToXsdNamespace = RngToXsd

      def initialize(grammar, file_path: nil)
        @grammar = grammar
        @file_path = file_path
        @schema = Xsd::Schema.new
        @schema.element_form_default = "qualified"

        ns = grammar.ns
        @schema.target_namespace = ns unless ns.nil? || ns.is_a?(Lutaml::Model::UninitializedClass)

        @define_map = build_define_map(grammar)
        @define_results = {}

        @naming = RngToXsdNamespace::NamingService.new(@define_map)
        @facet_builder = RngToXsdNamespace::FacetBuilder.new
        @simple_type_builder = RngToXsdNamespace::SimpleTypeBuilder.new(
          facet_builder: @facet_builder,
          define_resolver: define_resolver,
          grammar: grammar,
          file_path: file_path,
        )
        @attribute_builder = RngToXsdNamespace::AttributeBuilder.new(
          simple_type_builder: @simple_type_builder,
        )
        @particle_converter = RngToXsdNamespace::ParticleConverter.new(
          simple_type_builder: @simple_type_builder,
          attribute_builder: @attribute_builder,
          define_resolver: define_resolver,
          define_map: @define_map,
          define_results_view: -> { @define_results },
          schema_sink: schema_sink,
        )
        @complex_type_builder = RngToXsdNamespace::ComplexTypeBuilder.new(
          particle_converter: @particle_converter,
          attribute_builder: @attribute_builder,
          define_map: @define_map,
          schema_sink: schema_sink,
        )
        @define_converter = RngToXsdNamespace::DefineConverter.new(
          define_map: @define_map,
          simple_type_builder: @simple_type_builder,
          complex_type_builder: @complex_type_builder,
          particle_converter: @particle_converter,
          naming_service: @naming,
          schema_sink: schema_sink,
        )
      end

      def convert
        convert_includes
        @define_converter.convert_all
        @define_results = @define_converter.results
        convert_start_elements
        convert_grammar_elements
        @schema
      end

      # Public seam used by SchemaParser and specs; collaborators use
      # define_resolver (a callable) to avoid a hard back-reference.
      def convert_define(name)
        @define_converter.convert(name)
      end

      private

      def define_resolver
        ->(name) { @define_converter&.convert(name) }
      end

      def schema_sink
        lambda do |kind, obj|
          case kind
          when :simple_type then @schema.simple_type(obj)
          when :complex_type then @schema.complex_type(obj)
          when :element then @schema.element(obj)
          when :group then @schema.group(obj)
          when :attribute_group then @schema.attribute_group(obj)
          end
        end
      end

      def build_define_map(grammar)
        map = {}
        collect_defines(grammar, map)
        map
      end

      def collect_defines(container, map)
        (container.define || []).each do |d|
          map[d.name] = d if d.name
        end
        (container.div || []).each { |div| collect_defines(div, map) }
      end

      def convert_includes
        return unless @file_path

        extract_include_locations.each do |inc_location|
          @schema.include(Xsd::Include.new(schema_location: inc_location))
        end
      end

      def extract_include_locations
        content = File.read(@file_path)
        locations = []

        case File.extname(@file_path).downcase
        when ".rnc"
          content.scan(/^include\s+"([^"]+)"/) do
            loc = Regexp.last_match(1)
            locations << loc.sub(/\.rnc$/i, ".xsd")
          end
        when ".rng"
          content.scan(/<include\s+[^>]*href\s*=\s*"([^"]+)"/) do
            loc = Regexp.last_match(1)
            locations << loc.sub(/\.rng$/i, ".xsd")
          end
        end

        locations
      end

      def convert_start_elements
        (@grammar.start || []).each do |start|
          pattern = single_start_pattern(start)
          next unless pattern

          case pattern
          when Rng::Element
            xsd_elem = @particle_converter.convert_element(pattern)
            @schema.element(xsd_elem) if xsd_elem
          when Rng::Ref
            promote_start_ref(pattern)
          end
        end
      end

      def single_start_pattern(start)
        RngToXsdNamespace::PatternInspector.single_child(start)
      end

      def promote_start_ref(ref)
        result = @define_results[ref.name]
        return unless result

        if result[:element]
          # Already promoted to top-level by DefineConverter.
          return
        end
        return unless result[:complex_type]

        @schema.element(Xsd::Element.new(name: ref.name, type: ref.name))
      end

      def convert_grammar_elements
        (@grammar.element || []).each do |rng_elem|
          xsd_elem = @particle_converter.convert_element(rng_elem)
          @schema.element(xsd_elem) if xsd_elem
        end
      end
    end
  end
end
