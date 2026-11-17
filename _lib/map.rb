# frozen_string_literal: true

require 'base64'
require 'httparty'
require 'openssl'
require 'uri'

module Strava
  module Models
    class Map < Strava::Models::Response
      def decoded_summary_polyline
        Polylines::Decoder.decode_polyline(summary_polyline) if summary_polyline && !summary_polyline.blank?
      end

      def image_url
        return unless decoded_summary_polyline&.any?

        google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_SERVER_API_KEY']
        raise 'Missing GOOGLE_STATIC_MAPS_SERVER_API_KEY' if google_maps_api_key.to_s.empty?

        signing_secret = ENV['GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET']
        raise 'Missing GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET' if signing_secret.to_s.empty?

        @image_url ||= begin
          start_latlng = decoded_summary_polyline[0]
          end_latlng = decoded_summary_polyline[-1]
          query = URI.encode_www_form([
            ['maptype', 'roadmap'],
            ['path', "enc:#{summary_polyline}"],
            ['key', google_maps_api_key],
            ['size', '800x800'],
            ['markers', "color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}"],
            ['markers', "color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"]
          ])
          path = "/maps/api/staticmap?#{query}"
          signature = Base64.urlsafe_encode64(
            OpenSSL::HMAC.digest('SHA1', Base64.urlsafe_decode64(signing_secret), path)
          )
          "https://maps.googleapis.com#{path}&signature=#{signature}"
        end
      end

      def png
        return unless image_url

        @png ||= begin
          response = HTTParty.get(image_url)
          raise "Google Maps Static API request failed (HTTP #{response.code})" unless response.code == 200
          raise 'Google Maps Static API returned a non-PNG response' unless response.headers['content-type'].to_s.split(';').first == 'image/png'

          response.body
        end
      end
    end
  end
end
