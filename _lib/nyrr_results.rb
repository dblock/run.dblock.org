require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/api'

    def self.token
      regex = /\"token\"\:\"(?<token>\w*)\"/
      body = HTTParty.get('https://results.nyrr.org/GetSettings/rms-settings.rjs').body
      token_match = body.match(regex)
      raise "Error locating token in RMS settings: #{body}" unless token_match

      token_match['token']
    end

    def self.search(name)
      body = JSON.parse(
        post('/runners/search',
             body: {
               searchString: name,
               pageIndex: 1,
               pageSize: 1
             }.to_json,
             headers: {
               'token' => NYRR::Results.token,
               'Content-Type' => 'application/json'
             }).body
      )

      raise "Error #{body['ErrorCode']}: #{body['Message']}" if body['ErrorCode']

      body['response']['items']
    end
  end
end
