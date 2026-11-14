# frozen_string_literal: true

require "lutaml/xsd/cli"
require "lutaml/xsd/schema_repository_package"
require "json"
require "net/http"
require "tmpdir"

RSpec.describe Lutaml::Xsd::Commands::ServeCommand do
  let(:dir) { Dir.mktmpdir("serve-spec") }
  let(:schema_path) { File.join(dir, "s.xsd") }
  let(:package_path) { File.join(dir, "test.lxr") }
  let(:port) { 4699 }

  let(:schema) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="doc">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="value" type="xs:int" maxOccurs="unbounded"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD
  end

  before do
    File.write(schema_path, schema)
    repo = Lutaml::Xsd::SchemaRepository.new
    repo.add_schema_files([schema_path])
    Lutaml::Xsd::SchemaRepositoryPackage.create(
      repository: repo, output_path: package_path,
      config: Lutaml::Xsd::PackageConfiguration.new, metadata: {}
    )
  end

  after do
    FileUtils.rm_rf(dir)
  rescue StandardError
    nil
  end

  def with_server(&)
    command = described_class.new(package_path, port: port, verbose: false)
    thread = Thread.new { command.run }
    sleep 2
    yield
  ensure
    Thread.kill(thread) if thread
  end

  it "validates posted instances and reports findings" do
    with_server do
      uri = URI("http://localhost:#{port}/api/validate")
      res = Net::HTTP.post(uri, JSON.generate(
                                  instance: "<doc><value>abc</value></doc>",
                                ), "Content-Type" => "application/json")
      body = JSON.parse(res.body)
      expect(body["valid"]).to be(false)
      expect(body["errors"]).not_to be_empty
      expect(body["errors"].first).to include("code", "message")

      good = Net::HTTP.post(uri, JSON.generate(
                                   instance: "<doc><value>1</value></doc>",
                                 ), "Content-Type" => "application/json")
      expect(JSON.parse(good.body)["valid"]).to be(true)
    end
  end

  it "answers 400 with a request_error finding on malformed input" do
    with_server do
      uri = URI("http://localhost:#{port}/api/validate")
      res = Net::HTTP.post(uri, "not-json",
                           "Content-Type" => "application/json")
      expect(res.code).to eq("400")
      body = JSON.parse(res.body)
      expect(body["valid"]).to be(false)
      expect(body["errors"].first["code"]).to eq("request_error")
    end
  end
end
