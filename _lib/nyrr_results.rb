require 'httparty'

module NYRR
  class Results
    include HTTParty
    base_uri 'https://results.nyrr.org/'

    def self.token
      response = HTTParty.get('https://results.nyrr.org/GetSettings/rms-settings.rjs')
      token_match = response.body.match(/\"token\"\:\"(?<token>\w*)\"/)
      raise "Error locating token in RMS settings: #{response.body}" unless token_match

      return token_match['token']
    end

    def self.search(name)
      body = {
          searchString: name,
          pageIndex: 1,
          pageSize: 1
      }.to_json

      token = NYRR::Results.token

      headers = {
        'token' => token,
        'Content-Type' => 'application/json;charset=UTF-8'
      }

      response = JSON.parse(
        post('/api/runners/search', body: body, headers: headers).body
      )

      raise "Error #{response['ErrorCode']}: #{response['Message']}" if response['ErrorCode']
      raise "Error, unexpected response: #{response}" unless response.key?('response')

      response['response']['items']
    end
  end
end
