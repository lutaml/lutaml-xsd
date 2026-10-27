# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      autoload :ContentModelMatcher,
               "lutaml/xsd/validation/content_model_matcher"
      autoload :EngineBacked, "lutaml/xsd/validation/engine_backed"
      autoload :OccurrenceProductGuard,
               "lutaml/xsd/validation/occurrence_product_guard"
      autoload :ValueSpace, "lutaml/xsd/validation/value_space"
    end
  end
end
