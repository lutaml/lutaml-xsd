# frozen_string_literal: true

module Lutaml
  module Xsd
    module Config
      module_function

      def set_path_or_url(location)
        return if location.nil?

        @url = location if location.start_with?(/http\w?:\/{2}[^.]+/)
        @path = location unless @url
      end

      def path
        @path
      end

      def url
        @url
      end

      def path?
        !@path.nil?
      end

      def url?
        !@url.nil?
      end
    end
  end
end
