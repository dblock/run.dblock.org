module Strava
  def self.client
    @client ||= begin
      query = {
        client_id: ENV['STRAVA_CLIENT_ID'] || raise('Missing STRAVA_CLIENT_ID.'),
        client_secret: ENV['STRAVA_CLIENT_SECRET'] || raise('Missing STRAVA_CLIENT_SECRET.'),
        grant_type: 'refresh_token',
        refresh_token: ENV['STRAVA_API_REFRESH_TOKEN'] || raise('Missing STRAVA_API_REFRESH_TOKEN.')
      }

      response = HTTMultiParty.post(
        Strava::Api::V3::Configuration::DEFAULT_AUTH_ENDPOINT,
        query: query
      )

      raise Strava::Api::V3::ServerError.new(response.code.to_i, response.body) unless response.success?

      refresh_token = response['refresh_token']
      if refresh_token != ENV['STRAVA_API_REFRESH_TOKEN']
        puts "The Strava API refresh token has changed, updating .travis.yml."
        rc = system("travis encrypt STRAVA_API_REFRESH_TOKEN=#{refresh_token} --add env")
        fail "travis encrypt failed with exit code #{$CHILD_STATUS.exitstatus}" if rc.nil? || !rc || $CHILD_STATUS.exitstatus != 0
      end

      Strava::Api::V3::Client.new(access_token: response['access_token'])
    end
  end
end
