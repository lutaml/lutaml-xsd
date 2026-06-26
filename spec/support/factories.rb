# frozen_string_literal: true

# Test data builders for specs. Real model instances only — no doubles.
# Include via `RSpec.configure { |c| c.include Factories }` (done in spec_helper).
module Factories
  # Build a real Lutaml::Xsd::PackageSource with the given attributes.
  # Defaults match what most specs previously stubbed on the double.
  def package_source(path: "pkg.lxr", priority: 0, conflict_resolution: "keep",
                     namespace_remapping: [], repository: nil)
    config = Lutaml::Xsd::BasePackageConfig.new(
      package: path,
      priority: priority,
      conflict_resolution: conflict_resolution,
      namespace_remapping: namespace_remapping,
    )
    Lutaml::Xsd::PackageSource.new(
      package_path: path,
      config: config,
      repository: repository || Lutaml::Xsd::SchemaRepository.new,
    )
  end

  # Build a real Lutaml::Xml::Schema::Xsd::Schema with optional types.
  def xsd_schema(target_namespace: "http://example.com/ns", complex_types: [],
                 simple_types: [], elements: [])
    schema = Lutaml::Xml::Schema::Xsd::Schema.new
    schema.target_namespace = target_namespace
    complex_types.each { |t| schema.complex_type << t }
    simple_types.each { |t| schema.simple_type << t }
    elements.each { |e| schema.element << e }
    schema
  end

  # Build a real Lutaml::Xml::Schema::Xsd::ComplexType.
  def xsd_complex_type(name: "TestType", attributes: [], base: nil)
    ct = Lutaml::Xml::Schema::Xsd::ComplexType.new(name: name)
    attributes.each { |a| ct.attribute << a }
    ct
  end

  # Build a real Lutaml::Xml::Schema::Xsd::Attribute.
  def xsd_attribute(name: "id", type: "xs:string", use: "optional")
    Lutaml::Xml::Schema::Xsd::Attribute.new(name: name, type: type, use: use)
  end

  # Build a real Lutaml::Xsd::NamespaceMapping.
  def ns_mapping(prefix: "ex", uri: "http://example.com/ns")
    Lutaml::Xsd::NamespaceMapping.new(prefix: prefix, uri: uri)
  end

  # Build a real SchemaRepository pre-populated with namespaces, files, and
  # types (per namespace). The type index and namespace registry are populated
  # through their public APIs — no instance_variable manipulation.
  def repo_with(namespaces: {}, types_by_namespace: {}, files: [])
    repo = Lutaml::Xsd::SchemaRepository.new(files: files)
    namespaces.each do |prefix, uri|
      repo.namespace_registry.register(prefix, uri)
    end
    types_by_namespace.each do |uri, type_names|
      schema = Lutaml::Xml::Schema::Xsd::Schema.new
      schema.target_namespace = uri
      type_names.each do |name|
        schema.complex_type << Lutaml::Xml::Schema::Xsd::ComplexType.new(name: name)
      end
      repo.type_index.index_schema(schema, "#{uri}.xsd")
    end
    repo
  end
end

RSpec.configure { |c| c.include Factories }
