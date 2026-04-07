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
def with_writable_temp_dir
  require "fileutils"
  Dir.mktmpdir do |tmpdir|
    FileUtils.chmod(0o755, tmpdir)
    yield tmpdir
  end
end
