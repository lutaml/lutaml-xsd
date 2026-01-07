# frozen_string_literal: true

module Lutaml
  module Xsd
    class Register
      attr_reader :register

      REGISTER_ID = :xsd

      def initialize(register_id = REGISTER_ID)
        @register = ::Lutaml::Model::Register.new(register_id)
        ::Lutaml::Model::GlobalRegister.register(@register)
      end

      class << self
        def register_model(klass, id)
          instance.register.register_model(klass, id: id)
        end

        def instance=(register_instance)
          @instance = register_instance
        end

        def instance
          @instance ||= new
        end

        def register
          instance.register
        end
      end
    end
  end
end
