# frozen_string_literal: true

RSpec.describe Lutaml::Xsd do
  subject(:parsed_schema) { described_class.parse(schema) }

  context 'when parsing schema unitsml-v1.0-csd03.xsd' do
    let(:schema) { File.read('spec/fixtures/unitsml-v1.0-csd03.xsd') }
    let(:liquid_file_content) { File.read('spec/fixtures/liquid_templates/_elements.liquid') }

    it 'parsed schema round-trips the XSD' do
      processed_xml = parsed_schema.to_xml
      doc = Nokogiri::XML(schema)
      doc.xpath('//comment()').remove
      no_comments_schema = doc.to_s
      expect(processed_xml).to be_xml_equivalent_to(no_comments_schema)
    end

    it 'parsed schema to_liquid matches count of direct child elements of the root' do
      render_options = { 'schema' => parsed_schema.to_liquid }
      template_output = Liquid::Template.parse(liquid_file_content).render(render_options)
      expect(template_output).to match(/^Elements:\s+Name: \*UnitsML\*/)
      expect(template_output).to match(/^ComplexTypes:\s+Name: \*UnitsMLType\*/)
    end
  end
end