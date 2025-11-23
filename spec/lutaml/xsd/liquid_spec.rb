# frozen_string_literal: true

RSpec.describe Lutaml::Xsd do
  subject(:parsed_schema) { described_class.parse(schema) }

  context 'when parsing schema unitsml-v1.0-csd03.xsd' do
    let(:schema) { File.read('spec/fixtures/unitsml-v1.0-csd03.xsd') }
    let(:liquid_file_content) { File.read('spec/fixtures/liquid_templates/_elements.liquid') }

    it 'matches the parsed' do
      processed_xml = schema_to_xml(parsed_schema.to_xml, escape_content_tags: true)
      expect(processed_xml).to be_analogous_with(schema_to_xml(schema))
    end

    it 'matches count of direct child elements of the root' do
      render_options = { 'schema' => parsed_schema.to_liquid }
      template_output = Liquid::Template.parse(liquid_file_content).render(render_options)
      expect(template_output).to match(/^Elements:\s+Name: \*UnitsML\*/)
      expect(template_output).to match(/^ComplexTypes:\s+Name: \*UnitsMLType\*/)
    end
  end
end
