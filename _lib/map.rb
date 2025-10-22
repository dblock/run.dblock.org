# frozen_string_literal: true

require 'cgi'
require 'httparty'

module Strava
  module Models
    class Map < Strava::Models::Response
      def decoded_summary_polyline
        Polylines::Decoder.decode_polyline(summary_polyline) if summary_polyline && !summary_polyline.blank?
      end

      def image_url
        return unless decoded_summary_polyline&.any?

        google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_API_KEY']
        raise 'Missing GOOGLE_STATIC_MAPS_API_KEY' unless google_maps_api_key

        @image_url ||= begin
          start_latlng = decoded_summary_polyline[0]
          end_latlng = decoded_summary_polyline[-1]
          "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{CGI.escape(summary_polyline)}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
        end
      end

      def png
        return unless image_url

        @png ||= HTTParty.get(image_url).body
      end
    end
  end
end
