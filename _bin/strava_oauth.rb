# obtain a Strava OAuth token
# see https://developers.strava.com/docs/authentication/

require 'strava/api/v3'
require 'active_support/core_ext/object/to_query'

query = {
  client_id: ENV['STRAVA_CLIENT_ID'] || raise('Missing STRAVA_CLIENT_ID.'),
  redirect_uri: 'http://localhost',
  response_type: 'code',
  scope: 'activity:read_all'
}

STDOUT.write "1. Navigate to https://www.strava.com/oauth/authorize?#{query.to_query}\n"
STDOUT.write "2. Copy paste the code from the URL: "
code = gets.strip
puts "3. Using code #{code} ..."

query = {
  client_id: ENV['STRAVA_CLIENT_ID'] || raise('Missing STRAVA_CLIENT_ID.'),
  client_secret: ENV['STRAVA_CLIENT_SECRET'] || raise('Missing STRAVA_CLIENT_SECRET.'),
  grant_type: 'authorization_code',
  code: code
}

response = HTTMultiParty.post(Strava::Api::V3::Configuration::DEFAULT_AUTH_ENDPOINT, query: query)

raise "Error #{response.code.to_i}, #{response.body}" unless response.success?

rc = JSON.parse(response.body)

puts "token_type: #{rc['token_type']}"
puts "refresh_token: #{rc['refresh_token']}"
puts "access_token: #{rc['access_token']}"
puts "expires_at: #{Time.at(rc['expires_at'])}"
