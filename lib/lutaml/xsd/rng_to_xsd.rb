# frozen_string_literal: true

module Lutaml
  module Xsd
    # Namespace hosting the collaborators that RngToXsdConverter orchestrates
    # to turn an Rng::Grammar into an Lutaml::Xml::Schema::Xsd::Schema.
    #
    # Each collaborator owns one phase of the conversion (pattern inspection,
    # facet dispatch, simple-type / attribute / particle / complex-type
    # building, naming, and define classification). The orchestrator wires
    # them together; collaborators never reach into each other's internals.
    module RngToXsd
      autoload :PatternInspector, "lutaml/xsd/rng_to_xsd/pattern_inspector"
      autoload :FacetBuilder, "lutaml/xsd/rng_to_xsd/facet_builder"
      autoload :SimpleTypeBuilder, "lutaml/xsd/rng_to_xsd/simple_type_builder"
      autoload :AttributeBuilder, "lutaml/xsd/rng_to_xsd/attribute_builder"
      autoload :NamingService, "lutaml/xsd/rng_to_xsd/naming_service"
      autoload :ParticleConverter, "lutaml/xsd/rng_to_xsd/particle_converter"
      autoload :ComplexTypeBuilder, "lutaml/xsd/rng_to_xsd/complex_type_builder"
      autoload :DefineConverter, "lutaml/xsd/rng_to_xsd/define_converter"
    end
  end
end
