# frozen_string_literal: true

module Lutaml
  module Xsd
    # Component-level diff between two resolved schema repositories
    # (read-only over the SOM; see
    # docs/superpowers/specs/2026-11-26-schema-diff-design.md).
    #
    # Identity is (target namespace, local name, kind) in Clark form;
    # renames and namespace moves are reconciled from the unmatched
    # removal/addition pairs by content similarity.
    class SchemaDiff
      autoload :ChangeSet, "lutaml/xsd/schema_diff/change_set"
      autoload :Change, "lutaml/xsd/schema_diff/change"
      autoload :Modification, "lutaml/xsd/schema_diff/modification"

      RENAME_SIMILARITY_THRESHOLD = 0.6

      Component = Struct.new(:kind, :namespace, :local_name, :definition,
                             :scalars, :sets, keyword_init: true) do
        def identity
          namespace.to_s.match?(/\S/) ? "{#{namespace}}#{local_name}" : local_name.to_s
        end

        # The flat fingerprint the rename/move similarity runs over.
        def fingerprint
          scalars.map { |k, v| "#{k}=#{v}" } +
            sets.flat_map { |aspect, members| members.map { |m| "#{aspect}:#{m}" } }
        end

        def similarity(other)
          mine = fingerprint
          theirs = other.fingerprint
          union = (mine | theirs).size
          return 0.0 if union.zero?

          (mine & theirs).size.fdiv(union)
        end
      end

      XSD_BUILTIN_PREFIXES = %w[xs xsd].freeze

      FACET_ACCESSORS = %i[
        enumeration pattern length min_length max_length
        min_inclusive max_inclusive min_exclusive max_exclusive
        fraction_digits total_digits white_space
      ].freeze

      # Direct element particles exist only on these container shapes;
      # everything else raises through lutaml-model's method_missing.
      ELEMENT_CONTAINERS = [
        Lutaml::Xml::Schema::Xsd::Sequence,
        Lutaml::Xml::Schema::Xsd::Choice,
        Lutaml::Xml::Schema::Xsd::All,
      ].freeze

      # Nested particle containers per shape (verified surface —
      # Sequence/Choice carry no `all`; Group carries no direct
      # `element`; Group/All cannot nest further groups).
      CONTAINER_ACCESSORS = {
        Lutaml::Xml::Schema::Xsd::Sequence => %i[sequence choice group],
        Lutaml::Xml::Schema::Xsd::Choice => %i[sequence choice group],
        Lutaml::Xml::Schema::Xsd::All => [],
        Lutaml::Xml::Schema::Xsd::Group => %i[sequence choice all],
        Lutaml::Xml::Schema::Xsd::ComplexType => %i[sequence choice all group],
        Lutaml::Xml::Schema::Xsd::ExtensionComplexContent =>
          %i[sequence choice all group],
        Lutaml::Xml::Schema::Xsd::RestrictionComplexContent =>
          %i[sequence choice all group],
      }.freeze

      # @param old_repository [SchemaRepository] resolved
      # @param new_repository [SchemaRepository] resolved
      # @param namespace_map [Hash{String => String}] old-side
      #   namespace URI normalizations (the package-composition remap)
      def initialize(old_repository, new_repository, namespace_map: {})
        @old_repository = old_repository
        @new_repository = new_repository
        @namespace_map = namespace_map
      end

      # @return [ChangeSet]
      def diff
        old_components = components(@old_repository)
        new_components = components(@new_repository)

        changes = []
        common = old_components.keys & new_components.keys
        common.each do |identity|
          mods = modifications(old_components[identity],
                               new_components[identity])
          next if mods.empty?

          changes << build_change("modified", new_components[identity],
                                  modifications: mods)
        end

        paired = reconcile(old_components, new_components, changes)
        (new_components.keys - common - paired.values).each do |identity|
          changes << build_change("added", new_components[identity])
        end
        (old_components.keys - common - paired.keys).each do |identity|
          changes << build_change("removed", old_components[identity])
        end

        ChangeSet.new(changes: changes.sort_by do |c|
          [c.category, c.namespace.to_s, c.local_name.to_s]
        end)
      end

      private

      def build_change(category, component, modifications: [], renamed_from: nil)
        Change.new(
          category: category,
          kind: component.kind,
          namespace: component.namespace,
          local_name: component.local_name,
          renamed_from: renamed_from,
          modifications: modifications,
        )
      end

      # Extract every named component from the repository's schemas.
      #
      # @param repository [SchemaRepository]
      # @return [Hash{String => Component}]
      def components(repository)
        result = {}
        repository.all_schemas.each_value do |schema|
          namespace = schema.target_namespace.to_s
          collect_components(schema, namespace, result)
        end
        result
      end

      def collect_components(schema, namespace, result)
        Array(schema.element).each do |element|
          register(result, component("element", namespace, element.name,
                                     scalars: element_scalars(element)))
        end
        Array(schema.complex_type).each do |type|
          register(result, component("complex_type", namespace, type.name,
                                     scalars: complex_type_scalars(type),
                                     sets: complex_type_sets(type)))
        end
        Array(schema.simple_type).each do |type|
          register(result, component("simple_type", namespace, type.name,
                                     scalars: simple_type_scalars(type),
                                     sets: simple_type_sets(type)))
        end
        Array(schema.attribute).each do |attribute|
          register(result, component("attribute", namespace, attribute.name,
                                     scalars: attribute_scalars(attribute)))
        end
        Array(schema.group).each do |group|
          register(result, component("group", namespace, group.name,
                                     sets: group_sets(group)))
        end
        Array(schema.attribute_group).each do |group|
          register(result, component("attribute_group", namespace, group.name,
                                     sets: attribute_group_sets(group)))
        end
      end

      def register(result, component)
        return if component.local_name.to_s.empty?

        result[component.identity] = component
      end

      def component(kind, namespace, local_name, scalars: {}, sets: {})
        normalized = normalized_namespace(namespace)
        Component.new(
          kind: kind,
          namespace: normalized,
          local_name: local_name,
          definition: nil,
          scalars: scalars.transform_values { |v| compact_value(v) },
          sets: sets,
        )
      end

      def normalized_namespace(namespace)
        @namespace_map.fetch(namespace, namespace)
      end

      def compact_value(value)
        value&.to_s
      end

      def element_scalars(element)
        {
          "type" => element.type,
          "min_occurs" => element.min_occurs,
          "max_occurs" => element.max_occurs,
          "default" => element.default,
          "fixed" => element.fixed,
          "nillable" => element.nillable,
          "abstract" => element.abstract,
          "substitution_group" => element.substitution_group,
        }
      end

      def attribute_scalars(attribute)
        {
          "type" => attribute.type,
          "use" => attribute.use,
          "default" => attribute.default,
          "fixed" => attribute.fixed,
        }
      end

      def complex_type_scalars(type)
        {
          "base" => derivation_base(type),
          "mixed" => type.mixed,
          "abstract" => type.abstract,
        }
      end

      def complex_type_sets(type)
        {
          "attributes" => Set.new(
            attribute_members(type).map { |a| a.name.to_s }.reject(&:empty?),
          ),
          "particles" => Set.new(particle_names(type)),
        }
      end

      def simple_type_scalars(type)
        { "base" => simple_type_base(type) }
      end

      # Facet constraints live on the restriction model.
      def simple_type_sets(type)
        restriction = type.restriction
        return {} unless restriction

        facets = FACET_ACCESSORS.flat_map do |accessor|
          Array(restriction.public_send(accessor)).filter_map do |facet|
            value = facet.value.to_s
            next if value.empty?

            "#{accessor}=#{value}"
          end
        end
        { "facets" => Set.new(facets) }
      end

      def group_sets(group)
        { "particles" => Set.new(particle_names(group)) }
      end

      def attribute_group_sets(group)
        {
          "attributes" => Set.new(
            attribute_group_members(group).map { |a| a.name.to_s }.reject(&:empty?),
          ),
        }
      end

      # Scalar modifications: every aspect whose values diverge.
      #
      # @return [Array<Modification>]
      def modifications(old_component, new_component)
        mods = []
        (old_component.scalars.keys | new_component.scalars.keys).each do |aspect|
          old_value = old_component.scalars[aspect]
          new_value = new_component.scalars[aspect]
          next if old_value == new_value

          mods << Modification.new(aspect: aspect, old: old_value, new: new_value)
        end

        (old_component.sets.keys | new_component.sets.keys).each do |aspect|
          old_members = old_component.sets[aspect] || Set.new
          new_members = new_component.sets[aspect] || Set.new
          (new_members - old_members).sort.each do |member|
            mods << Modification.new(aspect: aspect, old: nil, new: member)
          end
          (old_members - new_members).sort.each do |member|
            mods << Modification.new(aspect: aspect, old: member, new: nil)
          end
        end
        mods
      end

      # Rename/move reconciliation over the unmatched pairs, highest
      # similarity first (deterministic: ties break on identity).
      #
      # @return [Hash{String => String}] old identity => new identity
      def reconcile(old_components, new_components, changes)
        removed = (old_components.keys - new_components.keys)
        added = (new_components.keys - old_components.keys)

        candidates = removed.product(added).filter_map do |old_id, new_id|
          old_c = old_components[old_id]
          new_c = new_components[new_id]
          next unless pairable?(old_c, new_c)

          score = old_c.similarity(new_c)
          score >= RENAME_SIMILARITY_THRESHOLD ? [score, old_id, new_id] : nil
        end.sort_by { |score, old_id, new_id| [-score, old_id, new_id] }

        used_old = []
        used_new = []
        pairs = {}
        candidates.each do |_score, old_id, new_id|
          next if used_old.include?(old_id) || used_new.include?(new_id)

          used_old << old_id
          used_new << new_id
          pairs[old_id] = new_id
          new_c = new_components[new_id]
          changes << if old_components[old_id].namespace == new_c.namespace
                       build_change("renamed", new_c, renamed_from: old_id)
                     else
                       build_change("moved_namespace", new_c,
                                    renamed_from: old_id)
                     end
        end
        pairs
      end

      def pairable?(old_component, new_component)
        return false if old_component.nil? || new_component.nil?
        return false if old_component.kind != new_component.kind

        # Same namespace = rename candidate; different namespace with
        # the same local name = namespace-move candidate.
        old_component.namespace == new_component.namespace ||
          old_component.local_name == new_component.local_name
      end

      def derivation_base(type)
        cc = type.complex_content
        sc = type.simple_content
        part = cc&.extension || cc&.restriction || sc&.extension || sc&.restriction
        base = part&.base
        return "" if base.nil?

        prefix = base.to_s.split(":").first
        XSD_BUILTIN_PREFIXES.include?(prefix) ? "" : base.to_s
      end

      def simple_type_base(type)
        restriction = type.restriction
        return "" unless restriction

        prefix = restriction.base.to_s.split(":").first
        XSD_BUILTIN_PREFIXES.include?(prefix) ? "" : restriction.base.to_s
      end

      def attribute_members(type)
        members = []
        if type.complex_content
          %i[extension restriction].each do |shape|
            part = Array(type.complex_content.public_send(shape)).first
            members.concat(Array(part&.attribute))
          end
        end
        if type.simple_content
          %i[extension restriction].each do |shape|
            part = Array(type.simple_content.public_send(shape)).first
            members.concat(Array(part&.attribute))
          end
        end
        members.concat(Array(type.attribute))
        members
      end

      def attribute_group_members(group)
        Array(group.attribute) + Array(group.attribute_group).flat_map do |nested|
          attribute_group_members(nested)
        end
      end

      # All child element names in the content model, recursive
      # through the per-shape container accessors, cycle-guarded
      # (derivation cycles are writable in XML).
      #
      # @return [Array<String>]
      def particle_names(node, seen = {}.compare_by_identity)
        names = []
        return names if node.nil? || seen.key?(node)

        seen[node] = true

        if ELEMENT_CONTAINERS.any? { |klass| node.is_a?(klass) }
          Array(node.element).each do |particle|
            name = particle.name.to_s
            names << name unless name.empty?
          end
        end

        CONTAINER_ACCESSORS.fetch(node.class, []).each do |container|
          Array(node.public_send(container)).each do |nested|
            names.concat(particle_names(nested, seen))
          end
        end

        if node.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) && node.complex_content
          %i[extension restriction].each do |shape|
            Array(node.complex_content.public_send(shape)).each do |part|
              names.concat(particle_names(part, seen))
            end
          end
        end

        names
      end
    end
  end
end
