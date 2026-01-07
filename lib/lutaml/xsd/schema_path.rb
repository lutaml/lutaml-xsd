# frozen_string_literal: true

require "net/http"

module Lutaml
  module Xsd
    class SchemaPath
      URI_SCHEMES = %w[http https].freeze
      URL_FILENAME_REGEX = %r{/[^/]+\.[^/]+$}
      FILE_PATH_REGEX = %r{/[^.]+\.\w+$}
      FORWARD_SLASH = "/"
      attr_reader :path, :url, :errors, :location

      def initialize(location)
        @location = location
        if URI::DEFAULT_PARSER.make_regexp(URI_SCHEMES).match?(@location)
          @url = URI(extract_base_url(location))
        elsif location
          @path = location.delete_suffix(location.match(FILE_PATH_REGEX).to_s)
        end
        @errors = []
      end

      def path?
        !@path.nil?
      end

      def url?
        !@url.nil?
      end

      def location?
        url? || path?
      end

      def http_get(uri)
        Net::HTTP.get(URI.parse(uri))
      end

      def relative_path?(schema_path)
        return false unless location? && schema_path

        if url?
          test_url(schema_path)
        else
          File.exist?(File.join(@path, schema_path))
        end
      end

      def include_schema(schema_location)
        return unless location? && schema_location
        return http_get(schema_location) if absolute_url?(schema_location)

        schema_path = schema_location_path(schema_location)
        url? ? http_get(schema_path) : File.read(schema_path)
      end

      def schema_location_path(schema_location)
        if url?
          separator = FORWARD_SLASH unless assign_separator?(schema_location)

          if schema_location.nil?
            @location
          else
            [url, schema_location].join(separator)
          end
        else
          File.join([path, schema_location].compact)
        end
      end

      private

      def extract_base_url(uri)
        return uri unless uri.match?(URL_FILENAME_REGEX)

        uri.sub(URL_FILENAME_REGEX, FORWARD_SLASH)
      end

      def absolute_url?(schema_location)
        URI::DEFAULT_PARSER
          .make_regexp(URI_SCHEMES)
          .match?(schema_location)
      end

      def test_url(schema_path)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        request = Net::HTTP::Head.new(URI([url, FORWARD_SLASH, schema_path].join))
        http.request(request).is_a?(::Net::HTTPSuccess)
      end

      def assign_separator?(schema_location)
        schema_location&.start_with?(FORWARD_SLASH) ||
          url.to_s.end_with?(FORWARD_SLASH)
      end
    end
  end
end
