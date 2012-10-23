module RubyCAS
  class Client
    module XmlResponse
      attr_reader :xml, :parse_datetime
      attr_reader :failure_code, :failure_message

      def check_and_parse_xml(raw_xml)
        begin
          doc = REXML::Document.new(raw_xml, :raw => :all)
        rescue REXML::ParseException => e
          raise BadResponseException,
            "MALFORMED CAS RESPONSE:\n#{raw_xml.inspect}\n\nEXCEPTION:\n#{e}"
        end

        unless doc.elements && doc.elements["cas:serviceResponse"]
          raise BadResponseException,
            "This does not appear to be a valid CAS response (missing cas:serviceResponse root element)!\nXML DOC:\n#{doc.to_s}"
        end

        return doc.elements["cas:serviceResponse"].elements[1]
      end

      def to_s
        xml.to_s
      end
    end

  end
end
