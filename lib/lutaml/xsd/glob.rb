# frozen_string_literal: true

require "net/http"

module Lutaml
  module Xsd
    module Glob
      extend self

      def path_or_url(location)
        return nullify_location if location.nil?

        @location = location
        @url = location if location.start_with?(%r{http\w?:/{2}[^.]+})
        @path = File.expand_path(location) unless @url
      rescue Errno::ENOENT
        raise Error, "Invalid location: #{location}"
      end

      def location
        @location
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

      def include_schema(schema_location)
        return unless location? && schema_location

        schema_path = schema_location_path(schema_location)
        url? ? http_get(schema_path) : File.read(schema_path)
      end

      private

      def schema_location_path(schema_location)
        separator = "/" unless schema_location&.start_with?("/") || location&.end_with?("/")

        location_params = [location, schema_location].compact
        url? ? location_params.join(separator) : File.join(location_params)
      end

      def nullify_location
        @location = nil
        @path = nil
        @url = nil
      end
    end
  end
end
