module RubyCAS
  class Client
    # Represents a response from the CAS server to a login request
    # (i.e. after submitting a username/password).
    class LoginResponse
      attr_reader :tgt, :ticket, :service_redirect_url
      attr_reader :failure_message

      def initialize(http_response = nil, options={})
        parse_http_response(http_response) if http_response
      end

      def parse_http_response(http_response)
        header = http_response.to_hash

        # FIXME: this regexp might be incorrect...
        if header['set-cookie'] &&
          header['set-cookie'].first &&
          header['set-cookie'].first =~ /tgt=([^&]+);/
          @tgt = $~[1]
        end

        location = header['location'].first if header['location'] && header['location'].first
        if location =~ /ticket=([^&]+)/
          @ticket = $~[1]
        end

        # Legacy check. CAS Server used to return a 200 (Success) or a 302 (Found) on successful authentication.
        # This behavior should be deprecated at some point in the future.
        legacy_valid_ticket = (http_response.kind_of?(Net::HTTPSuccess) || http_response.kind_of?(Net::HTTPFound)) && @ticket.present?

        # If using rubycas-server 1.1.0+
        valid_ticket = http_response.kind_of?(Net::HTTPSeeOther) && @ticket.present?

        if !legacy_valid_ticket && !valid_ticket
          @failure = true
          # Try to extract the error message -- this only works with RubyCAS-Server.
          # For other servers we just return the entire response body (i.e. the whole error page).
          body = http_response.body
          if body =~ /<div class="messagebox mistake">(.*?)<\/div>/m
            @failure_message = $~[1].strip
          else
            @failure_message = body
          end
        end

        @service_redirect_url = location
      end

      def is_success?
        !@failure && (!ticket.nil? || !ticket.empty?)
      end

      def is_failure?
        @failure == true
      end
    end
  end
end
