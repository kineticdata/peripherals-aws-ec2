module Seahorse
  module Client
    module Plugins

      # @seahorse.client.option [Boolean] :raise_response_errors (true)
      #   When `true`, response errors are raised.
      class RaiseResponseErrors < Plugin

        option(:raise_response_errors, true)

        # @api private
        class Handler < Client::Handler
          def call(context)
            response = @handler.call(context)
            raise response.error if response.error
            response
          end
        end

        def add_handlers(handlers, config)
          if config.raise_response_errors
            handlers.add(Handler, step: :validate, priority: 95)
          end
        end

      end
    end
  end
end
