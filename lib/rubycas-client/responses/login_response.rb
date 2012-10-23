require "debugger"
module RubyCAS
  class Client
    # Represents a response from the CAS server to a login request
    # (i.e. after submitting a username/password).
    class LoginResponse
      attr_reader :tgt, :ticket, :service_redirect_url
      attr_reader :failure_message

      def initialize(http_response = nil)
        parse_http_response(http_response) if http_response
      end

      def parse_http_response(http_response)
        header = http_response.to_hash

        header['set-cookie'].to_a.each do |cookie|
          cookie.split(";").first =~ /tgt=([^&]+)/
          @tgt = $~[1] if $~
          break if @tgt
        end

        location = header['location'].first if header['location'].is_a?(Array)
        if location =~ /ticket=([^&]+)/
          @ticket = $~[1]
        end

        valid_ticket = http_response.kind_of?(Net::HTTPResponse) && !@ticket.nil? && !@ticket.empty?

        if !valid_ticket
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
