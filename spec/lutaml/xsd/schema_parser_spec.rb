# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/schema_parser"

RSpec.describe Lutaml::Xsd::SchemaParser do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:parser) { described_class.new(repository) }
  let(:test_schema) do
    File.expand_path("../../fixtures/test_schema.xsd", __dir__)
  end

  describe "#initialize" do
    it "binds to the repository's parsed_schemas store" do
      expect(parser.store).to eq(repository.parsed_schemas)
    end

    it "starts with no current schema" do
      expect(parser.schema).to be_nil
    end
  end

  describe "#parse_file" do
    context "with a parseable XSD file" do
      it "registers the file path in the repository store" do
        parser.parse_file(test_schema, [])
        expect(repository.parsed_schemas.exists?(test_schema)).to eq(true)
      end

      it "stores a parsed schema object" do
        parser.parse_file(test_schema, [])
        schema = repository.parsed_schemas.get(test_schema)
        expect(schema).to respond_to(:element)
      end

      it "is idempotent — parsing twice does not error" do
        parser.parse_file(test_schema, [])
        expect { parser.parse_file(test_schema, []) }.not_to raise_error
      end
    end

    context "with a nonexistent file" do
      let(:missing) { "/nonexistent/path/schema.xsd" }

      it "does not raise and does not register the path" do
        expect { parser.parse_file(missing, []) }.not_to raise_error
        expect(repository.parsed_schemas.exists?(missing)).to eq(false)
      end
    end

    context "with an already-parsed file" do
      it "skips re-parsing" do
        parser.parse_file(test_schema, [])
        before_count = repository.parsed_schemas.all.size

        parser.parse_file(test_schema, [])
        expect(repository.parsed_schemas.all.size).to eq(before_count)
      end
    end
  end

  describe "#parse" do
    it "parses multiple files" do
      files = [test_schema]
      parser.parse(files, [])

      expect(repository.parsed_schemas.exists?(test_schema)).to eq(true)
    end

    it "supports verbose mode without error" do
      expect { parser.parse([test_schema], [], verbose: true) }
        .to output(/All schemas parsed/).to_stdout
    end
  end
end
