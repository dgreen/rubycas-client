require 'uri'
require 'cgi'
require 'logger'
require 'net/https'
require 'rexml/document'
require 'json'


module CASClient
  class CASException < Exception
    # TODO implement CASException if necessary
  end
end

require 'rubycas-client/tickets'
require 'rubycas-client/responses'
require 'rubycas-client/client'
