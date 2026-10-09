# frozen_string_literal: true

require 'hashie'
require 'strava-ruby-client'

require_relative 'strava'
require_relative 'map'
require_relative 'activity'
require_relative 'shoe_tags'
require_relative 'place_tags'

require 'fileutils'
require 'polylines'
require 'yaml'

require 'active_support'
require 'active_support/core_ext/date/calculations'

module Strava
  class Post
    attr_reader :id

    def initialize(id, data = nil)
      @id = id
      return unless data

      @data = data
      @activity = Strava::Models::DetailedActivity.new(data)
      @photos = data['activity_photos']&.map { |ap| Strava::Models::DetailedPhoto.new(ap) }
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
        file.write(JSON.pretty_generate(data))
      end

      save_map!
      generate!
    end

    def generate!(
      shoe_first_use_months: ShoeTags.first_use_months,
      place_context: PlaceTags.tagging_context
    )
      FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

      activity_photo_urls = photo_urls
      activity_splits = splits
      front_matter = {
        'layout' => 'activity',
        'title' => activity.name,
        'date' => activity.start_date_local.strftime('%F %T'),
        'tags' => tags(shoe_first_use_months:, place_context:),
        'distance' => activity.distance_in_miles,
        'time' => activity.moving_time,
        'average_heartrate' => activity.average_heartrate,
        'strava_id' => activity.id,
        'distance_display' => activity.distance_in_miles_s,
        'moving_time_display' => activity.moving_time_in_hours_s,
        'pace_display' => activity.pace_per_mile_s,
        'description' => activity.description,
        'map' => File.exist?(activity.map_filename) ? true : nil,
        'device_name' => activity.device_name,
        'gear_name' => activity.gear&.name,
        'splits' => activity_splits.any? ? activity_splits : nil,
        'photos' => activity_photo_urls.any? ? activity_photo_urls : nil
      }.compact
      temporary_filename = "#{activity.filename}.tmp"
      File.binwrite(temporary_filename, "#{YAML.dump(front_matter)}---\n")
      FileUtils.mv(temporary_filename, activity.filename, force: true)

      self
    ensure
      FileUtils.rm_f(temporary_filename) if temporary_filename
    end

    def filename
      activity.filename
    end

    private

    def data
      @data ||= activity.to_h.merge('activity_photos' => photos.map(&:to_h))
    end

    def splits
      activity.splits_standard&.map do |split|
        {
          'number' => split.split,
          'pace' => split.pace_per_mile_s,
          'elevation' => split.elevation_difference_in_feet_s
        }
      end || []
    end

    def photo_urls
      data.fetch('activity_photos', []).each_with_index.filter_map do |photo, index|
        url = photo.fetch('urls', {}).fetch('600', '').to_s.strip
        next if url.empty?

        photo_id = photo['unique_id'].to_s.empty? ? index : photo.fetch('unique_id')
        [photo_id, url]
      end.uniq(&:first).map(&:last)
    end

    def tags(shoe_first_use_months:, place_context:)
      run_with_names = []
      [/run with (?<name>\w*)/i, /run with .* and (?<name>\w*)/i].each do |regex|
        run_with_match = activity.name.match(regex)
        run_with_names << run_with_match['name'] if run_with_match
      end
      [
        "#{activity.sport_type.humanize.downcase}s",
        "#{activity.rounded_distance_in_miles_s} miles",
        activity.rounded_pace_per_mile_s,
        activity.race? ? 'races' : nil,
        activity.max_heartrate ? "μ#{activity.rounded_max_heartrate_s} bpm" : nil,
        activity.average_heartrate ? "→#{activity.rounded_average_heartrate_s} bpm" : nil,
        run_with_names.any? ? run_with_names.map { |name| "w/#{name.downcase}" } : nil,
        "y/#{activity.start_date_local.year}",
        activity.device_name&.downcase&.split&.first,
        activity.gear&.name&.downcase&.split&.first,
        activity.gear&.name ? ShoeTags.tag(
          activity.gear.id,
          activity.gear.name,
          activity.start_date_local.strftime('%Y/%m'),
          shoe_first_use_months
        ) : nil,
        PlaceTags.tags(
          activity,
          place_context.fetch(:places),
          place_context.fetch(:compiled_places)
        )
      ].flatten.compact
    end

    def save_map!
      if activity.map.decoded_summary_polyline&.any?
        unless File.exist?(activity.map_filename)
          FileUtils.mkdir_p(File.dirname(activity.map_filename))
          File.binwrite(activity.map_filename, activity.map.png)
        end
      elsif File.exist?(activity.map_filename)
        File.delete(activity.map_filename)
      end
    end
  end
end
