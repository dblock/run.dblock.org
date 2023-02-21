require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/'

    def self.search(name)
      body = {
        searchString: name,
        pageIndex: 1,
        pageSize: 1
      }.to_json

      headers = {
        'content-type' => 'application/json;charset=UTF-8'
      }

      response = JSON.parse(
        post('/api/v2/runners/search', body: body, headers: headers).body
      )

      raise "Error, unexpected response: #{response}" unless response.key?('items')

      response['items']
    end
  end
end
