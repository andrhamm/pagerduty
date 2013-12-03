require 'json'
require 'net/http'
require 'pagerduty/version'

class PagerdutyException < Exception
  attr_reader :pagerduty_instance, :api_response

  def initialize(instance, resp)
    @pagerduty_instance = instance
    @api_response = resp
  end
end

class Pagerduty

  attr_reader :service_key, :incident_key, :sub_domain

  def initialize(service_key, incident_key = nil, sub_domain = nil)
    @service_key = service_key
    @incident_key = incident_key
    @sub_domain = sub_domain
  end

  def trigger(description, details = {})
    resp = api_call("trigger", description, details)
    throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

    PagerdutyIncident.new @service_key, resp["incident_key"]
  end

  def get_incident(incident_key)
    PagerdutyIncident.new @service_key, incident_key
  end

  def get_services
    resp = rest_call("services")
    throw PagerdutyException.new(self, resp) unless defined? resp["services"]

    resp["services"].map {|service| OpenStruct.new service}
  end

protected
  def rest_call(uri)
    url = URI.parse("https://#{@sub_domain}.pagerduty.com/api/v1/#{uri}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new(url.request_uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'
    req['Authorization'] = "Token token=#{@service_key}"

    res = http.request(req)

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      JSON.parse(res.body)
    else
      res.error!
    end
  end

  def api_call(event_type, description, details = {})
    params = { :event_type => event_type, :service_key => @service_key, :description => description, :details => details }
    params.merge!({ :incident_key => @incident_key }) unless @incident_key == nil

    url = URI.parse("http://events.pagerduty.com/generic/2010-04-15/create_event.json")

    http = Net::HTTP.new(url.host, url.port)

    req = Net::HTTP::Post.new(url.request_uri)
    req.body = JSON.generate(params)

    res = http.request(req)
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      JSON.parse(res.body)
    else
      res.error!
    end
  end

end

class PagerdutyIncident < Pagerduty

  def initialize(service_key, incident_key)
    super service_key
    @incident_key = incident_key
  end

  def acknowledge(description, details = {})
    resp = api_call("acknowledge", description, details)
    throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

    self
  end

  def resolve(description, details = {})
    resp = api_call("resolve", description, details)
    throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

    self
  end

end