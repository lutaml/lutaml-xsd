# frozen_string_literal: true

require "net/http"

module Lutaml
  module Xsd
    class SchemaPath
      URI_SCHEMES = %w[http https].freeze
      URL_FILENAME_REGEX = %r{/[^/]+\.[^/]+$}
      FORWARD_SLASH = "/"
      attr_reader :base_url, :path, :url, :errors, :location

      def initialize(location)
        @location = location
        if URI::DEFAULT_PARSER.make_regexp(URI_SCHEMES).match?(@location)
          @url = URI(location)
          @base_url = extract_base_url(location)
        elsif location
          @path = Pathname.new(location).expand_path
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

      def http_get(url)
        Net::HTTP.get(URI.parse(url))
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
        return http_get(schema_location) if URI::DEFAULT_PARSER.make_regexp(URI_SCHEMES).match?(schema_location)

        schema_path = schema_location_path(schema_location)
        url? ? http_get(schema_path) : File.read(schema_path)
      end

      def schema_location_path(schema_location)
        unless schema_location&.start_with?(FORWARD_SLASH) ||
               location&.end_with?(FORWARD_SLASH)
          separator = FORWARD_SLASH
        end

        location_params = [location, schema_location].compact
        url? ? location_params.join(separator) : File.join(location_params)
      end

      private

      def extract_base_url(uri)
        return uri unless uri.match?(URL_FILENAME_REGEX)

        URI(uri.sub(URL_FILENAME_REGEX, FORWARD_SLASH))
      end

      def test_url(schema_path)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        request = Net::HTTP::Head.new(URI([base_url, FORWARD_SLASH, schema_path].join))
        http.request(request).is_a?(::Net::HTTPSuccess)
      end
    end
  end
end
