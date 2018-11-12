require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/api'

    def self.search(name)
      body = JSON.parse(
        post('/runners/search',
             body: {
               searchString: name,
               pageIndex: 1,
               pageSize: 1
             }.to_json,
             headers: {
               'token' => 'ebe04e9c08064536',
               'Content-Type' => 'application/json'
             }).body
      )

      if body['ErrorCode']
        raise "Error #{body['ErrorCode']}: #{body['Message']}"
      else
        body['response']['items']
      end
    end
  end
end
