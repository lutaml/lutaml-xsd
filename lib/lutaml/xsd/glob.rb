# frozen_string_literal: true

module Lutaml
  module Xsd
    module Glob
      module_function

      def set_path_or_url(location)
        return nullify_path_and_url if location.nil?

        @location = location
        @url = location if location.start_with?(/http\w?:\/{2}[^.]+/)
        @path = File.expand_path(location) unless @url
      rescue => e
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

      def schema_location_path(schema_location)
        if schema_location.start_with?("/") || location.end_with?("/")
          location + schema_location
        else
          location + "/" + schema_location
        end
      end

      private

      def nullify_location
        @location = nil
        @path = nil
        @url = nil
      end
    end
  end
end
