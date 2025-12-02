# frozen_string_literal: true

require "json"

module Lutaml
  module Xsd
    module Spa
      module Filters
        # Schema-specific Liquid filters
        #
        # Provides custom filters for formatting and displaying XSD schema
        # information in Liquid templates.
        module SchemaFilters
          # Convert object to JSON string (Liquid json filter implementation)
          #
          # @param obj [Object] Object to serialize
          # @return [String] JSON string (properly escaped for HTML/JS)
          def json(obj)
            return "null" if obj.nil?

            # Use JSON.generate which properly escapes all special characters
            # including backslashes, quotes, newlines, etc.
            JSON.generate(obj)
          end

          # Alias for backwards compatibility
          alias json_string json

          # Format type name with proper styling
          #
          # @param type [String] Type name
          # @return [String] Formatted type name
          def format_type(type)
            return "" unless type

            type.to_s.strip
          end

          # Get icon for type
          #
          # @param type [String] Type category
          # @return [String] Icon character/emoji
          def type_icon(type)
            icons = {
              "element" => "📦",
              "complex_type" => "🔷",
              "simple_type" => "🔸",
              "attribute" => "🏷️",
              "group" => "📂",
              "schema" => "📄",
            }
            icons[type.to_s] || "•"
          end

          # Format occurrence constraints (minOccurs/maxOccurs)
          #
          # @param min_occurs [String, Integer] Minimum occurrences
          # @param max_occurs [String, Integer] Maximum occurrences
          # @return [String] Formatted occurrence (e.g., "0..1", "1..*")
          def format_occurrence(min_occurs, max_occurs)
            min_val = min_occurs || "1"
            max_val = max_occurs == "unbounded" ? "*" : (max_occurs || "1")

            "#{min_val}..#{max_val}"
          end

          # Format namespace with prefix
          #
          # @param namespace [String] Namespace URI
          # @return [String] Formatted namespace
          def format_namespace(namespace)
            return "" unless namespace

            # Extract common namespace prefixes
            prefixes = {
              "http://www.w3.org/2001/XMLSchema" => "xs:",
              "http://www.w3.org/XML/1998/namespace" => "xml:",
              "http://www.w3.org/1999/xlink" => "xlink:",
            }

            prefixes.each do |uri, prefix|
              return prefix if namespace.start_with?(uri)
            end

            namespace
          end

          # Check if type is built-in XSD type
          #
          # @param type [String] Type name
          # @return [Boolean] True if built-in type
          def builtin_type?(type)
            return false unless type

            type_str = type.to_s
            type_str.start_with?("xs:", "xsd:") ||
              %w[string integer decimal boolean date time].include?(type_str)
          end

          # Get CSS class for type
          #
          # @param type [String] Type name
          # @return [String] CSS class name
          def type_class(type)
            return "type-unknown" unless type

            if builtin_type?(type)
              "type-builtin"
            else
              "type-custom"
            end
          end

          # Format attribute use
          #
          # @param use [String] Attribute use (required, optional, prohibited)
          # @return [String] Formatted use with styling
          def format_use(use)
            return "optional" unless use

            use.to_s
          end

          # Get badge class for attribute use
          #
          # @param use [String] Attribute use
          # @return [String] CSS class for badge
          def use_badge_class(use)
            case use.to_s
            when "required"
              "badge-required"
            when "optional"
              "badge-optional"
            when "prohibited"
              "badge-prohibited"
            else
              "badge-default"
            end
          end

          # Count items in collection
          #
          # @param collection [Array, nil] Collection to count
          # @return [Integer] Item count
          def count_items(collection)
            return 0 unless collection

            collection.respond_to?(:size) ? collection.size : 0
          end

          # Check if collection has items
          #
          # @param collection [Array, nil] Collection to check
          # @return [Boolean] True if collection has items
          def has_items?(collection)
            count_items(collection).positive?
          end

          # Format content model
          #
          # @param model [String] Content model type
          # @return [String] Formatted model name
          def format_content_model(model)
            return "" unless model

            case model.to_s
            when "sequence"
              "Sequence"
            when "choice"
              "Choice"
            when "all"
              "All"
            when "complex_content"
              "Complex Content"
            when "simple_content"
              "Simple Content"
            else
              model.to_s.capitalize
            end
          end

          # Get icon for content model
          #
          # @param model [String] Content model type
          # @return [String] Icon character
          def content_model_icon(model)
            icons = {
              "sequence" => "→",
              "choice" => "⎇",
              "all" => "∀",
              "complex_content" => "⊕",
              "simple_content" => "⊙",
            }
            icons[model.to_s] || "•"
          end

          # Convert name to slug format (kebab-case)
          #
          # Handles namespace prefixes and converts CamelCase to kebab-case
          #
          # @param name [String] Name to slugify
          # @return [String] Slugified name
          def slugify(name)
            return "unnamed" unless name

            # Handle namespace prefixes
            local_name = name.to_s.include?(":") ? name.to_s.split(":").last : name.to_s

            # Convert CamelCase to kebab-case
            local_name
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
              .gsub(/([a-z\d])([A-Z])/, '\1-\2')
              .downcase
              .gsub(/[^a-z0-9]+/, "-")
              .gsub(/^-|-$/, "")
          end
        end
      end
    end
  end
end
