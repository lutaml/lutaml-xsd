# frozen_string_literal: true

require "lutaml/xsd"
require "lutaml/xsd/conformance/w3c_suite"

module Lutaml
  module Xsd
    module Conformance
      # The ride battery: the probe set for candidate dependency
      # trains. Every upstream-filing leg (the cases whose fixes ride
      # leptris/moxml releases) plus the regression canaries that
      # caught the ride-419 wave. `rake conformance:ride` runs this
      # against the currently-pinned train; a full 94-batch measure
      # remains the adoption gate.
      module RideBattery
        ADAPTER_FALLBACK_MARKER = "falling back to nokogiri"

        # Matched by fragment against the suite case names (each
        # fragment is unique in the suite enumeration).
        CASES = %w[
          stE050
          stE055
          stE063
          stE065
          stE066
          stE096
          attgC035
          attgC036
          attgC037
          attgC038
          wildZ013b
          wildZ013c
          attZ014a
          attZ014b
          stZ054
          stZ055
          stZ056
          stZ073b
          particlesA013
          particlesIe004
          particlesIg003
          addB114
          addA005
          isDefault001
          isDefault072
          isDefault079
          addB028
          addB104
          addB187
          elemT058
          elemT071
          elemT074
          elemT026
          ctI003
          ctI040
          groupJ003
          particlesZ034
          dtZ86723
          elemZ014
        ].freeze

        # Runs the battery in this process. Returns the failure
        # fragments; prints one TSV line per case to `out`. The CALLER
        # owns adapter-fallback detection (run this under a stderr
        # capture — a silent nokogiri fallback makes every engine-leg
        # verdict meaningless).
        #
        # @return [Array<String>]
        def self.run(out: $stdout)
          suite_cases = W3CSuite.cases
          failures = []
          CASES.each do |fragment|
            c = suite_cases.find { |x| x.name.include?(fragment) }
            if c.nil?
              out.puts "MISS\t#{fragment}\t-\t-"
              failures << fragment
              next
            end
            begin
              valid = W3CSuite.pipeline_valid?(c)
              ok = valid == (c.expected == "valid")
              out.puts "#{ok ? 'PASS' : 'FAIL'}\t#{fragment}\t#{c.expected}\t#{valid ? 'valid' : 'invalid'}"
              failures << fragment unless ok
            rescue StandardError => e
              out.puts "ERR\t#{fragment}\t#{e.class}\t#{e.message[0, 60]}"
              failures << fragment
            end
          end
          failures
        end

        # The rake-task body: run the battery in a subprocess (so a
        # moxml adapter fallback surfaces on stderr), enforce the
        # adapter floor, and print the ADOPT / PIN BACK verdict.
        #
        # @return [void]
        def self.run!
          require "open3"

          marker = ADAPTER_FALLBACK_MARKER
          script = <<~RUBY
            require "lutaml/xsd"
            require "lutaml/xsd/conformance/ride_battery"
            require "lutaml/xsd/conformance/w3c_suite"
            puts "moxml \#{Gem::Specification.find_by_name('moxml').version} " \\
              "leptris \#{Gem::Specification.find_by_name('leptris').version} " \\
              "lutaml-model \#{Gem::Specification.find_by_name('lutaml-model').version}"
            Lutaml::Xsd::Conformance::RideBattery.run
          RUBY

          out, err, status = Open3.capture3(
            RbConfig.ruby, "-Ilib", "-e", script
          )
          puts out.lines.first
          if err.include?(marker)
            warn "RIDE ABORT: the leptris adapter is unusable on this " \
                 "train (#{marker.strip.inspect} on stderr) — probes " \
                 "answer engine-less via the nokogiri fallback; pin a " \
                 "compatible moxml/leptris pair first."
            abort("conformance:ride failed: adapter fallback detected")
          end
          unless status.success?
            abort("conformance:ride failed: battery runner exited " \
                  "#{status.exitstatus}")
          end

          puts out.lines[1..]
          failures = out.lines[1..].count do |line|
            line.start_with?("FAIL", "ERR", "MISS")
          end
          total = CASES.size
          if failures.zero?
            puts "RIDE VERDICT: ADOPT — battery #{total}/#{total} green " \
                 "on this train. Confirm with a full measure: " \
                 "`rake conformance:w3c:run` + ledger diff."
          else
            warn "RIDE VERDICT: PIN BACK — #{failures}/#{total} battery " \
                 "cases fail on this train."
            abort("conformance:ride failed: #{failures} battery failures")
          end
        end
      end
    end
  end
end
