module Strava
  def self.client
    @client ||= begin
      oauth_client = Strava::OAuth::Client.new(
        client_id: ENV['STRAVA_CLIENT_ID'],
        client_secret: ENV['STRAVA_CLIENT_SECRET']
      )

      response = oauth_client.oauth_token(
        refresh_token: ENV['STRAVA_API_REFRESH_TOKEN'],
        grant_type: 'refresh_token'
      )

      refresh_token = response.refresh_token
      if refresh_token != ENV['STRAVA_API_REFRESH_TOKEN']
        puts "The Strava API refresh token has changed, updating .travis.yml."
        rc = system("travis encrypt STRAVA_API_REFRESH_TOKEN=#{refresh_token} --add env")
        fail "travis encrypt failed with exit code #{$CHILD_STATUS.exitstatus}" if rc.nil? || !rc || $CHILD_STATUS.exitstatus != 0
      end

      Strava::Api::Client.new(access_token: response.access_token)
    end
  end
end
