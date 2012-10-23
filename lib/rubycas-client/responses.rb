module RubyCAS
  class Client
    require 'rubycas-client/responses/xml_response'
    require 'rubycas-client/responses/validation_response'
    require 'rubycas-client/responses/proxy_response'
    require 'rubycas-client/responses/login_response'

    class BadResponseException < CASException; end
  end
end
