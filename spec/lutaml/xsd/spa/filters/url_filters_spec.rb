# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/filters/url_filters"

RSpec.describe Lutaml::Xsd::Spa::Filters::UrlFilters do
  let(:test_class) { Class.new { include Lutaml::Xsd::Spa::Filters::UrlFilters } }
  subject(:filter) { test_class.new }

  describe "#url_encode" do
    it "encodes spaces" do
      expect(filter.url_encode("hello world")).to eq("hello+world")
    end

    it "encodes special characters" do
      expect(filter.url_encode("a&b=c")).to include("%")
    end

    it "returns empty string for nil" do
      expect(filter.url_encode(nil)).to eq("")
    end
  end

  describe "#url_decode" do
    it "decodes spaces" do
      expect(filter.url_decode("hello+world")).to eq("hello world")
    end

    it "decodes special characters" do
      encoded = filter.url_encode("a&b=c")
      expect(filter.url_decode(encoded)).to eq("a&b=c")
    end

    it "returns empty string for nil" do
      expect(filter.url_decode(nil)).to eq("")
    end
  end

  describe "#anchor_id" do
    it "converts to lowercase" do
      expect(filter.anchor_id("HelloWorld")).to eq("helloworld")
    end

    it "replaces spaces with hyphens" do
      expect(filter.anchor_id("Hello World")).to eq("hello-world")
    end

    it "removes special characters" do
      expect(filter.anchor_id("Hello@World!")).to eq("helloworld")
    end

    it "removes leading/trailing hyphens" do
      expect(filter.anchor_id("-Hello-")).to eq("hello")
    end

    it "returns empty string for nil" do
      expect(filter.anchor_id(nil)).to eq("")
    end
  end

  describe "#link_to_id" do
    it "creates link with anchor" do
      result = filter.link_to_id("my-id", "My Link")

      expect(result).to include('href="#my-id"')
      expect(result).to include(">My Link<")
    end

    it "uses ID as text when text not provided" do
      result = filter.link_to_id("my-id")

      expect(result).to include(">my-id<")
    end

    it "returns empty string for nil ID" do
      expect(filter.link_to_id(nil)).to eq("")
    end
  end

  describe "#link_to_schema_item" do
    it "creates schema item link" do
      result = filter.link_to_schema_item("schema-1", "element", "item-1", "Item")

      expect(result).to include('href="#')
      expect(result).to include('class="schema-link"')
      expect(result).to include(">Item<")
    end

    it "uses item_id as text when text not provided" do
      result = filter.link_to_schema_item("schema-1", "element", "item-1")

      expect(result).to include(">item-1<")
    end

    it "returns empty string for nil parameters" do
      expect(filter.link_to_schema_item(nil, "type", "id")).to eq("")
      expect(filter.link_to_schema_item("schema", nil, "id")).to eq("")
      expect(filter.link_to_schema_item("schema", "type", nil)).to eq("")
    end
  end

  describe "#external_link" do
    it "creates external link" do
      result = filter.external_link("http://example.com", "Example")

      expect(result).to include('href="http://example.com"')
      expect(result).to include('target="_blank"')
      expect(result).to include('rel="noopener noreferrer"')
      expect(result).to include(">Example")
    end

    it "includes external icon by default" do
      result = filter.external_link("http://example.com", "Example")

      expect(result).to include("↗")
    end

    it "omits external icon when requested" do
      result = filter.external_link("http://example.com", "Example", external_icon: false)

      expect(result).not_to include("↗")
    end

    it "returns empty string for nil URL" do
      expect(filter.external_link(nil, "text")).to eq("")
    end

    it "returns empty string for nil text" do
      expect(filter.external_link("http://example.com", nil)).to eq("")
    end
  end

  describe "#add_url_param" do
    it "adds parameter to URL without query string" do
      result = filter.add_url_param("http://example.com", "page", "2")

      expect(result).to eq("http://example.com?page=2")
    end

    it "adds parameter to URL with existing query string" do
      result = filter.add_url_param("http://example.com?foo=bar", "page", "2")

      expect(result).to include("foo=bar")
      expect(result).to include("page=2")
      expect(result).to include("&")
    end

    it "URL encodes parameter values" do
      result = filter.add_url_param("http://example.com", "q", "hello world")

      expect(result).to include("hello+world")
    end

    it "returns original URL when param is nil" do
      url = "http://example.com"
      expect(filter.add_url_param(url, nil, "value")).to eq(url)
    end
  end

  describe "#build_url" do
    it "builds URL with parameters" do
      result = filter.build_url("http://example.com", { "page" => "2", "sort" => "asc" })

      expect(result).to include("?")
      expect(result).to include("page=2")
      expect(result).to include("sort=asc")
    end

    it "URL encodes parameters" do
      result = filter.build_url("http://example.com", { "q" => "hello world" })

      expect(result).to include("hello+world")
    end

    it "returns base URL when params is nil" do
      url = "http://example.com"
      expect(filter.build_url(url, nil)).to eq(url)
    end

    it "returns base URL when params is empty" do
      url = "http://example.com"
      expect(filter.build_url(url, {})).to eq(url)
    end
  end

  describe "#asset_path" do
    it "returns asset path without type" do
      expect(filter.asset_path("app.js")).to eq("app.js")
    end

    it "prepends asset type" do
      expect(filter.asset_path("app.js", "js")).to eq("js/app.js")
    end
  end

  describe "#mailto_link" do
    it "creates mailto link" do
      result = filter.mailto_link("test@example.com")

      expect(result).to include('href="mailto:test@example.com"')
      expect(result).to include(">test@example.com<")
    end

    it "uses custom text" do
      result = filter.mailto_link("test@example.com", "Email Me")

      expect(result).to include(">Email Me<")
    end

    it "returns empty string for nil" do
      expect(filter.mailto_link(nil)).to eq("")
    end
  end

  describe "#external_url?" do
    it "returns true for http URLs" do
      expect(filter.external_url?("http://example.com")).to be true
    end

    it "returns true for https URLs" do
      expect(filter.external_url?("https://example.com")).to be true
    end

    it "returns true for protocol-relative URLs" do
      expect(filter.external_url?("//example.com")).to be true
    end

    it "returns false for relative paths" do
      expect(filter.external_url?("/path/to/page")).to be false
    end

    it "returns false for nil" do
      expect(filter.external_url?(nil)).to be false
    end
  end

  describe "#file_extension" do
    it "returns extension without dot" do
      expect(filter.file_extension("file.txt")).to eq("txt")
    end

    it "handles multiple dots" do
      expect(filter.file_extension("archive.tar.gz")).to eq("gz")
    end

    it "returns empty string for no extension" do
      expect(filter.file_extension("file")).to eq("")
    end

    it "returns empty string for nil" do
      expect(filter.file_extension(nil)).to eq("")
    end
  end

  describe "#filename_from_path" do
    it "extracts filename with extension" do
      expect(filter.filename_from_path("/path/to/file.txt")).to eq("file.txt")
    end

    it "extracts filename without extension" do
      result = filter.filename_from_path("/path/to/file.txt", include_ext: false)

      expect(result).to eq("file")
    end

    it "returns empty string for nil" do
      expect(filter.filename_from_path(nil)).to eq("")
    end
  end

  describe "#breadcrumb" do
    let(:parts) do
      [
        { text: "Home", url: "/" },
        { text: "Docs", url: "/docs" },
        { text: "Current" }
      ]
    end

    it "creates breadcrumb navigation" do
      result = filter.breadcrumb(parts)

      expect(result).to include("Home")
      expect(result).to include("Docs")
      expect(result).to include("Current")
    end

    it "makes last item current (not a link)" do
      result = filter.breadcrumb(parts)

      expect(result).to include('class="breadcrumb-current">Current')
    end

    it "creates links for non-last items" do
      result = filter.breadcrumb(parts)

      expect(result).to include('href="/"')
      expect(result).to include('href="/docs"')
    end

    it "includes separator" do
      result = filter.breadcrumb(parts)

      expect(result).to include("›")
    end

    it "uses custom separator" do
      result = filter.breadcrumb(parts, separator: "»")

      expect(result).to include("»")
    end

    it "returns empty string for nil" do
      expect(filter.breadcrumb(nil)).to eq("")
    end

    it "returns empty string for empty array" do
      expect(filter.breadcrumb([])).to eq("")
    end

    it "handles parts without URLs" do
      parts = [{ text: "Item" }]
      result = filter.breadcrumb(parts)

      expect(result).to include('class="breadcrumb-current"')
    end
  end
end