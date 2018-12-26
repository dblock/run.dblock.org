require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/api'

    def self.token
      regex = /n\.defaults\.headers\.common\.Token\=\"(?<token>\w*)\"/
      HTTParty.get('https://results.nyrr.org/bundles/app').body.match(regex)['token']
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
