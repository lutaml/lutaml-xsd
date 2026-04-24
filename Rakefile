# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Build the frontend SPA (frontend/dist/)
desc "Build frontend SPA assets"
task :build_frontend do
  frontend_dir = File.join(__dir__, "frontend")
  File.join(frontend_dir, "dist")

  puts "Building frontend..."
  system("cd #{frontend_dir} && npm install && npm run build") || raise("Frontend build failed")
end

# Build the RNG frontend SPA (frontend-rng/dist/)
desc "Build RNG frontend SPA assets"
task :build_frontend_rng do
  frontend_dir = File.join(__dir__, "frontend-rng")
  File.join(frontend_dir, "dist")

  puts "Building RNG frontend..."
  system("cd #{frontend_dir} && npm install && npm run build") || raise("RNG frontend build failed")
end

# Hook into bundler's release task to ensure frontends are built
Rake::Task["release"].enhance(["build_frontend", "build_frontend_rng"])
