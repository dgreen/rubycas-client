module RubyCAS
  class Client
    # Represents a response from the CAS server to a proxy ticket request
    # (i.e. after requesting a proxy ticket).
    class ProxyResponse
      include RubyCAS::Client::XmlResponse

      attr_reader :proxy_ticket

      def initialize(raw_text, options={})
        parse(raw_text)
      end

      def parse(raw_text)
        raise BadResponseException,
          "CAS response is empty." if raw_text.nil? || raw_text.empty?
        @parse_datetime = Time.now

        @xml = check_and_parse_xml(raw_text)

        if is_success?
          @proxy_ticket = @xml.elements["cas:proxyTicket"].text.strip if @xml.elements["cas:proxyTicket"]
        elsif is_failure?
          @failure_code = @xml.elements['//cas:proxyFailure'].attributes['code']
          @failure_message = @xml.elements['//cas:proxyFailure'].text.strip
        else
          # this should never happen, since the response should already have been recognized as invalid
          raise BadResponseException, "BAD CAS RESPONSE:\n#{raw_text.inspect}\n\nXML DOC:\n#{doc.inspect}"
        end

      end

      def is_success?
        xml.name == "proxySuccess"
      end

      def is_failure?
        xml.name == "proxyFailure"
      end
    end
  end
end
