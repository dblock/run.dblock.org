require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/api'

    def self.search(name)
      JSON.parse(
        post('/runners/search',
             body: {
               searchString: name,
               pageIndex: 1,
               pageSize: 1
             }.to_json,
             headers: {
               'token' => 'eb9dc6e334b64d77',
               'Content-Type' => 'application/json'
             }).body
      )['response']['items']
    end
  end
end
