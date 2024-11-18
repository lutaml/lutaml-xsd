# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd do
  subject(:parsed_schema) { described_class.parse(schema) }

  it "has a version number" do
    expect(Lutaml::Xsd::VERSION).not_to be nil
  end

  Dir.glob(File.expand_path("fixtures/*.xsd", __dir__)).each do |input_file|
    context "when parsing #{input_file}" do
      let(:schema) { File.read(input_file) }

      it "matches a Lutaml::Model::Schema object" do
        expect(parsed_schema).to be_a(Lutaml::Xsd::Schema)
      end

      it "matches count of direct child elements of the root" do
        expect(parsed_schema.import.count).to eql(schema.scan(/<xsd:import /).count)
        expect(parsed_schema.group.count).to eql(schema.scan(/<xsd:group name=/).count)
        expect(parsed_schema.simple_type.count).to eql(schema.scan(/<xsd:simpleType /).count)
        expect(parsed_schema.element.count).to eql(schema.scan(/^\s{0,2}<xsd:element /).count)
        expect(parsed_schema.complex_type.count).to eql(schema.scan(/<xsd:complexType /).count)
      end
    end
  end
end
