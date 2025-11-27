# frozen_string_literal: true

require_relative "file_validation_result"

module Lutaml
  module Xsd
    # Value object representing the validation results for multiple files
    class ValidationResult
      attr_reader :files

      # @param files [Array<FileValidationResult>] Individual file results
      def initialize(files)
        @files = if files.first.is_a?(FileValidationResult)
                   files
                 else
                   # Support backward compatibility with hash format
                   files.map do |f|
                     FileValidationResult.new(
                       file: f[:file],
                       valid: f[:valid],
                       error: f[:error],
                       detected_version: f[:detected_version]
                     )
                   end
                 end
      end

      # @return [Integer] Total number of files validated
      def total
        files.size
      end

      # @return [Integer] Number of valid files
      def valid
        files.count(&:success?)
      end

      # @return [Integer] Number of invalid files
      def invalid
        files.count(&:failure?)
      end

      # @return [Array<String>] Paths of failed files
      def failed_files
        files.select(&:failure?).map(&:file)
      end

      # @return [Boolean] true if all files passed validation
      def success?
        invalid.zero?
      end

      # @return [Boolean] true if any files failed validation
      def failure?
        !success?
      end

      # Convert to hash for backward compatibility
      # @return [Hash] Hash representation matching old format
      def to_h
        {
          total: total,
          valid: valid,
          invalid: invalid,
          files: files.map(&:to_h),
          failed_files: failed_files
        }
      end

      # @return [String] Human-readable summary
      def to_s
        "Validated #{total} file(s): #{valid} valid, #{invalid} invalid"
      end
    end
  end
end
