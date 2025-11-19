# frozen_string_literal: true

module Lutaml
  module Xsd
    # Analyzes and graphs type dependencies in schema repositories
    # Provides functionality to find what types a type depends on and what depends on it
    class DependencyGrapher
      attr_reader :repository

      def initialize(repository)
        @repository = repository
        @type_index = repository.instance_variable_get(:@type_index)
      end

      # Find all dependencies of a type (what it depends on)
      # @param qname [String] Qualified name of the type
      # @param depth [Integer] Maximum recursion depth
      # @return [Hash] Dependency graph
      def dependencies(qname, depth: 3)
        result = repository.find_type(qname)
        unless result.resolved?
          return {
            resolved: false,
            error: result.error_message,
            qname: qname
          }
        end

        graph = {
          resolved: true,
          root: qname,
          namespace: result.namespace,
          type_category: result.definition.class.name.split("::").last,
          dependencies: {}
        }

        visited = Set.new
        collect_dependencies(result.definition, graph[:dependencies], depth, 0, visited)

        graph
      end

      # Find all dependents of a type (what depends on it)
      # @param qname [String] Qualified name of the type
      # @return [Hash] List of dependents
      def dependents(qname)
        result = repository.find_type(qname)
        unless result.resolved?
          return {
            resolved: false,
            error: result.error_message,
            qname: qname
          }
        end

        target_clark_key = build_clark_key(result.namespace, result.local_name)

        dependents_list = []
        all_types = @type_index.all

        all_types.each do |clark_key, type_info|
          next if clark_key == target_clark_key

          definition = type_info[:definition]
          deps = extract_type_references(definition)

          # Check if this type references our target
          if deps.any? { |dep| matches_target?(dep, result.namespace, result.local_name) }
            dependents_list << {
              qname: build_qname(type_info[:namespace], type_info[:definition].name),
              namespace: type_info[:namespace],
              local_name: type_info[:definition].name,
              type_category: type_info[:type].to_s,
              schema_file: File.basename(type_info[:schema_file])
            }
          end
        end

        {
          resolved: true,
          target: qname,
          namespace: result.namespace,
          dependents: dependents_list,
          count: dependents_list.size
        }
      end

      # Generate Mermaid diagram format
      # @param graph [Hash] Dependency graph
      # @return [String] Mermaid diagram
      def to_mermaid(graph)
        return "graph TD\n  error[Error: #{graph[:error]}]" unless graph[:resolved]

        lines = ["graph TD"]
        node_id = 0
        node_map = {}

        # Create root node
        root_id = "n#{node_id}"
        node_map[graph[:root]] = root_id
        lines << "  #{root_id}[\"#{escape_mermaid(graph[:root])}\"]"
        lines << "  style #{root_id} fill:#e1f5ff,stroke:#01579b,stroke-width:2px"
        node_id += 1

        # Add dependencies
        graph[:dependencies].each do |dep_name, dep_info|
          dep_id = node_map[dep_name] || "n#{node_id}"
          node_map[dep_name] = dep_id
          node_id += 1 unless node_map[dep_name]

          lines << "  #{dep_id}[\"#{escape_mermaid(dep_name)}\"]"
          lines << "  #{root_id} --> #{dep_id}"

          # Add nested dependencies
          add_mermaid_dependencies(dep_info[:dependencies], dep_id, lines, node_map, node_id) if dep_info[:dependencies]
        end

        lines.join("\n")
      end

      # Generate DOT format (Graphviz)
      # @param graph [Hash] Dependency graph
      # @return [String] DOT diagram
      def to_dot(graph)
        return "digraph {\n  error [label=\"Error: #{graph[:error]}\"];\n}" unless graph[:resolved]

        lines = ["digraph dependencies {"]
        lines << "  rankdir=LR;"
        lines << "  node [shape=box, style=rounded];"
        lines << ""

        node_id = 0
        node_map = {}

        # Create root node
        root_id = "n#{node_id}"
        node_map[graph[:root]] = root_id
        lines << "  #{root_id} [label=\"#{escape_dot(graph[:root])}\", style=\"rounded,filled\", fillcolor=\"#e1f5ff\"];"
        node_id += 1

        # Add dependencies
        graph[:dependencies].each do |dep_name, dep_info|
          dep_id = node_map[dep_name] || "n#{node_id}"
          node_map[dep_name] = dep_id
          node_id += 1 unless node_map[dep_name]

          lines << "  #{dep_id} [label=\"#{escape_dot(dep_name)}\"];"
          lines << "  #{root_id} -> #{dep_id};"

          # Add nested dependencies
          add_dot_dependencies(dep_info[:dependencies], dep_id, lines, node_map, node_id) if dep_info[:dependencies]
        end

        lines << "}"
        lines.join("\n")
      end

      # Generate text format
      # @param graph [Hash] Dependency graph
      # @param direction [String] Direction of display (both, up, down)
      # @return [String] Text representation
      def to_text(graph, direction: "both")
        return "Error: #{graph[:error]}" unless graph[:resolved]

        lines = []
        lines << "Type: #{graph[:root]}"
        lines << "Namespace: #{graph[:namespace]}"
        lines << "Category: #{graph[:type_category]}"
        lines << ""

        if direction == "both" || direction == "down"
          lines << "Dependencies (what this type depends on):"
          if graph[:dependencies].empty?
            lines << "  (none)"
          else
            add_text_dependencies(graph[:dependencies], lines, "  ")
          end
        end

        lines.join("\n")
      end

      private

      # Collect dependencies recursively
      def collect_dependencies(definition, graph, max_depth, current_depth, visited)
        return if current_depth >= max_depth

        refs = extract_type_references(definition)
        refs.each do |type_ref|
          next if visited.include?(type_ref)
          visited.add(type_ref)

          # Resolve the type
          type_result = repository.find_type(type_ref)
          next unless type_result.resolved?

          dep_key = build_qname(type_result.namespace, type_result.local_name)
          next if graph.key?(dep_key)

          graph[dep_key] = {
            namespace: type_result.namespace,
            local_name: type_result.local_name,
            type_category: type_result.definition.class.name.split("::").last,
            schema_file: File.basename(type_result.schema_file),
            dependencies: {}
          }

          # Recurse
          collect_dependencies(
            type_result.definition,
            graph[dep_key][:dependencies],
            max_depth,
            current_depth + 1,
            visited
          )
        end
      end

      # Extract type references from a definition
      def extract_type_references(definition)
        refs = []

        # Base type from complex content
        if definition.respond_to?(:complex_content) && definition.complex_content
          refs.concat(extract_from_complex_content(definition.complex_content))
        end

        # Base type from simple content
        if definition.respond_to?(:simple_content) && definition.simple_content
          refs.concat(extract_from_simple_content(definition.simple_content))
        end

        # Restriction base for simple types
        if definition.respond_to?(:restriction) && definition.restriction
          refs << definition.restriction.base if definition.restriction.respond_to?(:base)
        end

        # Element types from sequence
        if definition.respond_to?(:sequence) && definition.sequence
          refs.concat(extract_from_sequence(definition.sequence))
        end

        # Element types from choice
        if definition.respond_to?(:choice) && definition.choice
          refs.concat(extract_from_choice(definition.choice))
        end

        # Element types from all
        if definition.respond_to?(:all) && definition.all
          refs.concat(extract_from_all(definition.all))
        end

        # Attribute types
        if definition.respond_to?(:attribute) && definition.attribute
          refs.concat(extract_from_attributes(definition.attribute))
        end

        # For elements with type references
        refs << definition.type if definition.respond_to?(:type) && definition.type

        refs.compact.uniq.reject { |ref| ref =~ /^xsd?:/ }
      end

      def extract_from_complex_content(complex_content)
        refs = []

        if complex_content.respond_to?(:extension) && complex_content.extension
          ext = complex_content.extension
          refs << ext.base if ext.respond_to?(:base)
          refs.concat(extract_from_sequence(ext.sequence)) if ext.respond_to?(:sequence) && ext.sequence
          refs.concat(extract_from_attributes(ext.attribute)) if ext.respond_to?(:attribute) && ext.attribute
        end

        if complex_content.respond_to?(:restriction) && complex_content.restriction
          restr = complex_content.restriction
          refs << restr.base if restr.respond_to?(:base)
          refs.concat(extract_from_sequence(restr.sequence)) if restr.respond_to?(:sequence) && restr.sequence
        end

        refs
      end

      def extract_from_simple_content(simple_content)
        refs = []

        if simple_content.respond_to?(:extension) && simple_content.extension
          ext = simple_content.extension
          refs << ext.base if ext.respond_to?(:base)
          refs.concat(extract_from_attributes(ext.attribute)) if ext.respond_to?(:attribute) && ext.attribute
        end

        if simple_content.respond_to?(:restriction) && simple_content.restriction
          restr = simple_content.restriction
          refs << restr.base if restr.respond_to?(:base)
        end

        refs
      end

      def extract_from_sequence(sequence)
        refs = []
        return refs unless sequence.respond_to?(:element)

        elements = Array(sequence.element).compact
        elements.each do |elem|
          refs << elem.type if elem.respond_to?(:type) && elem.type
          refs << elem.ref if elem.respond_to?(:ref) && elem.ref
        end

        refs
      end

      def extract_from_choice(choice)
        refs = []
        return refs unless choice.respond_to?(:element)

        elements = Array(choice.element).compact
        elements.each do |elem|
          refs << elem.type if elem.respond_to?(:type) && elem.type
          refs << elem.ref if elem.respond_to?(:ref) && elem.ref
        end

        refs
      end

      def extract_from_all(all_group)
        refs = []
        return refs unless all_group.respond_to?(:element)

        elements = Array(all_group.element).compact
        elements.each do |elem|
          refs << elem.type if elem.respond_to?(:type) && elem.type
          refs << elem.ref if elem.respond_to?(:ref) && elem.ref
        end

        refs
      end

      def extract_from_attributes(attributes)
        refs = []
        attrs = Array(attributes).compact

        attrs.each do |attr|
          refs << attr.type if attr.respond_to?(:type) && attr.type
          refs << attr.ref if attr.respond_to?(:ref) && attr.ref
        end

        refs
      end

      # Check if a type reference matches the target
      def matches_target?(ref, target_namespace, target_local_name)
        # Try to resolve the reference
        result = repository.find_type(ref)
        return false unless result.resolved?

        result.namespace == target_namespace && result.local_name == target_local_name
      end

      # Build Clark notation key
      def build_clark_key(namespace, local_name)
        if namespace && !namespace.empty?
          "{#{namespace}}#{local_name}"
        else
          local_name
        end
      end

      # Build qualified name
      def build_qname(namespace, local_name)
        return local_name unless namespace

        prefix = repository.namespace_to_prefix(namespace)
        prefix ? "#{prefix}:#{local_name}" : local_name
      end

      # Escape string for Mermaid
      def escape_mermaid(str)
        str.gsub('"', '&quot;')
      end

      # Escape string for DOT
      def escape_dot(str)
        str.gsub('"', '\\"')
      end

      # Add dependencies to Mermaid diagram recursively
      def add_mermaid_dependencies(deps, parent_id, lines, node_map, node_id)
        deps.each do |dep_name, dep_info|
          dep_id = node_map[dep_name] || "n#{node_id}"
          node_map[dep_name] = dep_id
          node_id += 1 unless node_map[dep_name]

          lines << "  #{dep_id}[\"#{escape_mermaid(dep_name)}\"]"
          lines << "  #{parent_id} --> #{dep_id}"

          add_mermaid_dependencies(dep_info[:dependencies], dep_id, lines, node_map, node_id) if dep_info[:dependencies]
        end
      end

      # Add dependencies to DOT diagram recursively
      def add_dot_dependencies(deps, parent_id, lines, node_map, node_id)
        deps.each do |dep_name, dep_info|
          dep_id = node_map[dep_name] || "n#{node_id}"
          node_map[dep_name] = dep_id
          node_id += 1 unless node_map[dep_name]

          lines << "  #{dep_id} [label=\"#{escape_dot(dep_name)}\"];"
          lines << "  #{parent_id} -> #{dep_id};"

          add_dot_dependencies(dep_info[:dependencies], dep_id, lines, node_map, node_id) if dep_info[:dependencies]
        end
      end

      # Add dependencies to text format recursively
      def add_text_dependencies(deps, lines, indent)
        deps.each do |dep_name, dep_info|
          lines << "#{indent}#{dep_name} (#{dep_info[:type_category]})"

          if dep_info[:dependencies] && !dep_info[:dependencies].empty?
            add_text_dependencies(dep_info[:dependencies], lines, indent + "  ")
          end
        end
      end
    end
  end
end