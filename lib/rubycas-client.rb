require 'uri'
require 'cgi'
require 'logger'
require 'net/https'
require 'rexml/document'
require 'json'


module RubyCAS
  class Client
    class CASException < Exception
    end
  end
end

require 'rubycas-client/responses'
require 'rubycas-client/client'
require 'rubycas-client/config'
