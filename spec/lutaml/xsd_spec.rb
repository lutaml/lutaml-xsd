# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd do
  LOCATIONS = {
    omml_schema: "https://raw.githubusercontent.com/t-yuki/ooxml-xsd/refs/heads/master",
    "metaschema-meta-constraints": "spec/lutaml/fixtures",
    "metaschema-markup-multiline": "spec/lutaml/fixtures",
    "metaschema-prose-module": "spec/lutaml/fixtures",
    "metaschema-markup-line": "spec/lutaml/fixtures",
    metaschema: "spec/lutaml/fixtures",
  }

  subject(:parsed_schema) { described_class.parse(schema, location: location) }

  it "has a version number" do
    expect(Lutaml::Xsd::VERSION).not_to be nil
  end

  Dir.glob(File.expand_path("fixtures/*.xsd", __dir__)).each do |input_file|
    context "when parsing #{input_file}" do
      let(:schema) { File.read(input_file) }
      let(:location) do
        file_location = LOCATIONS[File.basename(input_file, ".xsd").to_sym]
        if file_location&.start_with?("http")
          file_location
        elsif file_location
          File.expand_path(file_location)
        end
      end

      it "matches a Lutaml::Model::Schema object" do
        expect(parsed_schema).to be_a(Lutaml::Xsd::Schema)
      end

      it "matches count of direct child elements of the root" do
        # TODO: uncomment once we have a way to process imports
        # expect(parsed_schema.import.count).to eql(schema.scan(/<\w+:import /).count)
        expect(parsed_schema.group.count).to eql(schema.scan(/<\w+:group name=/).count)
        expect(parsed_schema.simple_type.count).to eql(schema.scan(/<\w+:simpleType /).count)
        expect(parsed_schema.element.count).to eql(schema.scan(/^\s{0,2}<\w+:element /).count)
        expect(parsed_schema.complex_type.count).to eql(schema.scan(/<\w+:complexType /).count)
      end

      it "matches count of attributes" do
        processed_xml = schema_to_xml(parsed_schema.to_xml, escape_content_tags: true)
        expect(processed_xml).to be_analogous_with(schema_to_xml(schema))
      end
    end
  end
end
