require 'spec_helper'
require 'rubycas-client/responses.rb'

describe RubyCAS::Client::XmlResponse do
  context "when parsing malformed raw xml" do
    let(:response_text) do
<<RESPONSE_TEXT
cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
  cas:authenticationSuccess>
    <cas:attribute
      <cas:name>Jimmy Bob</cas:name>
      <cas:status><![CDATA[stuff
]]></cas:status>
      <cas:yaml><![CDATA[--- true
]]></cas:yaml>
      <cas:json><![CDATA[{"id":10529}]]></cas:json>
    </cas:attributes>
  </cas:authenticationSuccess>
<cas:serviceResponse>
RESPONSE_TEXT
    end
    include RubyCAS::Client::XmlResponse

    it "should raise an bad response exception" do
      expect { check_and_parse_xml response_text }.to raise_error(RubyCAS::Client::BadResponseException, /MALFORMED CAS RESPONSE/)
    end
  end

  context "when parsing not valid CAS response as raw xml" do
    let(:response_text) do
<<RESPONSE_TEXT
<cas:service xmlns:cas="http://www.yale.edu/tp/cas">
  <cas:authenticationSuccess>
    <cas:attributes>
      <cas:name>Jimmy Bob</cas:name>
      <cas:status><![CDATA[stuff
]]></cas:status>
      <cas:yaml><![CDATA[--- true
]]></cas:yaml>
      <cas:json><![CDATA[{"id":10529}]]></cas:json>
    </cas:attributes>
  </cas:authenticationSuccess>
</cas:service>
RESPONSE_TEXT
    end
    include RubyCAS::Client::XmlResponse

    it "should raise an bad response exception" do
      expect { check_and_parse_xml response_text }.to raise_error(RubyCAS::Client::BadResponseException, /missing cas:serviceResponse root element/)
    end
  end
end
