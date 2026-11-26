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
        BASELINE_DIR = File.join(__dir__, "..", "..", "..", "..",
                                 "baseline")
        DEFAULT_VERSION = "1.0"

        module_function

        # The reading's batch directory and committed baseline path —
        # the 1.0 ledger lives at baseline/w3c_ledger.json over tmp/,
        # the 1.1 ledger at baseline/w3c_ledger_11.json over
        # tmp/w3c_batch_11/.
        #
        # @param version [String]
        # @return [Array<String>]
        def paths(version = DEFAULT_VERSION)
          if version == DEFAULT_VERSION
            ["tmp", File.join(BASELINE_DIR, "w3c_ledger.json")]
          else
            [File.join("tmp", "w3c_batch_#{version.tr('.', '')}"),
             File.join(BASELINE_DIR, "w3c_ledger_#{version.tr('.', '')}.json")]
          end
        end

        # Loads the fresh per-batch results (tmp/w3c_batch_*.json as
        # written by conformance:w3c:run).
        #
        # @param dir [String]
        # @return [Hash{String => Hash}]
        def load_batches(dir = paths.first)
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
        # @param version [String]
        # @return [Hash]
        def baseline(version = DEFAULT_VERSION)
          JSON.parse(File.read(paths(version).last))
        end

        # Regenerates the baseline from the current tmp/ measure.
        #
        # @param version [String]
        # @return [Hash]
        def regenerate!(version = DEFAULT_VERSION)
          batches = load_batches(paths(version).first)
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
          FileUtils.mkdir_p(File.dirname(paths(version).last))
          File.write(paths(version).last,
                     "#{JSON.pretty_generate(snapshot)}\n")
          snapshot
        end

        # Compares the fresh measure against the baseline. Regressed
        # batches are re-run once (the crosstalk families flake one
        # case at a time); the rerun verdict stands.
        #
        # @param version [String]
        # @return [Hash] wins/regressions/flakes + the headline
        def compare(version = DEFAULT_VERSION, rerun: true)
          base_failures = baseline(version)["failures"]
          batches = load_batches(paths(version).first)
          new_failures = batches.values.flat_map { |b| b["failures"] }
          passed = batches.values.sum { |b| b["passed"] }
          total = batches.values.sum { |b| b["total"] }

          wins = (base_failures - new_failures).sort
          regressions = (new_failures - base_failures).sort

          if rerun && regressions.any?
            regressions = rerun_regressions(regressions, batches, version)
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
        # @param regressions [Array<String>]
        # @param batches [Hash{String => Hash}]
        # @param version [String]
        # @return [Array<String>]
        def rerun_regressions(regressions, batches, version)
          batch_dir, = paths(version)
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
              "offset: #{offset}, limit: #{limit}, " \
              "version: '#{version}'); " \
              "r[:failures] = r[:failures].map { |f| " \
              "{ name: f.name, expected: f.expected, " \
              "contributor: f.contributor } }; " \
              "File.write(File.join('#{batch_dir}', '#{file}'), " \
              "JSON.generate(r))"
            )
          end
          fresh = load_batches(paths(version).first)
          fresh_failures = fresh.values.flat_map { |b| b["failures"] }
          base_failures = baseline(version)["failures"]
          (fresh_failures - base_failures).sort
        end

        # The rake-task body for ledger:check — prints the headline
        # and the per-case diff, aborts on real regressions (the
        # crosstalk rerun already applied inside compare).
        #
        # @param version [String]
        # @return [void]
        def self.check!(version = DEFAULT_VERSION)
          result = compare(version)
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
