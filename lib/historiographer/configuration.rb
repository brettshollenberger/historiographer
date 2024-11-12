require "singleton"

module Historiographer
  class Configuration
    include Singleton

    OPTS = {
      mode: {
        default: :histories
      }
    }
    OPTS.each do |key, options|
      attr_accessor key
    end

    class << self
      def configure
        yield instance
      end

      OPTS.each do |key, options|
        define_method "#{key}=" do |value|
          instance.send("#{key}=", value)
        end

        define_method key do
          instance.send(key) || options.dig(:default)
        end
      end
    end

    def initialize
      @mode = :histories
    end
  end
end
