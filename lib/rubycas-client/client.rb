module RubyCAS
  # The client brokers all HTTP transactions with the CAS server.
  class Client
    attr_reader :config, :log

    def initialize(conf, environment = nil)
      conf_hash = case conf
      when Hash
        conf
      when String
        parse_config_file(conf)
      else
        raise ArgumentError, "Could not configure RubyCAS::Client with #{conf.inspect}"
      end
      conf_hash = stringify_hash_keys(conf_hash)

      unless environment.nil?
        conf_hash = stringify_hash_keys(conf_hash[environment.to_sym])
      end


      @config = RubyCAS::Client::Config.new(conf_hash)
      @config.freeze

      @log = Logger.new(config.logger || STDERR)
    end

    # Returns the CAS server's logout url.
    #
    # If a logout_url has not been explicitly configured,
    # the default is cas_base_url + "/logout".
    #
    # destination_url:: Set this if you want the user to be
    #                   able to immediately log back in. Generally
    #                   you'll want to use something like <tt>request.referer</tt>.
    #                   Note that the above behaviour describes RubyCAS-Server
    #                   -- other CAS server implementations might use this
    #                   parameter differently (or not at all).
    # follow_url:: This satisfies section 2.3.1 of the CAS protocol spec.
    #              See http://www.ja-sig.org/products/cas/overview/protocol
    def logout_url(destination_url = nil, follow_url = nil, service_url = nil)
      url = @logout_url || (config.cas_base_url + "/logout")
      uri = URI.parse(url)
      service_url = (service_url if service_url) || @service_url
      h = uri.query ? query_to_hash(uri.query) : {}

      if destination_url
        # if present, remove the 'ticket' parameter from the destination_url
        duri = URI.parse(destination_url)
        dh = duri.query ? query_to_hash(duri.query) : {}
        dh.delete('ticket')
        duri.query = hash_to_query(dh)
        destination_url = duri.to_s.gsub(/\?$/, '')
        h[cas_destination_logout_param_name] = destination_url if destination_url
        h['gateway'] = 'true'
      elsif follow_url
        h['url'] = follow_url if follow_url
        h['service'] = service_url
      else
        h['service'] = service_url
      end
      uri.query = hash_to_query(h)
      uri.to_s
    end

    def proxy_url
      @proxy_url || (config.cas_base_url + "/proxy")
    end

    ##
    # Prepare uri for service ticket
    #
    # :args: service_ticket
    def prepare_uri_for(st)
      uri = URI.parse(config.proxy_validate_url)
      h = uri.query ? query_to_hash(uri.query) : {}
      h['service'] = st.service
      h['ticket'] = st.ticket
      h['renew'] = "1" if st.renew
      h['pgtUrl'] = config.proxy_callback_url if config.proxy_callback_url
      uri.query = hash_to_query(h)
      uri
    end

    def validate_service_ticket(response, st)
      st.user = response.user
      st.extra_attributes = response.extra_attributes
      st.pgt_iou = response.pgt_iou
      st.success = response.is_success?
      st.failure_code = response.failure_code
      st.failure_message = response.failure_message

      return st
    end

    alias validate_proxy_ticket validate_service_ticket

    # Returns true if the configured CAS server is up and responding;
    # false otherwise.
    def cas_server_is_up?
      uri = URI.parse(config.login_url)

      log.debug "Checking if CAS server at URI '#{uri}' is up..."

      https = https_connection(uri)

      begin
        raw_res = https.start do |conn|
          conn.get("#{uri.path}?#{uri.query}")
        end
      rescue Errno::ECONNREFUSED => e
        log.warn "CAS server did not respond! (#{e.inspect})"
        return false
      end

      log.debug "CAS server responded with #{raw_res.inspect}:\n#{raw_res.body}"

      return raw_res.kind_of?(Net::HTTPSuccess)
    end

    # Requests a login using the given credentials for the given service;
    # returns a LoginResponse object.
    def login_to_service(credentials, service)
      lt = request_login_ticket

      data = credentials.merge(
        :lt => lt,
        :service => service
      )

      res = submit_data_to_cas(login_url, data)
      response = RubyCAS::Client::LoginResponse.new(res)

      if response.is_success?
        log.info("Login was successful for ticket: #{response.ticket.inspect}.")
      end

      return response
    end

    # Requests a login ticket from the CAS server for use in a login request;
    # returns a LoginTicket object.
    #
    # This only works with RubyCAS-Server, since obtaining login
    # tickets in this manner is not part of the official CAS spec.
    def request_login_ticket
      uri = URI.parse(config.cas_base_url+'/loginTicket')
      https = https_connection(uri)
      res = https.post(uri.path, ';')

      raise CASException, res.body unless res.kind_of? Net::HTTPSuccess

      res.body.strip
    end

    # Requests a proxy ticket from the CAS server for the given service
    # using the given pgt (proxy granting ticket); returns a ProxyTicket
    # object.
    #
    # The pgt required to request a proxy ticket is obtained as part of
    # a ValidationResponse.
    def request_proxy_ticket(pgt, target_service)
      uri = URI.parse(proxy_url)
      h = uri.query ? query_to_hash(uri.query) : {}
      h['pgt'] = pgt.ticket
      h['targetService'] = target_service
      uri.query = hash_to_query(h)

      response = request_cas_response(uri, ProxyResponse)

      pt = ProxyTicket.new(response.proxy_ticket, target_service)
      pt.success = response.is_success?
      pt.failure_code = response.failure_code
      pt.failure_message = response.failure_message

      return pt
    end

    def retrieve_proxy_granting_ticket(pgt_iou)
      pgt = @ticket_store.retrieve_pgt(pgt_iou)

      raise CASException, "Couldn't find pgt for pgt_iou #{pgt_iou}" unless pgt

      ProxyGrantingTicket.new(pgt, pgt_iou)
    end

    def add_service_to_login_url(service_url)
      uri = URI.parse(config.login_url)
      uri.query = (uri.query ? uri.query + "&" : "") + "service=#{CGI.escape(service_url)}"
      uri.to_s
    end

    # Fetches a CAS response of the given type from the given URI.
    # Type should be either ValidationResponse or ProxyResponse.
    def request_cas_response(uri, type, options={})
      log.debug "Requesting CAS response for URI #{uri}"

      uri = URI.parse(uri) unless uri.kind_of? URI
      https = https_connection(uri)
      begin
        raw_res = https.start do |conn|
          conn.get("#{uri.path}?#{uri.query}")
        end
      rescue Errno::ECONNREFUSED => e
        log.error "CAS server did not respond! (#{e.inspect})"
        raise "The CAS authentication server at #{uri} is not responding!"
      end

      # We accept responses of type 422 since RubyCAS-Server generates these
      # in response to requests from the client that are processable but contain
      # invalid CAS data (for example an invalid service ticket).
      if raw_res.kind_of?(Net::HTTPSuccess) || raw_res.code.to_i == 422
        log.debug "CAS server responded with #{raw_res.inspect}:\n#{raw_res.body}"
      else
        log.error "CAS server responded with an error! (#{raw_res.inspect})"
        raise "The CAS authentication server at #{uri} responded with an error (#{raw_res.inspect})!"
      end

      type.new(raw_res.body, config)
    end

    private

    def https_connection(uri)
      https = Net::HTTP::Proxy(config.proxy_host, config.proxy_port).new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      https.verify_mode = (@force_ssl_verification ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE)
      https
    end


    # Submits some data to the given URI and returns a Net::HTTPResponse.
    def submit_data_to_cas(uri, data)
      uri = URI.parse(uri) unless uri.kind_of? URI
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data, ';')
      https = https_connection(uri)
      https.start {|conn| conn.request(req) }
    end

    def query_to_hash(query)
      CGI.parse(query)
    end

    def hash_to_query(hash)
      pairs = []
      hash.each do |k, vals|
        vals = [vals] unless vals.kind_of? Array
        vals.each {|v| pairs << (v.nil? ? CGI.escape(k) : "#{CGI.escape(k)}=#{CGI.escape(v)}")}
      end
      pairs.join("&")
    end

    private
      def parse_config_file(file_path)
        YAML::load(File.read(file_path))
      end

      def stringify_hash_keys(hash)
        hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      end
  end
end
