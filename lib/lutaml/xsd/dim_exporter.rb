# frozen_string_literal: true

require "json"

module Lutaml
  module Xsd
    # Exports an XSD schema to a Diagram Interchange Model (DIM) 0.1
    # document — the graph the Etassia engine lays out and draws. The
    # formation decision: one node per top-level type and global
    # element, its members as content blocks, and its relationships as
    # semantic edges — extension as generalization, restriction as
    # dependency, element-to-type membership as association, and
    # particle type references as references. The emitter sets no
    # positions; the engine computes them.
    #
    # Recorded losses (v0.1): type references match by local name, so
    # two types sharing a local name across namespaces collide; element
    # particles nest one level deep (complexType / extension /
    # restriction carry a single sequence/choice/all, matching the
    # JsonSchemaExporter scope); attributes, attribute groups,
    # substitution groups and identity constraints are not drawn; the
    # built-in types (xs:string and friends) are never nodes — member
    # text and simpleType "restricts" members carry them, and every
    # edge targets a node that exists in the graph.
    class DimExporter
      DIM_VERSION = "0.1"
      NOTATION = "xsd"
      WIDTH = 220
      COMPLEX_PARTICLE_DERIVATIONS = [
        Lutaml::Xml::Schema::Xsd::ExtensionComplexContent,
        Lutaml::Xml::Schema::Xsd::RestrictionComplexContent,
      ].freeze

      def initialize(schema)
        @schema = schema
      end

      # The DIM document as a Hash conforming to dim-0.1.schema.json.
      def export
        {
          "dim" => DIM_VERSION,
          "notation" => NOTATION,
          "graph" => {
            "id" => graph_id,
            "layoutOptions" => {
              "elk.algorithm" => "layered",
              "elk.direction" => "DOWN",
            },
            "children" => nodes,
            "edges" => edges,
          },
        }
      end

      # The document as JSON, ready for Etassia::Native.render_dim.
      def export_json
        JSON.pretty_generate(export)
      end

      private

      def graph_id
        target = read(@schema, :target_namespace)
        "schema-#{target || 'anonymous'}"
      end

      def nodes
        type_nodes + element_nodes
      end

      def type_nodes
        Array(read(@schema, :complex_type)).map { |t| type_node(t, "complexType") } +
          Array(read(@schema, :simple_type)).map { |t| type_node(t, "simpleType") }
      end

      def type_node(type, stereotype)
        content = [
          label(type.name, "title"),
          label(stereotype, "stereotype"),
        ]
        content.concat(restricts_block(type)) if stereotype == "simpleType"
        content.concat(member_blocks(type))
        {
          "id" => "type-#{type.name}",
          "width" => WIDTH,
          "height" => 24 + (22 * content.length),
          "content" => content,
        }
      end

      # A simpleType's base is usually a built-in, which is never a
      # node — the fact rides on the node as a member instead of an
      # edge to nowhere.
      def restricts_block(type)
        derivation, = derivation_of(type)
        base = derivation && read(derivation, :base)
        return [] if base.nil?

        [label("restricts #{base}", "member")]
      end

      def element_nodes
        Array(read(@schema, :element)).map do |element|
          content = [label(element.name, "title")]
          type_name = local(read(element, :type))
          content << label("type: #{type_name || 'anonymous'}", "member")
          content.concat(member_blocks(element))
          {
            "id" => "element-#{element.name}",
            "width" => WIDTH,
            "height" => 24 + (22 * content.length),
            "content" => content,
          }
        end
      end

      def member_blocks(type)
        particles = particle_containers(type)
        particles.filter_map do |element|
          next if read(element, :name).nil?

          label(member_text(element), "member")
        end
      end

      # One level of particles: the type's own sequence/choice/all, plus
      # the derivation's when the derivation is complex content (a
      # simpleContent derivation carries attributes only, no particles).
      def particle_containers(type)
        derivation, = derivation_of(type)
        direct = flat_map_kinds(type)
        return direct unless COMPLEX_PARTICLE_DERIVATIONS.any? { |k| derivation.is_a?(k) }

        direct + flat_map_kinds(derivation)
      end

      # [derivation, style]: extension generalizes, restriction depends.
      def derivation_of(type)
        content = read(type, :complex_content) || read(type, :simple_content)
        return from_content(content) unless content.nil?

        restriction = read(type, :restriction)
        return nil if restriction.nil?

        [restriction, "dependency"]
      end

      def from_content(content)
        extension = read(content, :extension)
        return [extension, "generalization"] unless extension.nil?

        [read(content, :restriction), "dependency"]
      end

      def flat_map_kinds(obj)
        return [] if obj.nil?

        %i[sequence choice all].flat_map do |kind|
          container = read(obj, kind)
          next [] if container.nil?

          Array(read(container, :element))
        end
      end

      def member_text(element)
        name = read(element, :name)
        suffix = occurrence_suffix(element)
        type_name = read(element, :type) || "anonymous"
        "#{name}#{suffix}: #{type_name}"
      end

      def occurrence_suffix(element)
        return "[]" if read(element, :max_occurs) == "unbounded"
        return "?" if read(element, :min_occurs) == "0"

        ""
      end

      def edges
        complex = Array(read(@schema, :complex_type))
        simple = Array(read(@schema, :simple_type))
        node_ids = nodes.map { |n| n["id"] }

        derivation_edges(complex + simple) +
          membership_edges(complex + simple, node_ids)
      end

      def derivation_edges(types)
        node_ids = nodes.map { |n| n["id"] }
        types.filter_map do |type|
          derivation, style = derivation_of(type)
          next if derivation.nil?

          target = "type-#{local(read(derivation, :base))}"
          next unless node_ids.include?(target)

          edge("derive-#{type.name}", "type-#{type.name}", target, style)
        end
      end

      def membership_edges(types, node_ids)
        element_edges = Array(read(@schema, :element)).flat_map do |element|
          target = "type-#{local(read(element, :type))}"
          next [] unless node_ids.include?(target)

          [edge("uses-#{element.name}", "element-#{element.name}", target,
                "association")]
        end

        element_edges + types.flat_map { |t| reference_edges(t, node_ids) }
      end

      def reference_edges(type, node_ids)
        source = "type-#{type.name}"
        seen = []
        particle_containers(type).filter_map do |element|
          target = "type-#{local(read(element, :type))}"
          next if !node_ids.include?(target) || seen.include?(target)

          seen << target
          edge("references-#{source}-#{seen.length}", source, target,
               "reference")
        end
      end

      def edge(id, source, target, style)
        {
          "id" => id,
          "sources" => [source],
          "targets" => [target],
          "style" => style,
        }
      end

      def label(text, role)
        { "kind" => "label", "text" => text, "role" => role }
      end

      # Reopened model attributes read back as an uninitialized sentinel
      # rather than nil; everything goes through this guard.
      def read(obj, name)
        return nil if obj.nil?

        value = obj.public_send(name)
        return nil if Lutaml::Model::Utils.uninitialized?(value)

        value
      end

      def local(type_name)
        return nil if type_name.nil?

        type_name.to_s.split(":").last
      end
    end
  end
end
