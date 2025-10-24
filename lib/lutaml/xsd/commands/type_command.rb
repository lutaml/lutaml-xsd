# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Type query commands
      # Handles finding and listing schema types
      class TypeCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "find QNAME", "Find and display information about a specific type"
        option :from,
               type: :string,
               required: true,
               desc: "Path to .lxr package file"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :show_docs,
               type: :boolean,
               default: true,
               desc: "Include documentation"
        option :show_attributes,
               type: :boolean,
               default: true,
               desc: "Include attributes"
        def find(qname)
          FindCommand.new(qname, options).run
        end

        desc "list", "List all types in the repository"
        option :from,
               type: :string,
               required: true,
               desc: "Path to .lxr package file"
        option :namespace,
               type: :string,
               desc: "Filter by namespace URI"
        option :category,
               type: :string,
               enum: %w[element complex_type simple_type attribute_group group],
               desc: "Filter by type category"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def list
          ListCommand.new(options).run
        end

        # Find command implementation
        class FindCommand < BaseCommand
          def initialize(qname, options)
            super(options)
            @qname = qname
          end

          def run
            package_path = options[:from] || options["from"]
            repository = load_repository(package_path)
            repository = ensure_resolved(repository)

            find_and_display_type(repository)
          end

          private

          def find_and_display_type(repository)
            verbose_output "Resolving type: #{@qname}"

            result = repository.find_type(@qname)

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(result_to_hash(result), format)
            else
              display_text_result(result)
            end

            exit 1 unless result.resolved?
          end

          def result_to_hash(result)
            hash = {
              resolved: result.resolved?,
              qname: result.qname
            }

            if result.resolved?
              hash[:namespace] = result.namespace
              hash[:local_name] = result.local_name
              hash[:schema_file] = result.schema_file
              hash[:resolution_path] = result.resolution_path
              hash[:definition_class] = result.definition.class.name
            else
              hash[:error_message] = result.error_message
              hash[:resolution_path] = result.resolution_path if result.resolution_path
            end

            hash
          end

          def display_text_result(result)
            output "=" * 80
            output "Type Resolution: #{@qname}"
            output "=" * 80
            output ""

            if result.resolved?
              display_resolved_type(result)
            else
              display_failed_resolution(result)
            end
          end

          def display_resolved_type(result)
            output "✓ Type found"
            output ""
            output "Qualified Name: #{result.qname}"
            output "Namespace: #{result.namespace}"
            output "Local Name: #{result.local_name}"
            output "Schema File: #{File.basename(result.schema_file)}"
            output "Type Class: #{result.definition.class.name}"
            output ""

            if verbose?
              output "Resolution Path:"
              result.resolution_path.each_with_index do |step, idx|
                output "  #{idx + 1}. #{step}"
              end
              output ""
            end

            display_documentation(result.definition) if options[:show_docs]
            display_type_structure(result.definition) if options[:show_attributes]
          end

          def display_failed_resolution(result)
            output "✗ Type not found"
            output ""
            output "Error: #{result.error_message}"

            return unless result.resolution_path && !result.resolution_path.empty?

            output ""
            output "Resolution Path:"
            result.resolution_path.each_with_index do |step, idx|
              output "  #{idx + 1}. #{step}"
            end
          end

          def display_documentation(definition)
            return unless definition.respond_to?(:annotation) && definition.annotation

            annotation = definition.annotation
            return unless annotation.respond_to?(:documentation) && annotation.documentation

            docs = annotation.documentation.is_a?(Array) ? annotation.documentation : [annotation.documentation]
            docs.compact.each do |doc|
              content = doc.respond_to?(:content) ? doc.content : doc.to_s
              next if content.nil? || content.strip.empty?

              output "Documentation:"
              content.strip.split("\n").each do |line|
                output "  #{line.strip}"
              end
              output ""
            end
          end

          def display_type_structure(definition)
            # Display simple content
            display_simple_content(definition.simple_content) if definition.respond_to?(:simple_content) && definition.simple_content

            # Display complex content
            display_complex_content(definition.complex_content) if definition.respond_to?(:complex_content) && definition.complex_content

            # Display direct attributes
            return unless definition.respond_to?(:attribute) && definition.attribute

            display_attributes(definition.attribute, "Attributes")
          end

          def display_simple_content(simple_content)
            output "Simple Content:"

            return unless simple_content.respond_to?(:extension) && simple_content.extension

            extension = simple_content.extension
            output "  Extension:"
            output "    Base: #{extension.base}" if extension.respond_to?(:base)

            return unless extension.respond_to?(:attribute) && extension.attribute

            display_attributes(extension.attribute, "    Attributes")
          end

          def display_complex_content(complex_content)
            output "Complex Content:"

            return unless complex_content.respond_to?(:extension) && complex_content.extension

            extension = complex_content.extension
            output "  Extension:"
            output "    Base: #{extension.base}" if extension.respond_to?(:base)
          end

          def display_attributes(attributes, label = "Attributes")
            attrs = attributes.is_a?(Array) ? attributes : [attributes]
            return if attrs.compact.empty?

            output "#{label}:"
            attrs.compact.each do |attr|
              attr_name = attr.respond_to?(:name) ? attr.name : "unknown"
              attr_type = attr.respond_to?(:type) ? attr.type : "unknown"
              attr_use = attr.respond_to?(:use) ? attr.use : nil
              use_str = attr_use ? " (#{attr_use})" : ""
              output "  - #{attr_name}: #{attr_type}#{use_str}"
            end
            output ""
          end
        end

        # List command implementation
        class ListCommand < BaseCommand
          def run
            package_path = options[:from] || options["from"]
            repository = load_repository(package_path)
            repository = ensure_resolved(repository)

            list_types(repository)
          end

          private

          def list_types(repository)
            stats = repository.statistics
            types_by_category = stats[:types_by_category] || {}

            # Filter by category if specified
            if options[:category]
              category_sym = options[:category].to_sym
              types_by_category = if types_by_category.key?(category_sym)
                                    { category_sym => types_by_category[category_sym] }
                                  else
                                    {}
                                  end
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(types_by_category, format)
            else
              display_text_list(types_by_category, stats)
            end
          end

          def display_text_list(types_by_category, stats)
            output "Schema Repository Type Listing"
            output "=" * 80
            output ""
            output "Total Types: #{stats[:total_types]}"
            output "Total Namespaces: #{stats[:total_namespaces]}"

            output "Filtered by Namespace: #{options[:namespace]}" if options[:namespace]

            output "Filtered by Category: #{options[:category]}" if options[:category]

            output ""
            output "Types by Category:"
            output "-" * 80

            types_by_category.sort.each do |category, count|
              output "  #{category}: #{count}"
            end

            output ""
            output "Note: Use 'lutaml-xsd type find <qname> --from <package>' to get details about a specific type"
          end
        end
      end
    end
  end
end
