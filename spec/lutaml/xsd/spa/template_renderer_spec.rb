# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/template_renderer"

RSpec.describe Lutaml::Xsd::Spa::TemplateRenderer do
  let(:temp_template_dir) { Dir.mktmpdir }
  let(:template_content) { "Hello {{ name }}!" }
  let(:layout_content) { "<html><body>{{ content }}</body></html>" }
  let(:partial_content) { "<div>{{ title }}</div>" }

  subject(:renderer) { described_class.new(template_dir: temp_template_dir) }

  after do
    FileUtils.remove_entry(temp_template_dir) if Dir.exist?(temp_template_dir)
  end

  describe "#initialize" do
    it "uses default template directory when not specified" do
      default_renderer = described_class.new
      expect(default_renderer.template_dir).to eq(described_class::DEFAULT_TEMPLATE_DIR)
    end

    it "accepts custom template directory" do
      expect(renderer.template_dir).to eq(temp_template_dir)
    end

    it "enables caching by default" do
      renderer = described_class.new(template_dir: temp_template_dir)
      expect(renderer.instance_variable_get(:@cache_enabled)).to be true
    end

    it "accepts cache_enabled option" do
      renderer = described_class.new(
        template_dir: temp_template_dir,
        cache_enabled: false
      )
      expect(renderer.instance_variable_get(:@cache_enabled)).to be false
    end

    it "creates Liquid file system" do
      expect(renderer.file_system).to be_a(Liquid::LocalFileSystem)
      expect(renderer.file_system.root).to eq(temp_template_dir)
    end
  end

  describe "#render" do
    before do
      File.write(
        File.join(temp_template_dir, "test.liquid"),
        template_content
      )
    end

    context "when template exists" do
      it "renders template with context" do
        result = renderer.render("test", { name: "World" })
        expect(result).to eq("Hello World!")
      end

      it "accepts symbol keys in context" do
        result = renderer.render("test", { name: "World" })
        expect(result).to eq("Hello World!")
      end

      it "accepts string keys in context" do
        result = renderer.render("test", { "name" => "World" })
        expect(result).to eq("Hello World!")
      end

      it "handles template name without .liquid extension" do
        result = renderer.render("test", { name: "Test" })
        expect(result).to eq("Hello Test!")
      end

      it "handles template name with .liquid extension" do
        result = renderer.render("test.liquid", { name: "Test" })
        expect(result).to eq("Hello Test!")
      end
    end

    context "when template does not exist" do
      it "raises ArgumentError" do
        expect do
          renderer.render("nonexistent", {})
        end.to raise_error(ArgumentError, /Template not found/)
      end
    end

    context "with caching enabled" do
      it "caches compiled templates" do
        renderer.render("test", { name: "First" })

        # Delete the file
        File.delete(File.join(temp_template_dir, "test.liquid"))

        # Should still work from cache
        result = renderer.render("test", { name: "Second" })
        expect(result).to eq("Hello Second!")
      end
    end

    context "with caching disabled" do
      let(:renderer) do
        described_class.new(
          template_dir: temp_template_dir,
          cache_enabled: false
        )
      end

      it "does not cache templates" do
        renderer.render("test", { name: "First" })

        # Modify the file
        File.write(
          File.join(temp_template_dir, "test.liquid"),
          "Goodbye {{ name }}!"
        )

        # Should read from file again
        result = renderer.render("test", { name: "Second" })
        expect(result).to eq("Goodbye Second!")
      end
    end
  end

  describe "#render_string" do
    it "renders template string with context" do
      result = renderer.render_string("Hello {{ name }}!", { name: "World" })
      expect(result).to eq("Hello World!")
    end

    it "accepts symbol keys in context" do
      result = renderer.render_string("{{ value }}", { value: 42 })
      expect(result).to eq("42")
    end

    it "does not use file system" do
      result = renderer.render_string("{{ x }} + {{ y }}", { x: 1, y: 2 })
      expect(result).to eq("1 + 2")
    end
  end

  describe "#register_filter" do
    let(:test_filter_module) do
      Module.new do
        def upcase(text)
          text.to_s.upcase
        end

        def reverse(text)
          text.to_s.reverse
        end
      end
    end

    before do
      File.write(
        File.join(temp_template_dir, "filter_test.liquid"),
        "{{ name | upcase }}"
      )
    end

    it "registers custom filter module" do
      renderer.register_filter(test_filter_module)
      result = renderer.render("filter_test", { name: "hello" })

      expect(result).to eq("HELLO")
    end

    it "allows chaining filters" do
      renderer.register_filter(test_filter_module)
      result = renderer.render_string("{{ name | upcase | reverse }}", { name: "hello" })

      expect(result).to eq("OLLEH")
    end
  end

  describe "#clear_cache" do
    before do
      File.write(
        File.join(temp_template_dir, "cached.liquid"),
        "Original: {{ value }}"
      )
    end

    it "clears template cache" do
      # Load template
      renderer.render("cached", { value: "first" })

      # Modify file
      File.write(
        File.join(temp_template_dir, "cached.liquid"),
        "Modified: {{ value }}"
      )

      # Clear cache
      renderer.clear_cache

      # Should load modified template
      result = renderer.render("cached", { value: "second" })
      expect(result).to eq("Modified: second")
    end
  end

  describe "#template_exists?" do
    before do
      File.write(
        File.join(temp_template_dir, "exists.liquid"),
        "Content"
      )
    end

    it "returns true for existing template" do
      expect(renderer.template_exists?("exists")).to be true
    end

    it "returns true for template with .liquid extension" do
      expect(renderer.template_exists?("exists.liquid")).to be true
    end

    it "returns false for non-existing template" do
      expect(renderer.template_exists?("nonexistent")).to be false
    end
  end

  describe "#template_path" do
    it "returns full path to template" do
      path = renderer.template_path("test")
      expect(path).to eq(File.join(temp_template_dir, "test.liquid"))
    end

    it "adds .liquid extension if not present" do
      path = renderer.template_path("test")
      expect(path).to end_with(".liquid")
    end

    it "does not add .liquid extension if already present" do
      path = renderer.template_path("test.liquid")
      expect(path).to end_with(".liquid")
      expect(path).not_to end_with(".liquid.liquid")
    end
  end

  describe "#render_partial" do
    before do
      FileUtils.mkdir_p(File.join(temp_template_dir, "components"))
      File.write(
        File.join(temp_template_dir, "components", "header.liquid"),
        partial_content
      )
    end

    it "renders partial from partials directory" do
      result = renderer.render_partial("header", { title: "Test Title" })
      expect(result).to eq("<div>Test Title</div>")
    end
  end

  describe "edge cases" do
    it "handles empty context" do
      File.write(
        File.join(temp_template_dir, "empty.liquid"),
        "No variables"
      )

      result = renderer.render("empty", {})
      expect(result).to eq("No variables")
    end

    it "handles nil values in context" do
      File.write(
        File.join(temp_template_dir, "nil.liquid"),
        "Value: {{ value }}"
      )

      result = renderer.render("nil", { value: nil })
      expect(result).to eq("Value: ")
    end

    it "handles complex nested data" do
      File.write(
        File.join(temp_template_dir, "nested.liquid"),
        "{{ user.name }} - {{ user.email }}"
      )

      result = renderer.render("nested", {
        user: { name: "John", email: "john@example.com" }
      })
      expect(result).to eq("John - john@example.com")
    end

    it "handles arrays in context" do
      File.write(
        File.join(temp_template_dir, "array.liquid"),
        "{% for item in items %}{{ item }}{% endfor %}"
      )

      result = renderer.render("array", { items: [1, 2, 3] })
      expect(result).to eq("123")
    end

    it "handles Liquid control structures" do
      File.write(
        File.join(temp_template_dir, "if.liquid"),
        "{% if show %}Visible{% endif %}"
      )

      result = renderer.render("if", { show: true })
      expect(result).to eq("Visible")
    end
  end

  describe "Liquid configuration" do
    it "sets file system" do
      expect(renderer.environment.file_system).to be_a(Liquid::LocalFileSystem)
    end

    it "sets error mode to strict" do
      expect(renderer.environment.error_mode).to eq(:strict)
    end
  end

  describe "error handling" do
    it "raises Liquid::SyntaxError for invalid template syntax" do
      File.write(
        File.join(temp_template_dir, "invalid.liquid"),
        "{% if %}"
      )

      expect do
        renderer.render("invalid", {})
      end.to raise_error(Liquid::SyntaxError)
    end

    it "provides helpful error message for missing template" do
      expect do
        renderer.render("missing", {})
      end.to raise_error(ArgumentError, /Template not found.*missing/)
    end
  end

  describe "performance" do
    it "reuses cached templates for better performance" do
      File.write(
        File.join(temp_template_dir, "perf.liquid"),
        "{{ value }}"
      )

      # First render compiles and caches
      renderer.render("perf", { value: 1 })

      # Subsequent renders should be faster (cached)
      10.times do |i|
        result = renderer.render("perf", { value: i })
        expect(result).to eq(i.to_s)
      end
    end
  end
end