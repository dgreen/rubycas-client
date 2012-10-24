require 'spec_helper'
require 'rubycas-client/responses.rb'

describe RubyCAS::Client::LoginResponse do
  context "when parsing login response" do
    response = Net::HTTPResponse.new(1.1, 200, "OK")
    response.add_field 'Set-Cookie', "tgt=TGC-1350985088rC518DAC9942FF66842"
    response.add_field 'Content-Lenght', 0
    response.add_field 'Location', "http://server.local/welcome?ticket=ST-1350989084rD4CCE99F36370CBE2E"

    subject { RubyCAS::Client::LoginResponse.new response }

    it "should return proper attributes for login response" do
      subject.service_redirect_url.should == "http://server.local/welcome?ticket=ST-1350989084rD4CCE99F36370CBE2E"
      subject.tgt.should == "TGC-1350985088rC518DAC9942FF66842"
      subject.ticket.should == "ST-1350989084rD4CCE99F36370CBE2E"
      subject.is_success?.should == true
      subject.is_failure?.should == false
    end
  end

  context "when parsing login response with error message" do
    response = Net::HTTPResponse.new(1.1, 401, "Unauthorized")
    # FIXME this p method should not be here but without it wont set body
    response.body
    response.body = '<div class="messagebox mistake">Incorrect username or password.</div>'


    subject { RubyCAS::Client::LoginResponse.new response }

    it "sets text attributes to their string value" do
      subject.service_redirect_url.should == nil
      subject.tgt.should == nil
      subject.ticket.should == nil
      subject.is_success?.should == false
      subject.is_failure?.should == true
    end
  end

  context "when parsing login response with error message" do
    response = Net::HTTPResponse.new(1.1, 401, "Unauthorized")
    # FIXME this p method should not be here but without it wont set body
    response.body
    response.body = "Incorrect username or password."
    subject { RubyCAS::Client::LoginResponse.new response }

    it "sets text attributes to their string value" do
      subject.service_redirect_url.should == nil
      subject.tgt.should == nil
      subject.ticket.should == nil
    end
  end

end
