# frozen_string_literal: true

require "json"
require "yaml"
require "rng"
require_relative "spa_metadata"

module Lutaml
  module Xsd
    module Spa
      # Serializes RNG/RNC schemas into a format for the RNG-specific Vue frontend.
      #
      # Accepts a YAML config file with a `files` array listing RNG/RNC files.
      # File paths are resolved relative to the config file's location.
      #
      # Output format:
      #   { metadata:, grammars: [{ id:, name:, file_path:, start_refs:, define_groups: }] }
      #
      # Each grammar has define_groups which separate defines by source:
      #   - Main file defines
      #   - Include defines (with href)
      #
      # @example
      #   serializer = RngSchemaSerializer.new("/path/to/config.yml", verbose: true)
      #   data = serializer.serialize
      class RngSchemaSerializer
        attr_reader :config_path, :options

        def initialize(config_path, options = {})
          @config_path = File.expand_path(config_path)
          @config_dir = File.dirname(@config_path)
          @options = options
          @parsed_grammars = []
        end

        # Main serialization method
        #
        # @return [Hash] {metadata:, grammars:}
        def serialize
          parse_all_schemas
          metadata = build_metadata
          metadata_hash = if metadata.respond_to?(:to_hash)
                            hash = metadata.to_hash
                            hash.to_h do |k, v|
                              [k.is_a?(String) ? k.to_sym : k, v]
                            end
                          elsif metadata.respond_to?(:to_h)
                            metadata.to_h
                          else
                            metadata
                          end
          {
            metadata: metadata_hash,
            grammars: serialize_grammars,
          }
        end

        private

        # -- Parsing -----------------------------------------------------------

        def parse_all_schemas
          config = YAML.load_file(@config_path)
          files = config["files"] || []

          files.each do |file_name|
            file_path = File.expand_path(file_name, @config_dir)
            unless File.exist?(file_path)
              warn "Warning: File not found: #{file_path}" if verbose?
              next
            end

            # Parse without resolving externals to get raw includes
            raw_grammar = parse_file_raw(file_path)

            @parsed_grammars << {
              file_path: file_path,
              raw_grammar: raw_grammar,
            }
          rescue StandardError => e
            warn "Warning: Failed to parse #{file_path}: #{e.message}" if verbose?
          end
        end

        def parse_file_raw(file_path)
          ext = File.extname(file_path).downcase
          content = File.read(file_path)
          case ext
          when ".rnc"
            Rng.parse_rnc(content)
          when ".rng"
            Rng.parse(content, resolve_external: false)
          else
            raise "Unsupported schema format: #{ext}"
          end
        end

        def parse_file_no_resolve(file_path)
          ext = File.extname(file_path).downcase
          content = File.read(file_path)
          case ext
          when ".rnc"
            Rng.parse_rnc(content)
          when ".rng"
            Rng.parse(content, resolve_external: false)
          else
            raise "Unsupported schema format: #{ext}"
          end
        end

        def verbose?
          options[:verbose] == true
        end

        # -- Metadata ----------------------------------------------------------

        def build_metadata
          title = derive_title
          SpaMetadata.new(
            generated: Time.now.utc.iso8601,
            generator: "lutaml-xsd v#{Lutaml::Xsd::VERSION} (RNG)",
            title: title,
            name: File.basename(@config_dir),
            version: nil,
            description: "Generated from RNG/RNC schemas via #{@config_path}",
            schema_count: @parsed_grammars.size,
          )
        end

        def derive_title
          dir_name = File.basename(@config_dir)
          dir_name.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
        end

        # -- Grammar Serialization ---------------------------------------------

        def serialize_grammars
          @parsed_grammars.map.with_index do |entry, index|
            serialize_single_grammar(
              entry[:raw_grammar],
              index,
              entry[:file_path],
            )
          end
        end

        def serialize_single_grammar(grammar, index, file_path)
          file_name = File.basename(file_path, ".*")
          start_refs = extract_start_refs(grammar)
          name = start_refs.first || file_name

          {
            id: slugify(file_name),
            name: name,
            file_path: File.basename(file_path),
            start_refs: start_refs,
            define_groups: build_define_groups(grammar, file_path),
            model_tree: build_model_tree(grammar),
          }
        end

        # -- Model tree (recursive object dump) --------------------------------

        INTERNAL_IVARS = %i[
          @using_default @lutaml_register @lutaml_root @lutaml_parent
          @element_order @ordered @pending_namespace_data @encoding
          @xml_declaration
        ].freeze

        def build_model_tree(object, visited: nil)
          visited ||= Set.new
          serialize_object(object, visited)
        end

        def serialize_object(object, visited)
          oid = object.object_id
          return { label: object.class.name, type: "circular", children: [], value: nil } if visited.include?(oid)

          visited.add(oid)

          children = []
          ivars = object.instance_variables.reject { |v| INTERNAL_IVARS.include?(v) }

          ivars.sort_by(&:to_s).each do |ivar|
            raw = object.instance_variable_get(ivar)
            name = ivar.to_s.delete("@")

            if uninitialized?(raw)
              # skip
            elsif raw.is_a?(Array)
              node = serialize_array(name, raw, visited)
              children << node if node
            elsif raw.is_a?(Hash)
              node = serialize_hash(name, raw)
              children << node if node
            elsif model_object?(raw)
              children << serialize_object(raw, visited).merge(label: name)
            elsif !raw.nil? && !(raw.is_a?(String) && raw.empty?)
              children << { label: name, type: "scalar", value: raw.to_s, children: [] }
            end
          end

          { label: object.class.name, type: "object", children: children, value: nil }
        end

        def serialize_array(name, array, visited)
          return nil if array.empty?

          if model_object?(array.first)
            items = array.map { |item| serialize_object(item, visited) }
            { label: "#{name} [#{array.size}]", type: "collection", children: items, value: nil }
          else
            values = array.compact.map(&:to_s)
            { label: name, type: "collection", children: [], value: values.join(", ") }
          end
        end

        def serialize_hash(name, hash)
          return nil if hash.empty?

          value = hash.map { |k, v| "#{k}: #{v}" }.join(", ")
          { label: name, type: "scalar", value: value, children: [] }
        end

        def model_object?(obj)
          obj.is_a?(Lutaml::Model::Serializable)
        end

        def uninitialized?(obj)
          obj.instance_of?(::Lutaml::Model::UninitializedClass)
        end

        # -- Define groups (main + includes) -----------------------------------

        def build_define_groups(grammar, main_file_path)
          groups = []
          main_dir = File.dirname(main_file_path)

          # Main file defines
          main_defines = grammar.define || []
          if main_defines.any?
            groups << {
              source: "main",
              source_href: nil,
              defines: main_defines.map { |d| serialize_single_define(d) }.sort_by { |d| d[:name] || "" },
            }
          end

          # Include defines — iterate the RNG model
          (grammar.include || []).each do |inc|
            href = inc.href
            next unless href

            # Override defines from the <include> tag (now a collection thanks to monkey-patch)
            override_defines = (inc.define || []).map { |d| serialize_single_define(d) }

            # Also try to parse the included file for its own defines
            included_path = File.expand_path(href, main_dir)
            file_defines = begin
              included_grammar = parse_file_no_resolve(included_path)
              (included_grammar.define || []).map { |d| serialize_single_define(d) }
            rescue StandardError => e
              warn "Warning: Could not parse include #{href}: #{e.message}" if verbose?
              []
            end

            # Combine: file defines + override defines (overrides take precedence)
            all_defines = file_defines.dup
            override_defines.each do |override|
              existing_idx = all_defines.index { |d| d[:name] == override[:name] }
              if existing_idx
                all_defines[existing_idx] = override
              else
                all_defines << override
              end
            end

            if all_defines.any?
              groups << {
                source: "include",
                source_href: href,
                defines: all_defines.sort_by { |d| d[:name] || "" },
              }
            end
          end

          groups
        end

        # -- Start refs --------------------------------------------------------

        def extract_start_refs(grammar)
          return [] if grammar.start.empty?

          grammar.start.filter_map do |start_item|
            start_item.ref&.name
          end.uniq
        end

        def extract_refs_from_pattern(pattern, refs)
          return unless pattern

          if pattern.respond_to?(:name) && pattern.name && !pattern.respond_to?(:attr_name)
            refs << pattern.name
          end

          %i[ref element choice group interleave mixed
             optional zeroOrMore oneOrMore].each do |attr|
            children = begin
              pattern.send(attr)
            rescue StandardError
              nil
            end
            Array(children).each do |child|
              extract_refs_from_pattern(child, refs)
            end
          end
        end

        # -- Define serialization ----------------------------------------------

        def serialize_single_define(define)
          child_elements = []
          child_refs = []
          child_attributes = []
          child_values = []
          child_data = []
          collect_children(define, child_elements, child_refs, child_attributes, child_values, child_data)

          {
            name: define.name,
            combine: safe_string(define.combine),
            content_type: detect_content_type(define),
            child_elements: child_elements.uniq.sort,
            child_refs: child_refs.uniq { |r| r[:name] }.sort_by { |r| r[:name] },
            child_attributes: child_attributes.uniq { |a| a[:name] }.sort_by { |a| a[:name] },
            child_values: child_values.uniq { |v| v[:value] }.sort_by { |v| v[:value] },
            child_data: child_data.uniq { |d| d[:type] }.sort_by { |d| d[:type] },
            documentation: extract_documentation(define),
          }
        end

        def collect_children(pattern, elements, refs, attributes, values, data, context: nil)
          return unless pattern

          Array(pattern.respond_to?(:element) ? pattern.element : nil).each do |elem|
            name = elem.attr_name || (elem.respond_to?(:name) ? elem.name&.value : nil)
            elements << name if name
            collect_children(elem, elements, refs, attributes, values, data, context: context)
          end

          Array(pattern.respond_to?(:ref) ? pattern.ref : nil).each do |ref|
            refs << { name: ref.name, context: context } if ref.name
          end

          Array(pattern.respond_to?(:attribute) ? pattern.attribute : nil).each do |attr|
            attr_name = attr.attr_name || attr.name
            attributes << { name: attr_name, context: context } if attr_name
          end

          Array(pattern.respond_to?(:value) ? pattern.value : nil).each do |val|
            values << { value: val.value, type: safe_string(val.type), context: context }
          end

          Array(pattern.respond_to?(:data) ? pattern.data : nil).each do |dat|
            data << { type: dat.type, context: context }
          end

          %i[choice group interleave mixed
             optional zeroOrMore oneOrMore].each do |attr|
            children = begin
              pattern.send(attr)
            rescue StandardError
              nil
            end
            Array(children).each do |child|
              collect_children(child, elements, refs, attributes, values, data, context: attr)
            end
          end
        end

        def detect_content_type(define)
          if define.element && !define.element.empty?
            "element"
          elsif define.attribute && !define.attribute.empty?
            "attribute"
          elsif define.choice && !define.choice.empty?
            "choice"
          elsif define.group && !define.group.empty?
            "group"
          elsif define.interleave && !define.interleave.empty?
            "interleave"
          elsif define.mixed && !define.mixed.empty?
            "mixed"
          elsif define.data && !define.data.empty?
            "data"
          elsif define.value && !define.value.empty?
            "value"
          elsif define.text && !define.text.empty?
            "text"
          elsif define.empty && !define.empty.empty?
            "empty"
          elsif define.list && !define.list.empty?
            "list"
          elsif define.notAllowed && !define.notAllowed.empty?
            "notAllowed"
          else
            "empty"
          end
        end

        # -- Helpers -----------------------------------------------------------

        def slugify(name)
          return "unnamed" unless name

          name.to_s
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
            .gsub(/([a-z\d])([A-Z])/, '\1-\2')
            .downcase
            .gsub(/[^a-z0-9]+/, "-")
            .gsub(/^-|-$/, "")
        end

        def safe_string(value)
          return nil if value.nil?
          return nil if value.instance_of?(::Lutaml::Model::UninitializedClass)
          return nil if %i[omitted empty].include?(value)

          value.to_s
        end

        def extract_documentation(obj)
          return nil unless obj.respond_to?(:documentation)

          doc = obj.documentation
          return nil unless doc

          doc.to_s
        end
      end
    end
  end
end
