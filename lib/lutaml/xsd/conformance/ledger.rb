# frozen_string_literal: true

require "json"
require "fileutils"

module Lutaml
  module Xsd
    module Conformance
      # The W3C ledger baseline: a committed JSON snapshot of the
      # per-case failures the register's headline number was measured
      # at. `conformance:ledger:check` compares a fresh measure
      # against it — wins and regressions per case, with one rerun of
      # regressed batches to absorb the known batch-crosstalk flakes.
      # The baseline moves ONLY via register commits (a register
      # round regenerates it from tmp/); the nightly job never writes
      # it.
      module Ledger
        BASELINE_PATH = File.join(__dir__, "..", "..", "..", "..",
                                  "baseline", "w3c_ledger.json")
        BATCH_DIR = "tmp"

        module_function

        # Loads the fresh per-batch results (tmp/w3c_batch_*.json as
        # written by conformance:w3c:run).
        #
        # @param dir [String]
        # @return [Hash{String => Hash}]
        def load_batches(dir = BATCH_DIR)
          Dir.glob(File.join(dir, "w3c_batch_*.json"))
            .each_with_object({}) do |path, h|
            data = JSON.parse(File.read(path))
            file = File.basename(path)
            h[file] = {
              "passed" => data["passed"],
              "total" => data["total"],
              "failures" => data["failures"].map { |f| f["name"] },
              "excluded" => data["excluded"] || [],
            }
          end
        end

        # The committed baseline.
        #
        # @return [Hash]
        def baseline
          JSON.parse(File.read(BASELINE_PATH))
        end

        # Regenerates the baseline from the current tmp/ measure.
        #
        # @return [Hash]
        def regenerate!
          batches = load_batches
          failures = batches.values.flat_map { |b| b["failures"] }.sort
          excluded = batches.values.flat_map { |b| b["excluded"] }.sort
          passed = batches.values.sum { |b| b["passed"] }
          total = batches.values.sum { |b| b["total"] }
          snapshot = {
            "provenance" => {
              "generated" => Time.now.utc.strftime("%Y-%m-%d"),
              "git" => `git rev-parse --short HEAD`.strip,
            },
            "passed" => passed,
            "total" => total,
            "failures" => failures,
            "excluded" => excluded,
          }
          FileUtils.mkdir_p(File.dirname(BASELINE_PATH))
          File.write(BASELINE_PATH, "#{JSON.pretty_generate(snapshot)}\n")
          snapshot
        end

        # Compares the fresh measure against the baseline. Regressed
        # batches are re-run once (the crosstalk families flake one
        # case at a time); the rerun verdict stands.
        #
        # @return [Hash] wins/regressions/flakes + the headline
        def compare(rerun: true)
          base_failures = baseline["failures"]
          batches = load_batches
          new_failures = batches.values.flat_map { |b| b["failures"] }
          passed = batches.values.sum { |b| b["passed"] }
          total = batches.values.sum { |b| b["total"] }

          wins = (base_failures - new_failures).sort
          regressions = (new_failures - base_failures).sort

          if rerun && regressions.any?
            regressions = rerun_regressions(regressions, batches)
          end

          {
            "passed" => passed,
            "total" => total,
            "wins" => wins,
            "regressions" => regressions,
          }
        end

        # Reruns the batches containing the regressed cases (one
        # subprocess per batch, the measure's own invocation) and
        # recomputes the regression list from the fresh files.
        #
        # @return [Array<String>]
        def rerun_regressions(regressions, batches)
          files = regressions.filter_map do |name|
            batches.find { |_, b| b["failures"].include?(name) }
          end.map(&:first).uniq
          files.each do |file|
            offset = file[/\d+/].to_i
            limit = 50
            system(
              RbConfig.ruby, "-Ilib", "-e",
              "require 'lutaml/xsd'; " \
              "require 'lutaml/xsd/conformance/w3c_suite'; " \
              "require 'json'; " \
              "r = Lutaml::Xsd::Conformance::W3CSuite.measure(" \
              "offset: #{offset}, limit: #{limit}); " \
              "r[:failures] = r[:failures].map { |f| " \
              "{ name: f.name, expected: f.expected, " \
              "contributor: f.contributor } }; " \
              "File.write(File.join('tmp', '#{file}'), JSON.generate(r))"
            )
          end
          fresh = load_batches
          fresh_failures = fresh.values.flat_map { |b| b["failures"] }
          base_failures = baseline["failures"]
          (fresh_failures - base_failures).sort
        end

        # The rake-task body for ledger:check — prints the headline
        # and the per-case diff, aborts on real regressions (the
        # crosstalk rerun already applied inside compare).
        #
        # @return [void]
        def self.check!
          result = compare
          puts "ledger: #{result['passed']}/#{result['total']} measured"
          puts "wins (#{result['wins'].size}):"
          result["wins"].each { |name| puts "  + #{name}" }
          if result["regressions"].empty?
            puts "regressions (0)"
          else
            puts "regressions (#{result['regressions'].size}):"
            result["regressions"].each { |name| puts "  - #{name}" }
            abort("conformance:ledger:check failed: " \
                  "#{result['regressions'].size} regressions")
          end
        end
      end
    end
  end
end
