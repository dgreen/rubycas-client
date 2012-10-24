require 'spec_helper'

describe RubyCAS::Client do
  describe "#initialize" do
    context "call with nil" do
      let(:config) { nil }
      it "should raise an argument error" do
        expect { RubyCAS::Client.new(config) }.to raise_error(ArgumentError, /Could not configure/)
      end
    end

    context "call with empty hash" do
      let(:config) { Hash.new }
      it "should raise an argument error" do
        expect { RubyCAS::Client.new(config) }.to raise_error(ArgumentError, /cas_base_url/)
      end
    end

    context "call with hash that includes cas_base_url" do
      let(:config) { {:cas_base_url => "http://cas.server.local/cas"}}
      subject { RubyCAS::Client.new(config) }
      it "should set the cas_base_url" do
        subject.config.cas_base_url.should == config[:cas_base_url]
      end
    end

    context "call with hash keys that are strings" do
      let(:config) { { "cas_base_url" => "https://cas.server.local/cas" } }
      subject { RubyCAS::Client.new(config) }
      it "should set the cas_base_url" do
        subject.config.cas_base_url.should == config["cas_base_url"]
      end
    end

    context "call with path to file" do
      include TempFiles
      create_temp_file("client_spec_config.yml")

      before do
        content_for_file <<-FILE
---
cas_base_url: https://cas.server.local/cas
        FILE
      end
      subject { RubyCAS::Client.new(file_path) }
      it "should load config file" do
        subject.config.cas_base_url.should == "https://cas.server.local/cas"
      end
    end

    context "where the path is invalid" do
      it "should raise an error" do
        expect { RubyCAS::Client.new("not_a_real_file.yml") }.to raise_error /No such file or directory/
      end
    end
  end
  let(:client)     { RubyCAS::Client.new(:login_url => login_url, :cas_base_url => '', :logger => "#{File.dirname(__FILE__)}/../tmp/spec.log")}
  let(:login_url)  { "http://localhost:3443/"}
  let(:uri)        { URI.parse(login_url) }
  let(:session)    { double('session', :use_ssl= => true, :verify_mode= => true) }

  context "https connection" do
    let(:proxy)      { double('proxy', :new => session) }

    before :each do
      Net::HTTP.stub :Proxy => proxy
    end

    it "sets up the session with the login url host and port" do
      proxy.should_receive(:new).with('localhost', 3443).and_return(session)
      client.send(:https_connection, uri)
    end

    it "sets up the proxy with the known proxy host and port" do
      client = RubyCAS::Client.new(:login_url => login_url, :cas_base_url => '', :proxy_host => 'foo', :proxy_port => 1234)
      Net::HTTP.should_receive(:Proxy).with('foo', 1234).and_return(proxy)
      client.send(:https_connection, uri)
    end
  end

  context "cas server requests" do
    let(:response)   { double('response', :body => 'HTTP BODY', :code => '200') }
    let(:connection) { double('connection', :get => response, :post => response, :request => response) }

    before :each do
      client.stub(:https_connection).and_return(session)
      session.stub(:start).and_yield(connection)
    end

    context "cas server is up" do
      it "returns false if the server cannot be connected to" do
        connection.stub(:get).and_raise(Errno::ECONNREFUSED)
        client.cas_server_is_up?.should be_false
      end

      it "returns false if the request was not a success" do
        response.stub :kind_of? => false
        client.cas_server_is_up?.should be_false
      end

      it "returns true when the server is running" do
        response.stub :kind_of? => true
        client.cas_server_is_up?.should be_true
      end
    end

    context "request login ticket" do
      it "raises an exception when the request was not a success" do
        session.stub(:post).with("/Ticket", ";").and_return(response)
        response.stub :kind_of? => false
        lambda {
          client.request_login_ticket
        }.should raise_error(RubyCAS::Client::CASException)
      end

      it "returns the response body when the request is a success" do
        session.stub(:post).with("/Ticket", ";").and_return(response)
        response.stub :kind_of? => true
        client.request_login_ticket.should == "HTTP BODY"
      end
    end

    context "request cas response" do
      let(:validation_response) { double('validation_response') }

      it "should raise an exception when the request is not a success or 422" do
        response.stub :kind_of? => false
        lambda {
          client.send(:request_cas_response, uri, RubyCAS::Client::ValidationResponse)
        }.should raise_error(RuntimeError)
      end

      it "should return a ValidationResponse object when the request is a success or 422" do
        RubyCAS::Client::ValidationResponse.stub(:new).and_return(validation_response)
        response.stub :kind_of? => true
        client.send(:request_cas_response, uri, RubyCAS::Client::ValidationResponse).should == validation_response
      end
    end

    context "submit data to cas" do
      it "should return an HTTPResponse" do
        client.send(:submit_data_to_cas, uri, {}).should == response
      end
    end

    context "add service to login_url" do
      it "should add service to login url" do
        client.add_service_to_login_url("http://service.local").should == "http://localhost:3443/?service=http%3A%2F%2Fservice.local"
      end
    end
  end
end
