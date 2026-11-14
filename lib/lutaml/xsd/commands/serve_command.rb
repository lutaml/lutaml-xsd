# frozen_string_literal: true

require_relative "base_command"
require "json"
require "fileutils"
require "tmpdir"

module Lutaml
  module Xsd
    module Commands
      # Serve an LXR package with the SPA playground: static frontend
      # plus a JSON validation API. WEBrick is loaded LAZILY and is a
      # Gemfile-side dependency — never a gemspec runtime requirement
      # (the optional-tooling rule).
      class ServeCommand < BaseCommand
        DEFAULT_PORT = 4567

        def initialize(package_path, options = {})
          @package_path = package_path
          @port = options[:port] || DEFAULT_PORT
          @frontend_dir = options[:frontend_dir] ||
            File.join(__dir__, "..", "..", "..", "..", "frontend", "dist")
          super(options)
        end

        def run
          validate_inputs
          schemas = load_schemas
          start_server(schemas)
        rescue StandardError => e
          error "Serve failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          raise CommandError
        end

        private

        def validate_inputs
          return if File.exist?(@package_path)

          error "Package file not found: #{@package_path}"
          raise CommandError
        end

        # The proven harness recipe: extract the package, parse every
        # schema with its location, build the collision-suffixing
        # repository the suite measures with. The temp dir survives
        # the server's lifetime (no-block mktmpdir) — the engine
        # compiles file-backed schemas and hint resolution read it
        # on every request.
        #
        # @return [Hash] { repository:, base: } for the job
        def load_schemas
          require "lutaml/xsd"
          require_relative "../conformance/runner"

          dir = Dir.mktmpdir("lutaml-xsd-serve")
          extract_package(dir)
          schemas = {}
          locations = {}
          Dir[File.join(dir, "**", "*.xsd")].each do |path|
            schema = Lutaml::Xml::Schema::Xsd.parse(File.read(path),
                                                    location: path)
            key = if schema.target_namespace.to_s.match?(/\S/)
                    schema.target_namespace
                  else
                    path
                  end
            key = "#{key}##{path}" while schemas.key?(key)
            schemas[key] = schema
            locations[path] = schema
          end
          repository = Lutaml::Xsd::Conformance::Runner::Repository.new(
            schemas, locations
          )
          { repository: repository, base: dir }
        end

        def extract_package(dir)
          require "zip"
          Zip::File.open(@package_path) do |zipfile|
            zipfile.each do |entry|
              next unless entry.name.end_with?(".xsd")

              target = File.join(dir, entry.name)
              FileUtils.mkdir_p(File.dirname(target))
              File.write(target, zipfile.get_input_stream(entry).read)
            end
          end
          unless Dir[File.join(dir, "**", "*.xsd")].any?
            error "Package contains no XSD schemas: #{@package_path}"
            raise CommandError
          end
        end

        def start_server(schemas)
          require "webrick"
          require_relative "../validation/validation_job"

          unless File.exist?(File.join(@frontend_dir, "index.html"))
            error "frontend assets not found at #{@frontend_dir} — " \
                  "run `rake build_frontend` first (the API still works: " \
                  "POST /api/validate)"
          end

          config = Lutaml::Xsd::Validation::ValidationConfiguration.new
          server = WEBrick::HTTPServer.new(
            Port: @port,
            DocumentRoot: File.expand_path(@frontend_dir),
            Logger: WEBrick::Log.new($stderr, WEBrick::Log::INFO),
            AccessLog: [],
          )
          server.mount_proc "/api/validate" do |req, res|
            handle_validate(req, res, schemas, config)
          end
          server.mount_proc "/api/json-schema" do |_req, res|
            handle_json_schema(res, schemas)
          end
          verbose_output "Serving #{@package_path} on " \
                         "http://localhost:#{@port}"
          server.start
        end

        def handle_validate(req, res, schemas, config)
          body = JSON.parse(req.body.to_s)
          content = body["instance"].to_s
          job = Lutaml::Xsd::Validation::ValidationJob.new(
            xml_content: content,
            repository: schemas[:repository],
            rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
            config: config,
            instance_base: schemas[:base],
          )
          result = job.execute
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(
            valid: result.valid?,
            errors: result.errors.map { |finding| finding_h(finding) },
            warnings: result.warnings.map { |finding| finding_h(finding) },
          )
        rescue StandardError => e
          res.status = 400
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(valid: false, errors: [
                                     { "code" => "request_error", "message" => e.message },
                                   ])
        end

        # GET /api/json-schema — every schema in the package as a
        # draft-2020-12 document (the JsonSchemaExporter contract;
        # lutaml-jsonschema consumes this shape). Keyed by source file.
        def handle_json_schema(res, schemas)
          require_relative "../json_schema_exporter"
          exported = schemas[:repository].all_schemas.map do |key, schema|
            {
              key: key,
              target_namespace: schema.target_namespace,
              json_schema: JsonSchemaExporter.new(schema).export,
            }
          end
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(schemas: exported)
        rescue StandardError => e
          res.status = 500
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(
            error: "export failed: #{e.message}",
          )
        end

        def finding_h(finding)
          {
            code: finding.code,
            message: finding.message,
            severity: finding.severity,
            location: finding.location,
          }
        end
      end
    end
  end
end
