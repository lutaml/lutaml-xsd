# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :deps do
  desc "Fail when Gemfile.lock resolution drifts from Gemfile/gemspec"
  task :lockfile_check do
    fresh = Bundler.with_unbundled_env { `bundle lock --print 2>/dev/null` }
    committed = File.exist?("Gemfile.lock") ? File.read("Gemfile.lock") : ""

    signature = lambda do |text|
      parsed = Bundler::LockfileParser.new(text)
      {
        platforms: parsed.platforms.map(&:to_s).sort,
        dependencies: parsed.dependencies.keys.sort,
        # name→version only: platform-variant listing differs across
        # environments and is not the behavior contract we guard.
        versions: parsed.specs.map { |s|
          "#{s.name} #{s.version}"
        }.uniq.sort,
      }
    end

    if signature.call(fresh) != signature.call(committed)
      warn <<~MSG
        Gemfile.lock is out of sync with the current Gemfile/gemspec.
        A fresh resolution differs from the committed lockfile — run
        `bundle install` locally and commit the updated Gemfile.lock.
        (Unlocked CI resolutions have shipped silent dependency behavior
        changes before, e.g. rng 0.3.8; the lockfile is the contract.)
      MSG
      abort("deps:lockfile_check failed")
    end
  end
end

task default: %i[deps:lockfile_check spec rubocop]

# Build the frontend SPA (frontend/dist/)
desc "Build frontend SPA assets"
task :build_frontend do
  frontend_dir = File.join(__dir__, "frontend")
  File.join(frontend_dir, "dist")

  puts "Building frontend..."
  system("cd #{frontend_dir} && npm install && npm run build") || raise("Frontend build failed")
end

# Hook into bundler's release task to ensure frontend is built
Rake::Task["release"].enhance(["build_frontend"])
