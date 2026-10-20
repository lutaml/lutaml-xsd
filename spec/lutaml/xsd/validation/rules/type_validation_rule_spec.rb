# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "lutaml/xsd/validation/rules/type_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/engine_context"

ENGINE_SUPPORTED = Lutaml::Xsd::Validation::EngineContext.xsd_supported?(
  Moxml::Context.new,
)

RSpec.describe Lutaml::Xsd::Validation::Rules::TypeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="date" type="xs:date"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:schema_element) { schema.element.first }

  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/date" }
    end
  end
  let(:xml_element) do
    Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator)
  end

  let(:engine_repository) do
    Class.new do
      def initialize(schemas)
        @schemas = schemas
      end

      def all_schemas
        @schemas
      end
    end.new({ "http://example.com/test" => schema })
  end
  let(:engine) do
    Lutaml::Xsd::Validation::EngineContext.compile(
      engine_repository, context: Moxml::Context.new
    )
  end
  let(:engine_rule) { described_class.new(engine_context: engine) }

  describe "#validate with engine context", if: ENGINE_SUPPORTED do
    context "with a builtin-typed element" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>2024-01-15</date>").root
      end

      it "accepts valid lexical values" do
        engine_rule.validate(xml_element, schema_element, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with an invalid builtin lexical value" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>not-a-date</date>").root
      end

      it "reports a type error" do
        engine_rule.validate(xml_element, schema_element, collector)

        codes = collector.errors.map(&:code)
        expect(codes).to include("type_validation_error")
      end
    end

    context "when the engine cannot answer" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>2024-01-15</date>").root
      end
      let(:empty_engine) do
        described_class.new(engine_context: nil)
      end

      it "falls back to existing (no-op) behavior" do
        empty_engine.validate(xml_element, schema_element, collector)

        expect(collector.errors).to be_empty
      end
    end
  end

  describe "#validate without engine context" do
    let(:moxml_element) do
      Moxml::Context.new.parse("<date>not-a-date</date>").root
    end

    it "keeps the existing no-op builtin behavior" do
      rule.validate(xml_element, schema_element, collector)

      expect(collector.errors).to be_empty
    end
  end
end
