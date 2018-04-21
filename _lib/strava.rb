module Strava
  def self.client
    @client ||= begin
      strava_api_token = ENV['STRAVA_API_TOKEN']
      raise 'Missing STRAVA_API_TOKEN' unless strava_api_token
      Strava::Api::V3::Client.new(access_token: strava_api_token)
    end
  end
end
