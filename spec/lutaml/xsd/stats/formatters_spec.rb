# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/stats/formatters"
require "json"
require "yaml"

RSpec.describe Lutaml::Xsd::Stats::Formatters do
  let(:stats) do
    {
      total_schemas: 3,
      total_types: 12,
      types_by_category: { complex_type: 7, simple_type: 5 },
      total_namespaces: 2,
      namespace_prefixes: 2,
      resolved: true,
      validated: false,
    }
  end

  describe ".lookup" do
    it "returns TextFormat for :text" do
      expect(described_class.lookup(:text)).to eq(
        Lutaml::Xsd::Stats::Formatters::TextFormat,
      )
    end

    it "returns JsonFormat for :json" do
      expect(described_class.lookup(:json)).to eq(
        Lutaml::Xsd::Stats::Formatters::JsonFormat,
      )
    end

    it "returns YamlFormat for :yaml" do
      expect(described_class.lookup(:yaml)).to eq(
        Lutaml::Xsd::Stats::Formatters::YamlFormat,
      )
    end

    it "raises ArgumentError for unregistered formats" do
      expect { described_class.lookup(:html) }
        .to raise_error(ArgumentError, /Unknown format: html/)
    end

    it "normalizes string format names" do
      expect(described_class.lookup("json")).to eq(
        Lutaml::Xsd::Stats::Formatters::JsonFormat,
      )
    end
  end

  describe ".render with text format" do
    subject(:output) { described_class.render(stats, format: :text) }

    it { is_expected.to start_with("Schema Repository Statistics") }
    it { is_expected.to include("Total Schemas: 3") }
    it { is_expected.to include("Total Types: 12") }
    it { is_expected.to include("Total Namespaces: 2") }
    it { is_expected.to include("Namespace Prefixes: 2") }
    it { is_expected.to include("Types by Category:") }
    it { is_expected.to include("complex_type: 7") }
    it { is_expected.to include("simple_type: 5") }
    it { is_expected.to include("Resolved: true") }
    it { is_expected.to include("Validated: false") }
  end

  describe ".render with json format" do
    subject(:output) { described_class.render(stats, format: :json) }

    it "produces valid JSON" do
      parsed = JSON.parse(output)
      expect(parsed).to be_a(Hash)
      expect(parsed["total_schemas"]).to eq(3)
      expect(parsed["total_types"]).to eq(12)
      expect(parsed["types_by_category"]).to eq(
        "complex_type" => 7, "simple_type" => 5,
      )
    end
  end

  describe ".render with yaml format" do
    subject(:output) { described_class.render(stats, format: :yaml) }

    it "produces valid YAML" do
      parsed = YAML.safe_load(output, permitted_classes: [Symbol])
      expect(parsed).to be_a(Hash)
      key = parsed.key?("total_schemas") ? "total_schemas" : :total_schemas
      expect(parsed[key]).to eq(3)
    end
  end

  describe ".render with unknown format" do
    it "raises ArgumentError" do
      expect { described_class.render(stats, format: :html) }
        .to raise_error(ArgumentError, /Unknown format: html/)
    end
  end

  describe "Base subclass contract" do
    it "raises NotImplementedError when .render is not overridden" do
      expect { Lutaml::Xsd::Stats::Formatters::Base.render(stats) }
        .to raise_error(NotImplementedError, /must implement \.render/)
    end
  end

  describe "registry extensibility" do
    it "allows registering a new format" do
      stub_const("HtmlProbe", Class.new(Lutaml::Xsd::Stats::Formatters::Base) do
        def self.render(_stats) = "<html></html>"
      end)

      described_class.register(:html_probe, HtmlProbe)
      expect(described_class.lookup(:html_probe)).to eq(HtmlProbe)
      expect(described_class.render(stats, format: :html_probe))
        .to eq("<html></html>")
    end
  end
end
