# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Prints parse/resolve progress to stdout when verbose mode is on.
      # Extracted from SchemaRepository so the repository class stays free
      # of presentation / formatting concerns.
      class ProgressReporter
        def initialize(out: $stdout)
          @out = out
        end

        def report_resolve(schemas)
          total = schemas.values.sum { |schema| (schema.import || []).size }

          if total.positive?
            @out.puts "Resolving #{total} schema dependencies..."
            processed = 0
            schemas.each_value do |schema|
              (schema.import || []).each do |import|
                processed += 1
                @out.print "\r[#{processed}/#{total}] #{import.namespace || 'no namespace'}"
                @out.flush
              end
            end
            @out.puts "\n✓ All dependencies resolved"
          else
            @out.puts "✓ No schema dependencies to resolve"
          end
        end
      end
    end
  end
end
