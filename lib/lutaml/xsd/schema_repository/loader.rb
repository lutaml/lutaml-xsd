# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Factory methods that build a SchemaRepository from external sources
      # (package files, YAML configs, single XSD/RNG files). Lives outside
      # the repository itself so the repository class stays focused on state
      # and coordination.
      module Loader
        module_function

        def validate_package(zip_path)
          SchemaRepositoryPackage.new(zip_path).validate
        end

        def from_package(zip_path)
          SchemaRepositoryPackage.new(zip_path).load_repository
        end

        def from_yaml_file(yaml_path)
          yaml_content = File.read(yaml_path)
          base_dir = File.dirname(yaml_path)

          repository = SchemaRepository.from_yaml(yaml_content)

          resolve_relative_paths(repository, base_dir)
          repository
        end

        def from_file(path)
          raise Errno::ENOENT, "No such file or directory - #{path}" unless File.exist?(path)

          case File.extname(path).downcase
          when ".lxr"
            repo = from_package(path)
            repo.resolve unless repo.resolved
            repo
          when ".xsd", ".rng", ".rnc"
            repo = SchemaRepository.new
            repo.files = [File.expand_path(path)]
            repo.parse.resolve
            repo
          when ".yml", ".yaml"
            repo = from_yaml_file(path)
            repo.parse.resolve if repo.needs_parsing?
            repo
          else
            raise ConfigurationError,
                  "Unsupported file type: #{path}. Expected .xsd, .rng, .rnc, .lxr, .yml, or .yaml"
          end
        end

        def from_file_cached(source_path, lxr_path: nil)
          lxr_path ||= source_path.sub(/\.(xsd|ya?ml)$/, ".lxr")

          if File.exist?(lxr_path) && File.mtime(lxr_path) >= File.mtime(source_path)
            from_file(lxr_path)
          else
            repo = from_file(source_path)
            repo.to_package(
              lxr_path,
              xsd_mode: :include_all,
              resolution_mode: :resolved,
              serialization_format: :marshal,
            )
            repo
          end
        end

        def resolve_relative_paths(repository, base_dir)
          if repository.files
            repository.files = repository.files.map do |file|
              File.absolute_path?(file) ? file : File.expand_path(file, base_dir)
            end
          end

          if repository.base_packages
            repository.base_packages = repository.base_packages.map do |pkg|
              pkg_path = pkg.package
              pkg.package = File.expand_path(pkg_path, base_dir) unless File.absolute_path?(pkg_path)
              pkg
            end
          end

          repository.schema_location_mappings&.each do |mapping|
            next if File.absolute_path?(mapping.to)

            mapping.to = File.expand_path(mapping.to, base_dir)
          end
        end

        private_class_method :resolve_relative_paths
      end
    end
  end
end
