# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/filters/schema_filters"

RSpec.describe Lutaml::Xsd::Spa::Filters::SchemaFilters do
  # Include the module to test its methods
  let(:test_class) { Class.new { include Lutaml::Xsd::Spa::Filters::SchemaFilters } }
  subject(:filter) { test_class.new }

  describe "#format_type" do
    it "returns formatted type name" do
      expect(filter.format_type("xs:string")).to eq("xs:string")
    end

    it "strips whitespace" do
      expect(filter.format_type("  xs:string  ")).to eq("xs:string")
    end

    it "returns empty string for nil" do
      expect(filter.format_type(nil)).to eq("")
    end
  end

  describe "#type_icon" do
    it "returns element icon" do
      expect(filter.type_icon("element")).to eq("📦")
    end

    it "returns complex_type icon" do
      expect(filter.type_icon("complex_type")).to eq("🔷")
    end

    it "returns simple_type icon" do
      expect(filter.type_icon("simple_type")).to eq("🔸")
    end

    it "returns attribute icon" do
      expect(filter.type_icon("attribute")).to eq("🏷️")
    end

    it "returns group icon" do
      expect(filter.type_icon("group")).to eq("📂")
    end

    it "returns schema icon" do
      expect(filter.type_icon("schema")).to eq("📄")
    end

    it "returns default icon for unknown type" do
      expect(filter.type_icon("unknown")).to eq("•")
    end
  end

  describe "#format_occurrence" do
    it "formats 0..1 occurrence" do
      expect(filter.format_occurrence("0", "1")).to eq("0..1")
    end

    it "formats 1..1 occurrence (required)" do
      expect(filter.format_occurrence("1", "1")).to eq("1..1")
    end

    it "formats unbounded max occurs" do
      expect(filter.format_occurrence("0", "unbounded")).to eq("0..*")
    end

    it "uses defaults for nil values" do
      expect(filter.format_occurrence(nil, nil)).to eq("1..1")
    end

    it "uses default min when nil" do
      expect(filter.format_occurrence(nil, "5")).to eq("1..5")
    end

    it "uses default max when nil" do
      expect(filter.format_occurrence("2", nil)).to eq("2..1")
    end
  end

  describe "#format_namespace" do
    it "formats XML Schema namespace" do
      ns = "http://www.w3.org/2001/XMLSchema"
      expect(filter.format_namespace(ns)).to eq("xs:")
    end

    it "formats XML namespace" do
      ns = "http://www.w3.org/XML/1998/namespace"
      expect(filter.format_namespace(ns)).to eq("xml:")
    end

    it "formats XLink namespace" do
      ns = "http://www.w3.org/1999/xlink"
      expect(filter.format_namespace(ns)).to eq("xlink:")
    end

    it "returns namespace as-is for unknown" do
      ns = "http://example.com/custom"
      expect(filter.format_namespace(ns)).to eq(ns)
    end

    it "returns empty string for nil" do
      expect(filter.format_namespace(nil)).to eq("")
    end
  end

  describe "#builtin_type?" do
    it "returns true for xs: prefixed types" do
      expect(filter.builtin_type?("xs:string")).to be true
    end

    it "returns true for xsd: prefixed types" do
      expect(filter.builtin_type?("xsd:integer")).to be true
    end

    it "returns true for common type names" do
      expect(filter.builtin_type?("string")).to be true
      expect(filter.builtin_type?("integer")).to be true
      expect(filter.builtin_type?("decimal")).to be true
      expect(filter.builtin_type?("boolean")).to be true
      expect(filter.builtin_type?("date")).to be true
      expect(filter.builtin_type?("time")).to be true
    end

    it "returns false for custom types" do
      expect(filter.builtin_type?("CustomType")).to be false
    end

    it "returns false for nil" do
      expect(filter.builtin_type?(nil)).to be false
    end
  end

  describe "#type_class" do
    it "returns builtin class for builtin types" do
      expect(filter.type_class("xs:string")).to eq("type-builtin")
    end

    it "returns custom class for custom types" do
      expect(filter.type_class("CustomType")).to eq("type-custom")
    end

    it "returns unknown class for nil" do
      expect(filter.type_class(nil)).to eq("type-unknown")
    end
  end

  describe "#format_use" do
    it "returns required for required" do
      expect(filter.format_use("required")).to eq("required")
    end

    it "returns optional for optional" do
      expect(filter.format_use("optional")).to eq("optional")
    end

    it "returns optional for nil" do
      expect(filter.format_use(nil)).to eq("optional")
    end
  end

  describe "#use_badge_class" do
    it "returns badge-required for required" do
      expect(filter.use_badge_class("required")).to eq("badge-required")
    end

    it "returns badge-optional for optional" do
      expect(filter.use_badge_class("optional")).to eq("badge-optional")
    end

    it "returns badge-prohibited for prohibited" do
      expect(filter.use_badge_class("prohibited")).to eq("badge-prohibited")
    end

    it "returns badge-default for unknown" do
      expect(filter.use_badge_class("unknown")).to eq("badge-default")
    end
  end

  describe "#count_items" do
    it "returns count for array" do
      expect(filter.count_items([1, 2, 3])).to eq(3)
    end

    it "returns 0 for empty array" do
      expect(filter.count_items([])).to eq(0)
    end

    it "returns 0 for nil" do
      expect(filter.count_items(nil)).to eq(0)
    end

    it "returns count for any collection with size" do
      expect(filter.count_items("hello")).to eq(5)
    end
  end

  describe "#has_items?" do
    it "returns true for non-empty array" do
      expect(filter.has_items?([1, 2])).to be true
    end

    it "returns false for empty array" do
      expect(filter.has_items?([])).to be false
    end

    it "returns false for nil" do
      expect(filter.has_items?(nil)).to be false
    end
  end

  describe "#format_content_model" do
    it "formats sequence" do
      expect(filter.format_content_model("sequence")).to eq("Sequence")
    end

    it "formats choice" do
      expect(filter.format_content_model("choice")).to eq("Choice")
    end

    it "formats all" do
      expect(filter.format_content_model("all")).to eq("All")
    end

    it "formats complex_content" do
      expect(filter.format_content_model("complex_content")).to eq("Complex Content")
    end

    it "formats simple_content" do
      expect(filter.format_content_model("simple_content")).to eq("Simple Content")
    end

    it "capitalizes unknown models" do
      expect(filter.format_content_model("custom")).to eq("Custom")
    end

    it "returns empty string for nil" do
      expect(filter.format_content_model(nil)).to eq("")
    end
  end

  describe "#content_model_icon" do
    it "returns sequence icon" do
      expect(filter.content_model_icon("sequence")).to eq("→")
    end

    it "returns choice icon" do
      expect(filter.content_model_icon("choice")).to eq("⎇")
    end

    it "returns all icon" do
      expect(filter.content_model_icon("all")).to eq("∀")
    end

    it "returns complex_content icon" do
      expect(filter.content_model_icon("complex_content")).to eq("⊕")
    end

    it "returns simple_content icon" do
      expect(filter.content_model_icon("simple_content")).to eq("⊙")
    end

    it "returns default icon for unknown" do
      expect(filter.content_model_icon("unknown")).to eq("•")
    end
  end
end
