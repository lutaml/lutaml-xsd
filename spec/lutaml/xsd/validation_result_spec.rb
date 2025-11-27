# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::ValidationResult do
  describe "#initialize" do
    it "accepts FileValidationResult objects" do
      file1 = Lutaml::Xsd::FileValidationResult.new(
        file: "schema1.xsd",
        valid: true
      )
      file2 = Lutaml::Xsd::FileValidationResult.new(
        file: "schema2.xsd",
        valid: false,
        error: "Invalid"
      )

      result = described_class.new([file1, file2])

      expect(result.files).to contain_exactly(file1, file2)
    end

    it "converts hash format to FileValidationResult objects" do
      hashes = [
        { file: "schema1.xsd", valid: true },
        { file: "schema2.xsd", valid: false, error: "Invalid" }
      ]

      result = described_class.new(hashes)

      expect(result.files.size).to eq(2)
      expect(result.files.first).to be_a(Lutaml::Xsd::FileValidationResult)
      expect(result.files.first.file).to eq("schema1.xsd")
      expect(result.files.first.success?).to be true
    end
  end

  describe "#total" do
    it "returns total number of files" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        ),
        Lutaml::Xsd::FileValidationResult.new(file: "c.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.total).to eq(3)
    end
  end

  describe "#valid" do
    it "returns count of valid files" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        ),
        Lutaml::Xsd::FileValidationResult.new(file: "c.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.valid).to eq(2)
    end
  end

  describe "#invalid" do
    it "returns count of invalid files" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        ),
        Lutaml::Xsd::FileValidationResult.new(file: "c.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.invalid).to eq(1)
    end
  end

  describe "#failed_files" do
    it "returns array of failed file paths" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "valid.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "bad1.xsd",
          valid: false,
          error: "Error1"
        ),
        Lutaml::Xsd::FileValidationResult.new(
          file: "bad2.xsd",
          valid: false,
          error: "Error2"
        )
      ]
      result = described_class.new(files)

      expect(result.failed_files).to contain_exactly("bad1.xsd", "bad2.xsd")
    end

    it "returns empty array when all files valid" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(file: "b.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.failed_files).to be_empty
    end
  end

  describe "#success?" do
    it "returns true when all files valid" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(file: "b.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.success?).to be true
    end

    it "returns false when any file invalid" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        )
      ]
      result = described_class.new(files)

      expect(result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns false when all files valid" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(file: "b.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.failure?).to be false
    end

    it "returns true when any file invalid" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        )
      ]
      result = described_class.new(files)

      expect(result.failure?).to be true
    end
  end

  describe "#to_h" do
    it "converts to hash matching old format" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(
          file: "valid.xsd",
          valid: true,
          detected_version: "1.0"
        ),
        Lutaml::Xsd::FileValidationResult.new(
          file: "invalid.xsd",
          valid: false,
          error: "Not a valid XSD"
        )
      ]
      result = described_class.new(files)

      hash = result.to_h

      expect(hash[:total]).to eq(2)
      expect(hash[:valid]).to eq(1)
      expect(hash[:invalid]).to eq(1)
      expect(hash[:failed_files]).to eq(["invalid.xsd"])
      expect(hash[:files]).to be_an(Array)
      expect(hash[:files].size).to eq(2)
      expect(hash[:files].first[:file]).to eq("valid.xsd")
    end
  end

  describe "#to_s" do
    it "returns human-readable summary" do
      files = [
        Lutaml::Xsd::FileValidationResult.new(file: "a.xsd", valid: true),
        Lutaml::Xsd::FileValidationResult.new(
          file: "b.xsd",
          valid: false,
          error: "Error"
        ),
        Lutaml::Xsd::FileValidationResult.new(file: "c.xsd", valid: true)
      ]
      result = described_class.new(files)

      expect(result.to_s).to eq("Validated 3 file(s): 2 valid, 1 invalid")
    end
  end
end
