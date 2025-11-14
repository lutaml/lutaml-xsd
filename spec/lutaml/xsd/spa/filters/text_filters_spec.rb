# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/filters/text_filters"

RSpec.describe Lutaml::Xsd::Spa::Filters::TextFilters do
  let(:test_class) { Class.new { include Lutaml::Xsd::Spa::Filters::TextFilters } }
  subject(:filter) { test_class.new }

  describe "#truncate_text" do
    it "truncates long text" do
      text = "a" * 150
      result = filter.truncate_text(text, 100)

      expect(result.length).to be <= 100
      expect(result).to end_with("...")
    end

    it "does not truncate short text" do
      text = "Short text"
      result = filter.truncate_text(text, 100)

      expect(result).to eq(text)
    end

    it "uses custom omission" do
      text = "a" * 150
      result = filter.truncate_text(text, 100, " [more]")

      expect(result).to end_with(" [more]")
    end

    it "returns empty string for nil" do
      expect(filter.truncate_text(nil)).to eq("")
    end
  end

  describe "#capitalize_first" do
    it "capitalizes first letter" do
      expect(filter.capitalize_first("hello")).to eq("Hello")
    end

    it "handles already capitalized" do
      expect(filter.capitalize_first("Hello")).to eq("Hello")
    end

    it "returns empty string for nil" do
      expect(filter.capitalize_first(nil)).to eq("")
    end
  end

  describe "#titleize" do
    it "converts to title case" do
      expect(filter.titleize("hello world")).to eq("Hello World")
    end

    it "handles underscores" do
      expect(filter.titleize("hello_world")).to eq("Hello World")
    end

    it "handles hyphens" do
      expect(filter.titleize("hello-world")).to eq("Hello World")
    end

    it "returns empty string for nil" do
      expect(filter.titleize(nil)).to eq("")
    end
  end

  describe "#slugify" do
    it "converts to slug" do
      expect(filter.slugify("Hello World")).to eq("hello-world")
    end

    it "removes special characters" do
      expect(filter.slugify("Hello @World!")).to eq("hello-world")
    end

    it "handles multiple spaces" do
      expect(filter.slugify("Hello    World")).to eq("hello-world")
    end

    it "trims edge dashes" do
      expect(filter.slugify("-Hello World-")).to eq("hello-world")
    end

    it "returns empty string for nil" do
      expect(filter.slugify(nil)).to eq("")
    end
  end

  describe "#pluralize" do
    it "returns singular for count of 1" do
      expect(filter.pluralize(1, "item")).to eq("item")
    end

    it "returns plural for count > 1" do
      expect(filter.pluralize(2, "item")).to eq("items")
    end

    it "returns plural for count of 0" do
      expect(filter.pluralize(0, "item")).to eq("items")
    end

    it "uses custom plural form" do
      expect(filter.pluralize(2, "child", "children")).to eq("children")
    end
  end

  describe "#number_with_delimiter" do
    it "formats thousands" do
      expect(filter.number_with_delimiter(1000)).to eq("1,000")
    end

    it "formats millions" do
      expect(filter.number_with_delimiter(1000000)).to eq("1,000,000")
    end

    it "uses custom separator" do
      expect(filter.number_with_delimiter(1000, " ")).to eq("1 000")
    end

    it "returns empty string for nil" do
      expect(filter.number_with_delimiter(nil)).to eq("")
    end
  end

  describe "#strip_html" do
    it "removes HTML tags" do
      html = "<p>Hello <strong>World</strong></p>"
      expect(filter.strip_html(html)).to eq("Hello World")
    end

    it "handles self-closing tags" do
      html = "Hello<br/>World"
      expect(filter.strip_html(html)).to eq("HelloWorld")
    end

    it "returns empty string for nil" do
      expect(filter.strip_html(nil)).to eq("")
    end
  end

  describe "#escape_html" do
    it "escapes ampersand" do
      expect(filter.escape_html("a & b")).to include("&amp;")
    end

    it "escapes less than" do
      expect(filter.escape_html("a < b")).to include("&lt;")
    end

    it "escapes greater than" do
      expect(filter.escape_html("a > b")).to include("&gt;")
    end

    it "escapes quotes" do
      expect(filter.escape_html('"test"')).to include("&quot;")
    end

    it "escapes apostrophes" do
      expect(filter.escape_html("it's")).to include("&#39;")
    end

    it "returns empty string for nil" do
      expect(filter.escape_html(nil)).to eq("")
    end
  end

  describe "#nl2br" do
    it "converts newlines to br tags" do
      text = "Line 1\nLine 2"
      result = filter.nl2br(text)

      expect(result).to include("<br>")
    end

    it "preserves original newlines" do
      text = "Line 1\nLine 2"
      result = filter.nl2br(text)

      expect(result).to include("\n")
    end

    it "returns empty string for nil" do
      expect(filter.nl2br(nil)).to eq("")
    end
  end

  describe "#paragraphize" do
    it "wraps text in p tags" do
      text = "Paragraph"
      result = filter.paragraphize(text)

      expect(result).to eq("<p>Paragraph</p>")
    end

    it "creates multiple paragraphs" do
      text = "Para 1\n\nPara 2"
      result = filter.paragraphize(text)

      expect(result).to include("<p>Para 1</p>")
      expect(result).to include("<p>Para 2</p>")
    end

    it "returns empty string for nil" do
      expect(filter.paragraphize(nil)).to eq("")
    end
  end

  describe "#highlight" do
    it "highlights search term" do
      text = "Hello World"
      result = filter.highlight(text, "World")

      expect(result).to include("<mark>World</mark>")
    end

    it "is case insensitive" do
      text = "Hello World"
      result = filter.highlight(text, "world")

      expect(result).to include("<mark>World</mark>")
    end

    it "uses custom tag" do
      text = "Hello World"
      result = filter.highlight(text, "World", "strong")

      expect(result).to include("<strong>World</strong>")
    end

    it "returns original text when term is nil" do
      text = "Hello World"
      expect(filter.highlight(text, nil)).to eq(text)
    end

    it "returns text when text is nil" do
      expect(filter.highlight(nil, "term")).to be_nil
    end
  end

  describe "#smart_truncate" do
    it "truncates at word boundary" do
      text = "The quick brown fox jumps over the lazy dog"
      result = filter.smart_truncate(text, 20)

      expect(result).not_to include("fox")
      expect(result).to end_with("...")
    end

    it "does not truncate short text" do
      text = "Short"
      result = filter.smart_truncate(text, 100)

      expect(result).to eq(text)
    end

    it "returns empty string for nil" do
      expect(filter.smart_truncate(nil)).to eq("")
    end
  end

  describe "#first_sentence" do
    it "extracts first sentence" do
      text = "First sentence. Second sentence."
      expect(filter.first_sentence(text)).to eq("First sentence.")
    end

    it "handles question marks" do
      text = "Is this first? This is second."
      expect(filter.first_sentence(text)).to eq("Is this first?")
    end

    it "handles exclamation marks" do
      text = "Hello! How are you?"
      expect(filter.first_sentence(text)).to eq("Hello!")
    end

    it "returns whole text if no sentence ending" do
      text = "No sentence ending"
      expect(filter.first_sentence(text)).to eq(text)
    end

    it "returns empty string for nil" do
      expect(filter.first_sentence(nil)).to eq("")
    end
  end

  describe "#word_count" do
    it "counts words" do
      text = "The quick brown fox"
      expect(filter.word_count(text)).to eq(4)
    end

    it "handles multiple spaces" do
      text = "The  quick   brown"
      expect(filter.word_count(text)).to eq(3)
    end

    it "returns 0 for nil" do
      expect(filter.word_count(nil)).to eq(0)
    end
  end

  describe "#code_block" do
    it "wraps in code block" do
      code = "const x = 1;"
      result = filter.code_block(code)

      expect(result).to include("<pre><code>")
      expect(result).to include("</code></pre>")
    end

    it "includes language class" do
      code = "const x = 1;"
      result = filter.code_block(code, "javascript")

      expect(result).to include('class="language-javascript"')
    end

    it "escapes HTML in code" do
      code = "<script>alert('xss')</script>"
      result = filter.code_block(code)

      expect(result).to include("&lt;script&gt;")
    end

    it "returns empty string for nil" do
      expect(filter.code_block(nil)).to eq("")
    end
  end

  describe "#inline_code" do
    it "wraps in inline code tag" do
      code = "x = 1"
      result = filter.inline_code(code)

      expect(result).to eq("<code>x = 1</code>")
    end

    it "escapes HTML" do
      code = "<tag>"
      result = filter.inline_code(code)

      expect(result).to include("&lt;tag&gt;")
    end

    it "returns empty string for nil" do
      expect(filter.inline_code(nil)).to eq("")
    end
  end
end