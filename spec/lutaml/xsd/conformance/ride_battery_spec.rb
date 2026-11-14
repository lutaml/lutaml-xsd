# frozen_string_literal: true

require "lutaml/xsd/conformance/ride_battery"

RSpec.describe Lutaml::Xsd::Conformance::RideBattery do
  describe "CASES" do
    it "is a frozen, non-empty, fragment-unique list" do
      expect(described_class::CASES).to be_frozen
      expect(described_class::CASES).not_to be_empty
      expect(described_class::CASES).to eq(described_class::CASES.uniq)
      described_class::CASES.each do |fragment|
        expect(fragment).to match(/\A\w+/)
      end
    end
  end

  describe ".run" do
    it "prints one TSV line per case and returns the failures" do
      vendor = Lutaml::Xsd::Conformance::W3CSuite.vendor_dir
      skip "vendor/xsdtests not vendored (rake conformance:w3c:setup)" unless
        vendor && File.directory?(vendor)

      out = StringIO.new
      failures = described_class.run(out: out)
      lines = out.string.lines
      expect(lines.size).to eq(described_class::CASES.size)
      expect(lines).to all(match(/\A(PASS|FAIL|ERR|MISS)\t/))
      expect(failures).to eq(lines.reject { |l| l.start_with?("PASS") }
        .map { |l| l.split("\t")[1] })
    end
  end
end
