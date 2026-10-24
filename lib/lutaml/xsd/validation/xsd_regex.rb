# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Translates XSD regular expressions (REC 2004, Appendix F) into
      # Ruby regexps.
      #
      # Dialect differences handled:
      # - XSD patterns are implicitly anchored over the whole string
      # - ^ and $ are literals, not anchors
      # - . matches any character including newlines (multiline flag)
      # - \i and \c are the XML name-start / name character classes
      # - \p{IsBasicLatin}-style block escapes map to Ruby block syntax
      # - character-class subtraction [a-z-[aeiou]] becomes nested
      #   lookaheads with an atomic single-character consume
      #
      #     regex = XsdRegex.to_regexp("[A-Z]{2}-\\d{4}")
      class XsdRegex
        NAME_START_CLASS = "[A-Z_a-z:\\u00C0-\\uD7FF\\uE000-\\uFFFD]"
        NAME_CHAR_CLASS =
          "[A-Z_a-z0-9:\\-.\\u00B7\\u00C0-\\uD7FF\\uE000-\\uFFFD]"

        # @param pattern [String] an XSD regular expression
        # @return [Regexp] whole-string, multiline Ruby regexp
        def self.to_regexp(pattern)
          new(pattern).to_regexp
        end

        def initialize(pattern)
          @pattern = pattern
        end

        def to_regexp
          Regexp.new("\\A(?:#{translate(@pattern)})\\z", Regexp::MULTILINE)
        end

        private

        # Most of the syntax is identical; the divergences are handled
        # per branch. Class interiors are consumed by scan_class.
        def translate(source)
          out = +""
          i = 0
          while i < source.length
            ch = source[i]
            case ch
            when "\\"
              out << translate_escape(source, i)
              i += escape_length(source, i)
            when "["
              body, next_i = scan_class(source, i)
              out << translate_class_body(body)
              i = next_i
            when "^", "$"
              out << "\\" << ch
              i += 1
            else
              out << ch
              i += 1
            end
          end
          out
        end

        def translate_escape(source, pos)
          rest = source[(pos + 1)..].to_s
          case rest[0]
          when "i" then NAME_START_CLASS
          when "c" then NAME_CHAR_CLASS
          else source[pos, escape_length(source, pos)]
          end
        end

        # \i \c consume two characters; \p{...} spans to its closing
        # brace; every other escape is backslash + one character.
        def escape_length(source, pos)
          rest = source[(pos + 1)..].to_s
          if rest.start_with?("p{") && (close = rest.index("}"))
            close + 2
          else
            2
          end
        end

        # @return [Array(String, Integer)] class body and index after the
        #   closing bracket; nested [..] (class subtraction) tracked by
        #   depth so [a-z-[aeiou]] scans as one construct
        def scan_class(source, start)
          i = start + 1
          depth = 0
          body = +"["
          while i < source.length
            ch = source[i]
            case ch
            when "\\"
              body << source[i, 2].to_s
              i += 2
            when "["
              depth += 1
              body << ch
              i += 1
            when "]"
              if depth.positive?
                depth -= 1
                body << ch
                i += 1
              else
                body << "]"
                return [body, i + 1]
              end
            else
              body << ch
              i += 1
            end
          end
          [body, i]
        end

        # Rewrites the inside of a [...] construct: subtraction becomes
        # atomic lookaheads; \i/\c expand; \p{Is...} normalizes.
        # Rewrites the inside of a [...] construct: subtraction becomes
        # atomic lookaheads; \i/\c expand; \p{Is...} normalizes.
        def translate_class_body(body)
          inner = body[1..-2]
          idx = inner.rindex("-[")
          if idx
            subtraction(inner[0...idx], inner[(idx + 2)..-2])
          else
            "[#{rewrite_escapes(inner)}]"
          end
        end

        # [X-[Y]] consumes one character that is in X and not in Y.
        def subtraction(base, subtracted)
          "(?>#{lookahead_in(base)}(?!#{class_body(subtracted)}).)"
        end

        def lookahead_in(body)
          "(?=[#{rewrite_escapes(body)}])"
        end

        def class_body(body)
          "[#{rewrite_escapes(body)}]"
        end

        def rewrite_escapes(body)
          body.gsub(/\\p\{Is([^}]*)\}/) do
            "\\p{#{block_name(Regexp.last_match(1))}}"
          end
            .gsub("\\i") { NAME_START_CLASS }
            .gsub("\\c") { NAME_CHAR_CLASS }
        end

        # XSD writes blocks as \p{IsBasicLatin}; Ruby as \p{In_Basic_Latin}.
        def block_name(xsd_name)
          stripped = xsd_name.delete_prefix("Is")
          "In_#{stripped.gsub(/([a-z])([A-Z])/, '\1_\2')}"
        end
      end
    end
  end
end
