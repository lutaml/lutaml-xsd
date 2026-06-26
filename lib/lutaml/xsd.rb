# frozen_string_literal: true

require "lutaml/model"
require "lutaml/xml/schema/xsd"

module Lutaml
  module Xsd
    class Error < StandardError; end
  end
end

# Constants and compatibility aliases must be eagerly loaded
require "lutaml/xsd/version"
require "lutaml/xsd/schema"
require "lutaml/xsd/compatibility"
require "lutaml/xsd/xsd_model_extensions"

module Lutaml
  module Xsd
    autoload :BasePackageConfig, "lutaml/xsd/base_package_config"
    autoload :BatchTypeQuery, "lutaml/xsd/batch_type_query"
    autoload :CoverageAnalyzer, "lutaml/xsd/coverage_analyzer"
    autoload :DefinitionExtractor, "lutaml/xsd/definition_extractor"
    autoload :DependencyGrapher, "lutaml/xsd/dependency_grapher"
    autoload :EntrypointIdentifier, "lutaml/xsd/entrypoint_identifier"
    autoload :Error, "lutaml/xsd/errors"
    autoload :SchemaNotFoundError, "lutaml/xsd/errors"
    autoload :TypeNotFoundError, "lutaml/xsd/errors"
    autoload :PackageValidationError, "lutaml/xsd/errors"
    autoload :ConfigurationError, "lutaml/xsd/errors"
    autoload :SchemaValidationError, "lutaml/xsd/errors"
    autoload :ValidationFailedError, "lutaml/xsd/errors"
    autoload :PackageMergeError, "lutaml/xsd/errors"
    autoload :FileValidationResult, "lutaml/xsd/file_validation_result"
    autoload :InteractiveBuilder, "lutaml/xsd/interactive_builder"
    autoload :NamespaceMapping, "lutaml/xsd/namespace_mapping"
    autoload :NamespacePrefixManager, "lutaml/xsd/namespace_prefix_manager"
    autoload :NamespaceRemapper, "lutaml/xsd/namespace_remapper"
    autoload :NamespaceUriRemapping, "lutaml/xsd/namespace_uri_remapping"
    autoload :PackageBuilder, "lutaml/xsd/package_builder"
    autoload :PackageConfiguration, "lutaml/xsd/package_configuration"
    autoload :PackageConflictDetector, "lutaml/xsd/package_conflict_detector"
    autoload :PackageConflictResolver, "lutaml/xsd/package_conflict_resolver"
    autoload :PackageInfo, "lutaml/xsd/conflict_report"
    autoload :ConflictReport, "lutaml/xsd/conflict_report"
    autoload :PackageLoader, "lutaml/xsd/package_loader"
    autoload :PackageSource, "lutaml/xsd/package_source"
    autoload :PackageTreeFormatter, "lutaml/xsd/package_tree_formatter"
    autoload :PackageValidator, "lutaml/xsd/package_validator"
    autoload :RngToXsdConverter, "lutaml/xsd/rng_to_xsd_converter"
    autoload :RngToXsd, "lutaml/xsd/rng_to_xsd"
    autoload :SchemaClassifier, "lutaml/xsd/schema_classifier"
    autoload :SchemaDependencyAnalyzer, "lutaml/xsd/schema_dependency_analyzer"
    autoload :SchemaExporter, "lutaml/xsd/schema_exporter"
    autoload :SchemaFileValidationResults, "lutaml/xsd/schema_file_validation_results"
    autoload :SchemaLocationMapping, "lutaml/xsd/schema_location_mapping"
    autoload :SchemaNameResolver, "lutaml/xsd/schema_name_resolver"
    autoload :SchemaRepository, "lutaml/xsd/schema_repository"
    autoload :SchemaParser, "lutaml/xsd/schema_parser"
    autoload :SchemaQueryService, "lutaml/xsd/schema_query_service"
    autoload :TypeCategoryCount, "lutaml/xsd/schema_repository_metadata"
    autoload :SchemaRepositoryStatistics, "lutaml/xsd/schema_repository_metadata"
    autoload :SchemaRepositoryMetadata, "lutaml/xsd/schema_repository_metadata"
    autoload :SchemaRepositoryPackage, "lutaml/xsd/schema_repository_package"
    autoload :SchemaResolver, "lutaml/xsd/schema_resolver"
    autoload :SerializedSchema, "lutaml/xsd/serialized_schema"
    autoload :TypeHierarchyAnalyzer, "lutaml/xsd/type_hierarchy_analyzer"
    autoload :TypeIndexEntry, "lutaml/xsd/type_index_entry"
    autoload :TypeResolutionResult, "lutaml/xsd/type_resolution_result"
    autoload :TypeSearcher, "lutaml/xsd/type_searcher"
    autoload :ValidationError, "lutaml/xsd/validation_error"
    autoload :ValidationResult, "lutaml/xsd/validation_result"
    autoload :XsdBundler, "lutaml/xsd/xsd_bundler"
    autoload :XsdSpecValidator, "lutaml/xsd/xsd_spec_validator"

    # CLI must be eagerly loaded (Thor requires it at boot)
    autoload :CLI, "lutaml/xsd/cli"

    # Sub-modules with their own autoload entries
    module Conflicts
      autoload :NamespaceConflict, "lutaml/xsd/conflicts/namespace_conflict"
      autoload :SchemaConflict, "lutaml/xsd/conflicts/schema_conflict"
      autoload :SchemaFileSource, "lutaml/xsd/conflicts/schema_conflict"
      autoload :TypeConflict, "lutaml/xsd/conflicts/type_conflict"
    end

    module Formatters
      autoload :Base, "lutaml/xsd/formatters/base"
      autoload :FormatterFactory, "lutaml/xsd/formatters/formatter_factory"
      autoload :JsonFormatter, "lutaml/xsd/formatters/json_formatter"
      autoload :Registry, "lutaml/xsd/formatters/registry"
      autoload :TextFormatter, "lutaml/xsd/formatters/text_formatter"
      autoload :YamlFormatter, "lutaml/xsd/formatters/yaml_formatter"
    end

    module Validation
      autoload :ResultCollector, "lutaml/xsd/validation/result_collector"
      autoload :RuleEngine, "lutaml/xsd/validation/rule_engine"
      autoload :RuleRegistry, "lutaml/xsd/validation/rule_registry"
      autoload :SchemaLocationExtractor, "lutaml/xsd/validation/schema_location_extractor"
      autoload :SchemaResolver, "lutaml/xsd/validation/schema_resolver"
      autoload :ValidationConfiguration, "lutaml/xsd/validation/validation_configuration"
      autoload :ValidationError, "lutaml/xsd/validation/validation_error"
      autoload :ValidationJob, "lutaml/xsd/validation/validation_job"
      autoload :ValidationResult, "lutaml/xsd/validation/validation_result"
      autoload :ValidationRule, "lutaml/xsd/validation/validation_rule"
      autoload :Validator, "lutaml/xsd/validation/validator"
      autoload :XmlAttribute, "lutaml/xsd/validation/xml_attribute"
      autoload :XmlDocument, "lutaml/xsd/validation/xml_document"
      autoload :XmlElement, "lutaml/xsd/validation/xml_element"
      autoload :XmlNavigator, "lutaml/xsd/validation/xml_navigator"

      module BaseTypes
        autoload :BaseTypeValidator, "lutaml/xsd/validation/base_types/base_type_validator"
        autoload :BaseTypeValidatorRegistry, "lutaml/xsd/validation/base_types/base_type_validator_registry"
      end

      module Facets
        autoload :FacetValidator, "lutaml/xsd/validation/facets/facet_validator"
        autoload :FacetValidatorRegistry, "lutaml/xsd/validation/facets/facet_validator_registry"
      end

      module Rules
        autoload :AttributeValidationRule, "lutaml/xsd/validation/rules/attribute_validation_rule"
        autoload :ContentModelValidationRule, "lutaml/xsd/validation/rules/content_model_validation_rule"
        autoload :OccurrenceValidationRule, "lutaml/xsd/validation/rules/occurrence_validation_rule"
      end
    end

    module Commands
      autoload :BaseCommand, "lutaml/xsd/commands/base_command"
      autoload :BuildCommand, "lutaml/xsd/commands/build_command"
      autoload :CoverageCommand, "lutaml/xsd/commands/coverage_command"
      autoload :ElementCommand, "lutaml/xsd/commands/element_command"
      autoload :GenerateSpaCommand, "lutaml/xsd/commands/generate_spa_command"
      autoload :InitCommand, "lutaml/xsd/commands/init_command"
      autoload :MetadataCommand, "lutaml/xsd/commands/metadata_command"
      autoload :NamespaceCommand, "lutaml/xsd/commands/namespace_command"
      autoload :PackageCommand, "lutaml/xsd/commands/package_command"
      autoload :PkgCommand, "lutaml/xsd/commands/pkg_command"
      autoload :SearchCommand, "lutaml/xsd/commands/search_command"
      autoload :StatsCommand, "lutaml/xsd/commands/stats_command"
      autoload :TreeCommand, "lutaml/xsd/commands/tree_command"
      autoload :TypeCommand, "lutaml/xsd/commands/type_command"
      autoload :ValidateCommand, "lutaml/xsd/commands/validate_command"
      autoload :VerifyCommand, "lutaml/xsd/commands/verify_command"
      autoload :XmlCommand, "lutaml/xsd/commands/xml_command"
    end

    # SPA module
    module Spa
      autoload :ConfigurationLoader, "lutaml/xsd/spa/configuration_loader"
      autoload :Generator, "lutaml/xsd/spa/generator"
      autoload :HtmlDocumentBuilder, "lutaml/xsd/spa/html_document_builder"
      autoload :OutputStrategy, "lutaml/xsd/spa/output_strategy"
      autoload :SchemaSerializer, "lutaml/xsd/spa/schema_serializer"
      autoload :SpaMetadata, "lutaml/xsd/spa/spa_metadata"
      autoload :XmlInstanceGenerator, "lutaml/xsd/spa/xml_instance_generator"

      module Utils
        autoload :ExtractEnumeration, "lutaml/xsd/spa/utils/extract_enumeration"
      end
    end

    # Errors module
    module Errors
      autoload :EnhancedError, "lutaml/xsd/errors/enhanced_error"
      autoload :ErrorContext, "lutaml/xsd/errors/error_context"
      autoload :MessageBuilder, "lutaml/xsd/errors/message_builder"
      autoload :Suggestion, "lutaml/xsd/errors/suggestion"

      module Suggesters
        autoload :FuzzyMatcher, "lutaml/xsd/errors/suggesters/fuzzy_matcher"
        autoload :TypeNotFoundSuggester, "lutaml/xsd/errors/suggesters/type_not_found_suggester"
      end

      module Troubleshooters
        autoload :NamespaceTroubleshooter, "lutaml/xsd/errors/troubleshooters/namespace_troubleshooter"
      end
    end
  end
end
