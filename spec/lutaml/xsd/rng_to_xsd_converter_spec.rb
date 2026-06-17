# frozen_string_literal: true

require "spec_helper"
require "rng"
require "lutaml/xsd/rng_to_xsd_converter"

RSpec.describe Lutaml::Xsd::RngToXsdConverter do
  describe "#convert" do
    let(:fixture_path) { "spec/fixtures/converter_test.rnc" }
    let(:grammar) { Rng.parse_file(fixture_path) }
    let(:converter) { described_class.new(grammar, file_path: fixture_path) }
    subject(:schema) { converter.convert }

    it "returns a Schema object" do
      expect(schema).to be_a(Lutaml::Xml::Schema::Xsd::Schema)
    end

    it "sets element form default to qualified" do
      expect(schema.element_form_default).to eq("qualified")
    end

    # --- Complex types ---

    it "produces complex types" do
      expect(schema.complex_type.length).to be >= 1
    end

    it "creates a complex type for named content patterns" do
      ct = schema.complex_type.find { |c| c.name == "test-doc-content" }
      expect(ct).not_to be_nil
      expect(ct.attribute&.map(&:name)).to include("version")
    end

    it "includes elements in complex type sequences" do
      ct = schema.complex_type.find { |c| c.name == "test-doc-content" }
      seq = ct.sequence
      expect(seq).not_to be_nil
      element_names = seq.element&.map { |e| e.name || e.ref }
      expect(element_names).to include("header", "sections", "metadata")
    end

    # --- Elements ---

    it "produces top-level elements" do
      element_names = schema.element.map(&:name)
      expect(element_names).to include("test-doc", "header", "sections", "clause",
                                       "note", "admonition", "metadata")
    end

    it "promotes named-pattern elements to top-level" do
      element_names = schema.element.map(&:name)
      expect(element_names).to include("title", "bold", "italic", "p")
    end

    it "creates elements with complex types containing sequences" do
      clause = schema.element.find { |e| e.name == "clause" }
      expect(clause).not_to be_nil
      expect(clause.complex_type).not_to be_nil
      expect(clause.complex_type.sequence).not_to be_nil
    end

    # --- Groups ---

    it "produces groups for named patterns" do
      group_names = schema.group.map(&:name)
      expect(group_names).to include("paragraph")
    end

    # --- Attribute groups ---

    it "produces attribute groups" do
      expect(schema.attribute_group.length).to be >= 1
    end

    it "creates AdmonitionAttributes with correct attributes" do
      ag = schema.attribute_group.find { |g| g.name == "AdmonitionAttributes" }
      expect(ag).not_to be_nil
      attr_names = ag.attribute.map(&:name)
      expect(attr_names).to include("type", "url")
    end

    # --- Validity ---

    it "produces valid XSD output" do
      expect { schema.to_formatted_xml }.not_to raise_error
    end
    end
  end

  describe "named pattern resolution" do
    def parse_and_convert(rnc_content)
      require "tempfile"

      Tempfile.create(["test", ".rnc"]) do |f|
        f.write(rnc_content)
        f.flush
        grammar = Rng.parse_file(f.path)
        converter = Lutaml::Xsd::RngToXsdConverter.new(grammar, file_path: f.path)
        converter.convert
      end
    end

    context "when a named pattern wraps a single element with a different name" do
      let(:rnc) do
        <<~RNC
          element root {
            (ext_toc & element email { text })
          }

          ext_toc = element name { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("name")
      end

      it "creates a schema-level group for the named pattern" do
        names = schema.group.map(&:name)
        expect(names).to include("ext_toc")
      end

      it "resolves the named pattern to an element ref inside interleave/all" do
        root = schema.element.find { |e| e.name == "root" }
        expect(root).not_to be_nil

        all = root.complex_type.all
        expect(all).not_to be_nil

        all.element.each do |el|
          expect(el).to be_a(Lutaml::Xml::Schema::Xsd::Element)
        end

        name_ref = all.element.find { |el| el.ref == "name" }
        expect(name_ref).not_to be_nil
        expect(name_ref.ref).to eq("name")

        expect(all.element.any? { |el| el.ref == "ext_toc" }).to be false
      end

      it "produces valid XSD output" do
        expect { schema.to_formatted_xml }.not_to raise_error
      end
    end

    context "when a named pattern wraps a single element with a matching name" do
      let(:rnc) do
        <<~RNC
          element root {
            (foo & element bar { text })
          }

          foo = element foo { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("foo")
      end

      it "resolves the named pattern to an element ref inside interleave/all" do
        root = schema.element.find { |e| e.name == "root" }
        all = root.complex_type.all

        foo_ref = all.element.find { |el| el.ref == "foo" }
        expect(foo_ref).not_to be_nil
      end
    end

    context "when a named pattern is referenced directly (not inside interleave)" do
      let(:rnc) do
        <<~RNC
          element root {
            ext_toc
          }

          ext_toc = element name { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("name")
      end

      it "creates a group for the named pattern" do
        names = schema.group.map(&:name)
        expect(names).to include("ext_toc")
      end

      it "resolves to an element ref in the content model" do
        root = schema.element.find { |e| e.name == "root" }
        seq = root.complex_type.sequence

        name_ref = seq.element.find { |el| el.ref == "name" }
        expect(name_ref).not_to be_nil
      end
    end

    context "when multiple defines wrap elements with the same name (collision)" do
      let(:rnc) do
        <<~RNC
          element root {
            (a_ref | b_ref)
          }

          a_ref = element item { text }
          b_ref = element item { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "does not promote colliding elements to top-level" do
        names = schema.element.map(&:name)
        expect(names).not_to include("item")
      end

      it "creates groups for both defines" do
        names = schema.group.map(&:name)
        expect(names).to include("a_ref", "b_ref")
      end
    end
  end
end
