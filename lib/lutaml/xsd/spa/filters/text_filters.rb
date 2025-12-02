# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Filters
        # Text formatting Liquid filters
        #
        # Provides filters for text manipulation, formatting, and display
        # in Liquid templates.
        module TextFilters
          # Truncate text to specified length
          #
          # @param text [String] Text to truncate
          # @param length [Integer] Maximum length
          # @param omission [String] String to append when truncated
          # @return [String] Truncated text
          def truncate_text(text, length = 100, omission = "...")
            return "" unless text

            text_str = text.to_s
            return text_str if text_str.length <= length

            text_str[0...(length - omission.length)] + omission
          end

          # Capitalize first letter
          #
          # @param text [String] Text to capitalize
          # @return [String] Capitalized text
          def capitalize_first(text)
            return "" unless text

            text.to_s.capitalize
          end

          # Convert to title case
          #
          # @param text [String] Text to convert
          # @return [String] Title cased text
          def titleize(text)
            return "" unless text

            text.to_s.split(/[\s_-]/).map(&:capitalize).join(" ")
          end

          # Convert to slug (URL-friendly)
          #
          # @param text [String] Text to slugify
          # @return [String] Slugified text
          def slugify(text)
            return "" unless text

            text.to_s
              .downcase
              .gsub(/[^\w\s-]/, "")
              .gsub(/[\s_-]+/, "-")
              .gsub(/^-+|-+$/, "")
          end

          # Pluralize word based on count
          #
          # @param count [Integer] Item count
          # @param singular [String] Singular form
          # @param plural [String, nil] Plural form (default: singular + 's')
          # @return [String] Pluralized word
          def pluralize(count, singular, plural = nil)
            count = count.to_i
            plural ||= "#{singular}s"

            count == 1 ? singular : plural
          end

          # Format number with separator
          #
          # @param number [Integer, Float] Number to format
          # @param separator [String] Thousands separator
          # @return [String] Formatted number
          def number_with_delimiter(number, separator = ",")
            return "" unless number

            number.to_s.reverse.scan(/\d{1,3}/).join(separator).reverse
          end

          # Strip HTML tags
          #
          # @param html [String] HTML content
          # @return [String] Plain text
          def strip_html(html)
            return "" unless html

            html.to_s.gsub(/<[^>]*>/, "")
          end

          # Escape HTML characters
          #
          # @param text [String] Text to escape
          # @return [String] Escaped text
          def escape_html(text)
            return "" unless text

            text.to_s
              .gsub("&", "&amp;")
              .gsub("<", "&lt;")
              .gsub(">", "&gt;")
              .gsub('"', "&quot;")
              .gsub("'", "&#39;")
          end

          # Convert newlines to <br> tags
          #
          # @param text [String] Text with newlines
          # @return [String] HTML with <br> tags
          def nl2br(text)
            return "" unless text

            text.to_s.gsub("\n", "<br>\n")
          end

          # Wrap text in paragraph tags
          #
          # @param text [String] Text content
          # @return [String] Text wrapped in <p> tags
          def paragraphize(text)
            return "" unless text

            text.to_s.split(/\n\n+/).map do |para|
              "<p>#{para.strip}</p>"
            end.join("\n")
          end

          # Highlight search term in text
          #
          # @param text [String] Text to search
          # @param term [String] Search term
          # @param tag [String] HTML tag to wrap matches
          # @return [String] Text with highlighted terms
          def highlight(text, term, tag = "mark")
            return text unless text && term

            text.to_s.gsub(
              /(#{Regexp.escape(term)})/i,
              "<#{tag}>\\1</#{tag}>",
            )
          end

          # Smart truncate preserving word boundaries
          #
          # @param text [String] Text to truncate
          # @param length [Integer] Maximum length
          # @param omission [String] String to append when truncated
          # @return [String] Truncated text
          def smart_truncate(text, length = 100, omission = "...")
            return "" unless text

            text_str = text.to_s
            return text_str if text_str.length <= length

            # Find last space before length limit
            truncated = text_str[0...(length - omission.length)]
            last_space = truncated.rindex(/\s/)

            if last_space
              truncated[0...last_space] + omission
            else
              truncated + omission
            end
          end

          # Extract first sentence
          #
          # @param text [String] Text content
          # @return [String] First sentence
          def first_sentence(text)
            return "" unless text

            match = text.to_s.match(/^[^.!?]+[.!?]/)
            match ? match[0] : text.to_s
          end

          # Count words in text
          #
          # @param text [String] Text content
          # @return [Integer] Word count
          def word_count(text)
            return 0 unless text

            text.to_s.split(/\s+/).size
          end

          # Format as code
          #
          # @param text [String] Code text
          # @param language [String, nil] Programming language
          # @return [String] Formatted code block
          def code_block(text, language = nil)
            return "" unless text

            lang_class = language ? %( class="language-#{language}") : ""
            "<pre><code#{lang_class}>#{escape_html(text)}</code></pre>"
          end

          # Format as inline code
          #
          # @param text [String] Code text
          # @return [String] Inline code
          def inline_code(text)
            return "" unless text

            "<code>#{escape_html(text)}</code>"
          end
        end
      end
    end
  end
end
