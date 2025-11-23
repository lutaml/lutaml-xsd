# frozen_string_literal: true

require 'cgi'

module Lutaml
  module Xsd
    module Spa
      module Filters
        # URL and link formatting Liquid filters
        #
        # Provides filters for URL encoding, link generation, and anchor
        # formatting in Liquid templates.
        module UrlFilters
          # URL encode text
          #
          # @param text [String] Text to encode
          # @return [String] URL-encoded text
          def url_encode(text)
            return '' unless text

            CGI.escape(text.to_s)
          end

          # URL decode text
          #
          # @param text [String] Encoded text
          # @return [String] Decoded text
          def url_decode(text)
            return '' unless text

            CGI.unescape(text.to_s)
          end

          # Generate anchor ID from text
          #
          # @param text [String] Text to convert
          # @return [String] Anchor-friendly ID
          def anchor_id(text)
            return '' unless text

            text.to_s
                .downcase
                .gsub(/[^\w\s-]/, '')
                .gsub(/[\s_]+/, '-')
                .gsub(/^-+|-+$/, '')
          end

          # Generate link to item by ID
          #
          # @param id [String] Item ID
          # @param text [String, nil] Link text (defaults to ID)
          # @return [String] HTML link
          def link_to_id(id, text = nil)
            return '' unless id

            display_text = text || id
            %(<a href="##{anchor_id(id)}">#{display_text}</a>)
          end

          # Generate link to schema item
          #
          # @param schema_id [String] Schema ID
          # @param item_type [String] Item type (element, type, etc.)
          # @param item_id [String] Item ID
          # @param text [String, nil] Link text
          # @return [String] HTML link
          def link_to_schema_item(schema_id, item_type, item_id, text = nil)
            return '' unless schema_id && item_type && item_id

            anchor = "#{schema_id}-#{item_type}-#{item_id}"
            display_text = text || item_id
            %(<a href="##{anchor_id(anchor)}" class="schema-link">#{display_text}</a>)
          end

          # Generate external link with icon
          #
          # @param url [String] URL
          # @param text [String] Link text
          # @param external_icon [Boolean] Show external link icon
          # @return [String] HTML link
          def external_link(url, text, external_icon: true)
            return '' unless url && text

            icon = external_icon ? ' <span class="external-icon">↗</span>' : ''
            %(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{text}#{icon}</a>)
          end

          # Add query parameter to URL
          #
          # @param url [String] Base URL
          # @param param [String] Parameter name
          # @param value [String] Parameter value
          # @return [String] URL with parameter
          def add_url_param(url, param, value)
            return url unless url && param

            separator = url.include?('?') ? '&' : '?'
            "#{url}#{separator}#{url_encode(param)}=#{url_encode(value)}"
          end

          # Build URL from base and parameters
          #
          # @param base [String] Base URL
          # @param params [Hash] URL parameters
          # @return [String] Complete URL
          def build_url(base, params = {})
            return base unless params && !params.empty?

            query_string = params.map do |key, value|
              "#{url_encode(key)}=#{url_encode(value)}"
            end.join('&')

            "#{base}?#{query_string}"
          end

          # Get path to asset
          #
          # @param asset_path [String] Asset path (relative)
          # @param asset_type [String, nil] Asset type (css, js, images)
          # @return [String] Full asset path
          def asset_path(asset_path, asset_type = nil)
            return asset_path unless asset_type

            "#{asset_type}/#{asset_path}"
          end

          # Generate mailto link
          #
          # @param email [String] Email address
          # @param text [String, nil] Link text (defaults to email)
          # @return [String] Mailto link
          def mailto_link(email, text = nil)
            return '' unless email

            display_text = text || email
            %(<a href="mailto:#{email}">#{display_text}</a>)
          end

          # Check if URL is external
          #
          # @param url [String] URL to check
          # @return [Boolean] True if external URL
          def external_url?(url)
            return false unless url

            url_str = url.to_s
            url_str.start_with?('http://', 'https://', '//')
          end

          # Get file extension from path
          #
          # @param path [String] File path
          # @return [String] File extension (without dot)
          def file_extension(path)
            return '' unless path

            ext = File.extname(path.to_s)
            ext.empty? ? '' : ext[1..]
          end

          # Get filename from path
          #
          # @param path [String] File path
          # @param include_ext [Boolean] Include extension
          # @return [String] Filename
          def filename_from_path(path, include_ext: true)
            return '' unless path

            name = File.basename(path.to_s)
            include_ext ? name : File.basename(name, '.*')
          end

          # Generate breadcrumb link
          #
          # @param parts [Array<Hash>] Breadcrumb parts with :text and :url
          # @param separator [String] Separator character
          # @return [String] Breadcrumb HTML
          def breadcrumb(parts, separator: '›')
            return '' unless parts && !parts.empty?

            parts.map.with_index do |part, index|
              if index == parts.size - 1
                %(<span class="breadcrumb-current">#{part[:text]}</span>)
              else
                url = part[:url] || '#'
                %(<a href="#{url}" class="breadcrumb-link">#{part[:text]}</a>)
              end
            end.join(%( <span class="breadcrumb-separator">#{separator}</span> ))
          end
        end
      end
    end
  end
end
