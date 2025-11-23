# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/validate_schema_command"
require "tempfile"
require "json"
require "yaml"

RSpec.describe Lutaml::Xsd::Commands::ValidateSchemaCommand do
  let(:valid_schema_content) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="root" type="xs:string"/>
      </xs:schema>
    XSD
  end

  let(:valid_xsd_1_1_content) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="test">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="value" type="xs:integer"/>
            </xs:sequence>
            <xs:assert test="value gt 0"/>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD
  end

  let(:invalid_schema_content) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <root>
        <child>Not a schema</child>
      </root>
    XML
  end

  describe "#validate" do
    context "with no files specified" do
      it "exits with error and usage message" do
        command = described_class.new
        # Stub options to return defaults with symbol keys
        allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

        expect { command.validate }.to output(/No schema files specified/).to_stdout
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context "with single valid schema file" do
      it "validates successfully" do
        Tempfile.create(["valid_schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format:

 "text" })

          expect { command.validate(file.path) }.to output(/✓ #{Regexp.escape(file.path)}/).to_stdout
            .and raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
        end
      end
    end

    context "with multiple valid schema files" do
      it "validates all files successfully" do
        Tempfile.create(["schema1", ".xsd"]) do |file1|
          Tempfile.create(["schema2", ".xsd"]) do |file2|
            file1.write(valid_schema_content)
            file1.rewind
            file2.write(valid_schema_content)
            file2.rewind

            command = described_class.new
            allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

            output = capture(:stdout) do
              expect { command.validate(file1.path, file2.path) }
                .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
            end

            expect(output).to match(/✓ #{Regexp.escape(file1.path)}/)
            expect(output).to match(/✓ #{Regexp.escape(file2.path)}/)
            expect(output).to match(/Total: 2/)
            expect(output).to match(/Valid: 2/)
            expect(output).to match(/Invalid: 0/)
          end
        end
      end
    end

    context "with non-existent file" do
      it "reports file not found" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })
        non_existent = "non_existent_schema.xsd"

        output = capture(:stdout) do
          expect { command.validate(non_existent) }
            .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end

        expect(output).to match(/✗ #{non_existent}/)
        expect(output).to match(/Error: File not found/)
        expect(output).to match(/Total: 1/)
        expect(output).to match(/Invalid: 1/)
      end
    end

    context "with invalid schema" do
      it "reports validation error" do
        Tempfile.create(["invalid_schema", ".xsd"]) do |file|
          file.write(invalid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
          end

          expect(output).to match(/✗ #{Regexp.escape(file.path)}/)
          expect(output).to match(/Error:/)
          expect(output).to match(/Not a valid XSD schema/)
        end
      end
    end

    context "with version option" do
      it "validates against XSD 1.0" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

          expect { command.validate(file.path) }.to output(/✓/).to_stdout
            .and raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
        end
      end

      it "validates against XSD 1.1 and accepts 1.1 features" do
        Tempfile.create(["schema_1_1", ".xsd"]) do |file|
          file.write(valid_xsd_1_1_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.1", verbose: false, format: "text" })

          expect { command.validate(file.path) }.to output(/✓/).to_stdout
            .and raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
        end
      end

      it "rejects XSD 1.1 features when validating as 1.0" do
        Tempfile.create(["schema_1_1", ".xsd"]) do |file|
          file.write(valid_xsd_1_1_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
          end

          expect(output).to match(/✗/)
          expect(output).to match(/XSD 1.1 features/)
        end
      end
    end

    context "with verbose option" do
      it "displays detected XSD version" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: true, format: "text" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          end

          expect(output).to match(/✓ #{Regexp.escape(file.path)} \(XSD 1\.0\)/)
        end
      end
    end

    context "with mixed valid and invalid files" do
      it "reports correct summary" do
        Tempfile.create(["valid", ".xsd"]) do |valid_file|
          Tempfile.create(["invalid", ".xsd"]) do |invalid_file|
            valid_file.write(valid_schema_content)
            valid_file.rewind
            invalid_file.write(invalid_schema_content)
            invalid_file.rewind

            command = described_class.new
            allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "text" })

            output = capture(:stdout) do
              expect { command.validate(valid_file.path, invalid_file.path) }
                .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
            end

            expect(output).to match(/Total: 2/)
            expect(output).to match(/Valid: 1/)
            expect(output).to match(/Invalid: 1/)
          end
        end
      end
    end

    context "with JSON format" do
      it "outputs valid schema results in JSON format" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "json" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          end

          json = JSON.parse(output)
          expect(json["summary"]["total"]).to eq(1)
          expect(json["summary"]["valid"]).to eq(1)
          expect(json["summary"]["invalid"]).to eq(0)
          expect(json["results"].length).to eq(1)
          expect(json["results"][0]["file"]).to eq(file.path)
          expect(json["results"][0]["valid"]).to be true
          expect(json["results"][0]["error"]).to be_nil
        end
      end

      it "outputs invalid schema results in JSON format" do
        Tempfile.create(["invalid", ".xsd"]) do |file|
          file.write(invalid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "json" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
          end

          json = JSON.parse(output)
          expect(json["summary"]["total"]).to eq(1)
          expect(json["summary"]["valid"]).to eq(0)
          expect(json["summary"]["invalid"]).to eq(1)
          expect(json["results"][0]["valid"]).to be false
          expect(json["results"][0]["error"]).to include("Not a valid XSD schema")
        end
      end

      it "outputs mixed results in JSON format" do
        Tempfile.create(["valid", ".xsd"]) do |valid_file|
          Tempfile.create(["invalid", ".xsd"]) do |invalid_file|
            valid_file.write(valid_schema_content)
            valid_file.rewind
            invalid_file.write(invalid_schema_content)
            invalid_file.rewind

            command = described_class.new
            allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "json" })

            output = capture(:stdout) do
              expect { command.validate(valid_file.path, invalid_file.path) }
                .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
            end

            json = JSON.parse(output)
            expect(json["summary"]["total"]).to eq(2)
            expect(json["summary"]["valid"]).to eq(1)
            expect(json["summary"]["invalid"]).to eq(1)
            expect(json["results"].length).to eq(2)
          end
        end
      end

      it "includes detected version in verbose JSON output" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: true, format: "json" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          end

          json = JSON.parse(output)
          expect(json["results"][0]["detected_version"]).to eq("1.0")
        end
      end
    end

    context "with YAML format" do
      it "outputs valid schema results in YAML format" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "yaml" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          end

          yaml = YAML.safe_load(output)
          expect(yaml["summary"]["total"]).to eq(1)
          expect(yaml["summary"]["valid"]).to eq(1)
          expect(yaml["summary"]["invalid"]).to eq(0)
          expect(yaml["results"].length).to eq(1)
          expect(yaml["results"][0]["file"]).to eq(file.path)
          expect(yaml["results"][0]["valid"]).to be true
          expect(yaml["results"][0]["error"]).to be_nil
        end
      end

      it "outputs invalid schema results in YAML format" do
        Tempfile.create(["invalid", ".xsd"]) do |file|
          file.write(invalid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "yaml" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
          end

          yaml = YAML.safe_load(output)
          expect(yaml["summary"]["total"]).to eq(1)
          expect(yaml["summary"]["valid"]).to eq(0)
          expect(yaml["summary"]["invalid"]).to eq(1)
          expect(yaml["results"][0]["valid"]).to be false
          expect(yaml["results"][0]["error"]).to include("Not a valid XSD schema")
        end
      end

      it "outputs mixed results in YAML format" do
        Tempfile.create(["valid", ".xsd"]) do |valid_file|
          Tempfile.create(["invalid", ".xsd"]) do |invalid_file|
            valid_file.write(valid_schema_content)
            valid_file.rewind
            invalid_file.write(invalid_schema_content)
            invalid_file.rewind

            command = described_class.new
            allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "yaml" })

            output = capture(:stdout) do
              expect { command.validate(valid_file.path, invalid_file.path) }
                .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
            end

            yaml = YAML.safe_load(output)
            expect(yaml["summary"]["total"]).to eq(2)
            expect(yaml["summary"]["valid"]).to eq(1)
            expect(yaml["summary"]["invalid"]).to eq(1)
            expect(yaml["results"].length).to eq(2)
          end
        end
      end

      it "includes detected version in verbose YAML output" do
        Tempfile.create(["schema", ".xsd"]) do |file|
          file.write(valid_schema_content)
          file.rewind

          command = described_class.new
          allow(command).to receive(:options).and_return({ version: "1.0", verbose: true, format: "yaml" })

          output = capture(:stdout) do
            expect { command.validate(file.path) }
              .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          end

          yaml = YAML.safe_load(output)
          expect(yaml["results"][0]["detected_version"]).to eq("1.0")
        end
      end
    end

    context "with invalid format option" do
      it "exits with error for invalid format" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ version: "1.0", verbose: false, format: "xml" })

        output = capture(:stdout) do
          expect { command.validate("schema.xsd") }
            .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end

        expect(output).to match(/Invalid format 'xml'/)
        expect(output).to match(/Must be 'text', 'json', or 'yaml'/)
      end
    end
  end

  # Helper method to capture stdout
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end
end