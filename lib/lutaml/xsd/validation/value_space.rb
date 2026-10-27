# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Lexical value-space helpers shared by the element-side type rule
      # and the attribute-side type validation: numeric/duration/temporal
      # comparison keys, range-facet comparisons, and content-measured
      # lengths (binary counts octets).
      module ValueSpace
        DurationKey = Struct.new(:months, :seconds) do
          include Comparable

          def <=>(other)
            [months, seconds] <=> [other.months, other.seconds]
          end
        end

        RANGE_FACETS = {
          "min_inclusive" => ->(value, bound) { value >= bound },
          "min_exclusive" => ->(value, bound) { value > bound },
          "max_inclusive" => ->(value, bound) { value <= bound },
          "max_exclusive" => ->(value, bound) { value < bound },
        }.freeze

        module_function

        # Range comparisons run in the lexical space of the base type:
        # numeric types compare numerically, durations order by
        # (months, seconds) per XSD 1.0 Appendix E, and the date/time
        # family compares temporally. Derived types whose base is not
        # a built-in name are not range-checked here.
        def range_domain(base)
          case base.to_s.split(":").last
          when "duration" then :duration
          when "date", "dateTime", "time", "gYear", "gYearMonth",
               "gMonth", "gMonthDay", "gDay"
            :temporal
          end
        end

        def facet_key(value, domain)
          case domain
          when :duration then duration_key(value)
          when :temporal then temporal_key(value)
          else numeric_key(value)
          end
        end

        def numeric_key(value)
          Integer(value, 10)
        rescue ArgumentError, TypeError
          Float(value, exception: false)
        end

        # XSD 1.0 Appendix E ordering: durations order by total months,
        # then by total seconds (days count as 24 hours).
        def duration_key(value)
          match = value.to_s.match(
            /\A(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?((?:\d+(?:\.\d*)?|\.\d+)S)?)?\z/,
          )
          return nil unless match
          return nil unless match[2] || match[3] || match[4] ||
            match[5] || match[6] || match[7]

          sign = match[1] ? -1 : 1
          months = sign * ((match[2].to_i * 12) + match[3].to_i)
          seconds = sign * ((match[4].to_i * 86_400) +
            (match[5].to_i * 3600) + (match[6].to_i * 60) +
            match[7].to_f)
          DurationKey.new(months, seconds)
        end

        # Calendar-derived types order by their fields; each XSD
        # lexical form maps to a comparable numeric tuple. Timezones
        # are stripped (the suite's range facets compare naive
        # values); unparseable forms fall back to DateTime.
        def temporal_key(value)
          text = value.to_s.strip.sub(/\s/, "").delete_suffix("Z")
            .sub(/[+-]\d{2}:\d{2}\z/, "")

          calendar_key(text) || begin
            require "date"
            DateTime.parse(value.to_s)
          end
        rescue StandardError
          nil
        end

        # @return [Array<Integer>, nil] the calendar fields of an XSD
        #   lexical form, or nil when the text is not one
        def calendar_key(text)
          year_month = text.match(/\A(-?\d{4,})-(\d{2})\z/)
          return [year_month[1].to_i, year_month[2].to_i] if year_month

          g_month_day = text.match(/\A--(\d{2})-(\d{2})\z/)
          return [g_month_day[1].to_i, g_month_day[2].to_i] if g_month_day

          single = text.match(/\A(-?\d{4,}|--\d{2}|---\d{2})\z/)
          return [single[1].to_i] if single

          nil
        end

        # Length units follow the base type: binary types measure octets.
        def measured_length(value, restriction)
          base = restriction.base.to_s.split(":").last
          text = value.to_s
          case base
          when "hexBinary"
            text.length / 2
          when "base64Binary"
            cleaned = text.gsub(/\s+/, "")
            (cleaned.length * 3 / 4) - cleaned.count("=")
          else
            text.length
          end
        end
      end
    end
  end
end
