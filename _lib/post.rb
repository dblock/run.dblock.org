require 'hashie'
require 'strava-ruby-client'

require_relative 'strava'
require_relative 'map'
require_relative 'activity'

require 'fileutils'
require 'polylines'

require 'active_support'
require 'active_support/core_ext/date/calculations'

module Strava
  class Post
    attr_reader :id

    def initialize(id, data = nil)
      @id = id
      if data
        @activity = Strava::Models::Activity.new(data)
        @photos = data["activity_photos"]&.map { |ap| Strava::Models::Photo.new(ap) }
      end
    end

    def activity
      @activity ||= Strava.client.activity(id)
    end

    def photos
      @photos ||= Strava.client.activity_photos(activity.id, size: '600')
    end

    def save!
      FileUtils.mkdir_p "_activities/#{activity.start_date_local.year}"

      File.open activity.json_filename, 'w' do |file|
        h = activity.to_h.merge("activity_photos" => photos.map(&:to_h))
        file.write(JSON.pretty_generate(h))
      end

      FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

      run_with_names = []
      [/run with (?<name>\w*)/i, /run with .* and (?<name>\w*)/i].each do |regex|
        run_with_match = activity.name.match(regex)
        run_with_names << run_with_match['name'] if run_with_match
      end

      File.open activity.filename, 'w' do |file|
        tags = [
          "#{activity.type.downcase}s",
          "#{activity.rounded_distance_in_miles_s} miles",
          activity.rounded_pace_per_mile_s,
          activity.race? ? 'races' : nil,
          activity.max_heartrate ? "μ#{activity.rounded_max_heartrate_s} bpm" : nil,
          activity.average_heartrate ? "→#{activity.rounded_average_heartrate_s} bpm" : nil,
          run_with_names.any? ? run_with_names.map { |name| "w/#{name.downcase}" } : nil,
          activity.device_name&.downcase,
          activity.gear&.name&.downcase
        ].compact

        data = {
          layout: 'post',
          title: "\"#{activity.name}\"",
          date: "\"#{activity.start_date_local.strftime('%F %T')}\"",
          tags: "[#{tags.join(', ')}]",
          race: activity.race?,
          distance: activity.distance_in_miles,
          time: activity.moving_time,
          average_heartrate: activity.average_heartrate,
          max_heartrate: activity.max_heartrate,
          strava_id: activity.id,
          device_name: activity.device_name
        }.compact

        file.write "---\n"
        data.each_pair do |k, v|
          file.write "#{k}: #{v}\n"
        end
        file.write "---\n"

        file.write "\n### Stats\n"
        file.write "\n| Distance | Time | Pace | Device | Gear |"
        file.write "\n|:--------:|:----:|:----:|:------:|:----:|"
        file.write "\n|" + [
            activity.distance_in_miles_s,
            activity.moving_time_in_hours_s,
            activity.pace_per_mile_s,
            activity.device_logo ? "![#{activity.device_name}]({{ site.url }}/#{activity.device_logo})" : activity.device_name,
            activity.gear&.name
          ].join('|') + "|\n"

        file.write "\n#{activity.description.strip}\n" if activity.description && !activity.description.strip.empty?

        if activity.map.image_url
          unless File.exist?(activity.map_filename)
            FileUtils.mkdir_p(File.dirname(activity.map_filename))
            File.write(activity.map_filename, activity.map.png)
          end

          file.write "\n![]({{ site.url }}/#{activity.map_filename})\n"
        elsif File.exist?(activity.map_filename)
          File.delete activity.map_filename
        end

        if activity.splits_standard && activity.splits_standard.any?
          file.write "\n### Splits\n"
          file.write "\n| Mile | Pace | Elevation |"
          file.write "\n|:----:|:----:|:---------:|"
          activity.splits_standard.each do |split|
            file.write "\n|#{split.split}|#{split.pace_per_mile_s}|#{split.total_elevation_gain_in_feet_s}|"
          end
          file.write "\n"
        end

        if photos.any?
          file.write "\n### Photos\n"
          photos.each do |photo|
            url = photo.urls['600']
            file.write "\n<img src='#{url}'>\n"
          end
        end
      end

      self
    end

    def filename
      activity.filename
    end
  end
end