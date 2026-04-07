# frozen_string_literal: true

require "liquid"
require "lutaml/xsd"
require "canon"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Helper to create a writable temp directory on Windows GitHub Actions
# On Windows, Dir.mktmpdir creates directories with restricted permissions
# that prevent RubyZip from writing files. This helper ensures the directory
# is writable on Unix systems.
def with_writable_temp_dir
  require "fileutils"

  Dir.mktmpdir do |tmpdir|
    # Ensure directory is writable (helps on Unix, no-op on Windows ACL systems)
    begin
      FileUtils.chmod(0o755, tmpdir)
    rescue StandardError
      nil
    end
    yield tmpdir
  end
end
