# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      autoload :ContentModelMatcher,
               "lutaml/xsd/validation/content_model_matcher"
      autoload :EngineBacked, "lutaml/xsd/validation/engine_backed"
    end
  end
end
