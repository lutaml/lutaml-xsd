# frozen_string_literal: true

LOCATIONS = {
  omml_schema: "https://raw.githubusercontent.com/t-yuki/ooxml-xsd/refs/heads/master",
  "metaschema-meta-constraints": "spec/lutaml/fixtures",
  "metaschema-markup-multiline": "spec/lutaml/fixtures",
  "metaschema-prose-module": "spec/lutaml/fixtures",
  "metaschema-markup-line": "spec/lutaml/fixtures",
  metaschema: "spec/lutaml/fixtures",
  "unitsml-v1.0-csd03": nil
}.freeze

RSpec.describe Lutaml::Xsd do
  subject(:parsed_schema) { described_class.parse(schema, location: location) }

  Dir.glob(File.expand_path("fixtures/*.xsd", __dir__)).each do |input_file|
    rel_path = Pathname.new(input_file).relative_path_from(Pathname.new(__dir__)).to_s

    context "when parsing #{rel_path}" do
      let(:schema) { File.read(input_file) }
      let(:location) { LOCATIONS[File.basename(input_file, ".xsd").to_sym] }

      it "matches a Lutaml::Model::Schema object" do
        expect(parsed_schema).to be_a(Lutaml::Xsd::Schema)
      end

      it "matches count of direct child elements of the root" do
        expect(parsed_schema.imports.count).to eql(schema.scan(/<\w+:import /).count)
        expect(parsed_schema.includes.count).to eql(schema.scan(/<\w+:include /).count)
        expect(parsed_schema.group.count).to eql(schema.scan(/<\w+:group name=/).count)
        expect(parsed_schema.simple_type.count).to eql(schema.scan(/<\w+:simpleType /).count)
        expect(parsed_schema.element.count).to eql(schema.scan(/^\s{0,2}<\w+:element /).count)
        expect(parsed_schema.complex_type.count).to eql(schema.scan(/<\w+:complexType /).count)
      end

      it "matches parsed schema to xml with the input" do
        processed_xml = schema_to_xml(parsed_schema.to_xml, escape_content_tags: true)
        expect(processed_xml).to be_analogous_with(schema_to_xml(schema))
      end
    end
  end
end
